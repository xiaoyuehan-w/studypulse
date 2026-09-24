// 设置页：GitHub 配置（含同步自查）/ 推送 / 数据 / 关于（真实版本号）
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_services.dart';
import '../app_version.dart';

class SettingsPage extends StatefulWidget {
  final AppServices services;
  const SettingsPage({super.key, required this.services});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _token;
  late final TextEditingController _owner;
  late final TextEditingController _repo;
  bool _tokenVisible = false;
  bool _validating = false;
  String? _validateResult;
  List<String>? _diagResult;
  bool _notifOk = true;
  bool _exactOk = true;

  @override
  void initState() {
    super.initState();
    final s = widget.services.store;
    _token = TextEditingController(text: s.token);
    _owner = TextEditingController(text: s.owner);
    _repo = TextEditingController(text: s.repo);
    _refreshPermissions();
  }

  @override
  void dispose() {
    _token.dispose();
    _owner.dispose();
    _repo.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    final n = widget.services.notify;
    final a = await n.hasPermission();
    final b = await n.canExactAlarm();
    if (mounted) {
      setState(() {
        _notifOk = a;
        _exactOk = b;
      });
    }
  }

  Future<void> _saveAndValidate() async {
    setState(() {
      _validating = true;
      _validateResult = null;
    });
    await widget.services.saveCredentials(
      token: _token.text,
      owner: _owner.text,
      repo: _repo.text,
    );
    final ok = await widget.services.github.validate();
    if (!mounted) return;
    setState(() {
      _validating = false;
      _validateResult = ok ? '✅ Token 有效，可以访问仓库' : '❌ Token 无效或无法访问仓库，请检查';
    });
    if (ok) await widget.services.refresh();
  }

  Future<void> _runDiagnostics() async {
    await widget.services.saveCredentials(
      token: _token.text,
      owner: _owner.text,
      repo: _repo.text,
    );
    final lines = await widget.services.github.diagnostics();
    if (!mounted) return;
    setState(() => _diagResult = lines);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('同步自查结果'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final l in lines) Text(l, style: const TextStyle(fontSize: 13))],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('GitHub 配置'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _token,
                    obscureText: !_tokenVisible,
                    decoration: InputDecoration(
                      labelText: 'Personal Access Token',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_tokenVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _tokenVisible = !_tokenVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _owner,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _repo,
                          decoration: const InputDecoration(
                            labelText: '仓库名',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _validating ? null : _saveAndValidate,
                      icon: _validating
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle),
                      label: const Text('保存并验证'),
                    ),
                  ),
                  if (_validateResult != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_validateResult!, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _runDiagnostics,
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: const Text('同步自查（读不到数据时点这里）'),
                  ),
                  if (_diagResult != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('上次自查：${_diagResult!.length} 项结果',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ),
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://github.com/settings/tokens')),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('如何创建 Token'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('推送设置'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('每日推送时间'),
                  subtitle: Text('${s.store.pushHour.toString().padLeft(2, '0')}:'
                      '${s.store.pushMinute.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: s.store.pushHour,
                        minute: s.store.pushMinute,
                      ),
                    );
                    if (picked != null) {
                      await s.store.setPushTime(picked.hour, picked.minute);
                      await s.refresh();
                      if (mounted) setState(() {});
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('发送测试通知'),
                  subtitle: const Text('验证推送链路是否正常'),
                  onTap: () async {
                    await s.notify.showTest();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已发送测试通知')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('通知权限'),
                  subtitle: Text(_notifOk ? '已授权 ✅' : '未授权 ❌ — 点此授权'),
                  onTap: () async {
                    if (!_notifOk) await s.notify.requestPermission();
                    await _refreshPermissions();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alarm_outlined),
                  title: const Text('精确闹钟（准点推送）'),
                  subtitle: Text(_exactOk ? '可用 ✅' : '未开启 ❌ — 点此开启'),
                  onTap: () async {
                    if (!_exactOk) await s.notify.requestExactAlarm();
                    await _refreshPermissions();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('数据'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('清除本地计划缓存'),
                  subtitle: const Text('下次同步会重新下载（学习记录不受影响）'),
                  onTap: () async {
                    await s.store.clearCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('缓存已清除')),
                      );
                    }
                  },
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('StudyPulse v$appVersionFull'),
                  subtitle: Text('你的 Obsidian 学习系统的执行终端'),
                ),
                if (s.store.lastSync != null)
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('上次同步'),
                    subtitle: Text(s.store.lastSync.toString().substring(0, 16)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
