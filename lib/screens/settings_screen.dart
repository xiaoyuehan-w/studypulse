import 'package:flutter/material.dart';
import '../services/github_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/timer_service.dart';

/// 设置页：配置 GitHub 访问、推送时间、测试通知
class SettingsScreen extends StatefulWidget {
  final GitHubService github;
  final StorageService storage;
  final NotificationService notifications;
  final VoidCallback? onConfigured;

  const SettingsScreen({
    super.key,
    required this.github,
    required this.storage,
    required this.notifications,
    this.onConfigured,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _tokenController;
  late TextEditingController _ownerController;
  late TextEditingController _repoController;
  bool _tokenVisible = false;
  bool _validating = false;
  bool _diagRunning = false;
  String? _validateResult;
  String _batteryStatus = '检查中…';
  String _notifStatus = '检查中…';
  String _alarmStatus = '检查中…';

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.storage.token);
    _ownerController = TextEditingController(text: widget.storage.owner);
    _repoController = TextEditingController(text: widget.storage.repo);
    _refreshBatteryStatus();
    _refreshPushStatus();
  }

  /// 查询电池优化白名单状态
  Future<void> _refreshBatteryStatus() async {
    final ignoring = await TimerService.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() => _batteryStatus =
        ignoring ? '已加入白名单 ✅' : '未加入，计时通知可能被系统杀掉');
  }

  /// 请求加入电池优化白名单（跳系统设置页）
  Future<void> _requestBatteryWhitelist() async {
    await TimerService.requestIgnoreBatteryOptimization();
    await Future.delayed(const Duration(seconds: 1));
    await _refreshBatteryStatus();
  }

  /// 刷新推送权限状态（通知权限 + 精确闹钟）
  Future<void> _refreshPushStatus() async {
    final notif = await widget.notifications.areNotificationsEnabled();
    final exact = await widget.notifications.canScheduleExact();
    if (!mounted) return;
    setState(() {
      _notifStatus = notif ? '已授权 ✅' : '未授权，收不到任何推送';
      _alarmStatus = exact
          ? '可用 ✅（准点送达）'
          : '未授权（Android 12+），推送可能延迟最多 15 分钟';
    });
  }

  /// 请求通知权限（Android 13+ 弹窗）
  Future<void> _requestNotificationPermission() async {
    await widget.notifications.requestPermission();
    await _refreshPushStatus();
  }

  /// 跳转系统「闹钟和提醒」授权页
  Future<void> _openExactAlarmSettings() async {
    await widget.notifications.openExactAlarmSettings();
    await Future.delayed(const Duration(seconds: 1));
    await _refreshPushStatus();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _ownerController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  /// 同步自查：显示每一步的真实 HTTP 状态码
  Future<void> _runDiagnostics() async {
    await _saveConfig();
    if (!mounted) return;
    setState(() => _diagRunning = true);
    final lines = await widget.github.runDiagnostics();
    if (!mounted) return;
    setState(() => _diagRunning = false);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('同步自查结果'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines) Text(l, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 保存 GitHub 配置
  Future<void> _saveConfig() async {
    widget.github.token = _tokenController.text.trim();
    widget.github.owner = _ownerController.text.trim();
    widget.github.repo = _repoController.text.trim();

    await widget.storage.setToken(_tokenController.text.trim());
    await widget.storage.setOwner(_ownerController.text.trim());
    await widget.storage.setRepo(_repoController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
      widget.onConfigured?.call();
    }
  }

  /// 验证 Token
  Future<void> _validateToken() async {
    await _saveConfig();
    setState(() {
      _validating = true;
      _validateResult = null;
    });

    final ok = await widget.github.validateToken();
    setState(() {
      _validating = false;
      _validateResult = ok ? '✅ Token 有效，可以访问仓库' : '❌ Token 无效或无法访问仓库，请检查';
    });
  }

  /// 选择推送时间
  Future<void> _pickPushTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: widget.storage.pushHour, minute: widget.storage.pushMinute),
    );
    if (picked != null) {
      await widget.storage.setPushTime(picked.hour, picked.minute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('推送时间已设为 ${picked.format(context)}')),
        );
      }
    }
  }

  /// 发送测试通知
  Future<void> _sendTestNotification() async {
    await widget.notifications.requestPermission();
    await widget.notifications.sendTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('测试通知已发送，请查看通知栏')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === GitHub 配置 ===
          const Text('🔗 GitHub 配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _tokenController,
                    obscureText: !_tokenVisible,
                    decoration: InputDecoration(
                      labelText: 'Personal Access Token',
                      hintText: 'ghp_ 开头的一串字符',
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
                          controller: _ownerController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _repoController,
                          decoration: const InputDecoration(
                            labelText: '仓库名',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _validating ? null : _validateToken,
                          icon: _validating
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check_circle),
                          label: const Text('保存并验证'),
                        ),
                      ),
                    ],
                  ),
                  if (_validateResult != null) ...[
                    const SizedBox(height: 8),
                    Text(_validateResult!, style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _diagRunning ? null : _runDiagnostics,
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: Text(_diagRunning ? '自查中…' : '同步自查（读不到数据时点这里）'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('如何创建 Token'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('1. 打开 github.com/settings/tokens'),
                              Text('2. Generate new token (classic)'),
                              Text('3. Note 填：StudyPulse'),
                              Text('4. Expiration 选：No expiration'),
                              Text('5. 勾选 ☑️ repo'),
                              Text('6. 生成后复制 ghp_ 开头的字符'),
                              Text(''),
                              Text('⚠️ 若用 Fine-grained Token：'),
                              Text('只勾选仓库不够，必须在'),
                              Text('Repository permissions 里把'),
                              Text('Contents 设为 Read-only。'),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('如何创建 Token？', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // === 推送设置 ===
          const Text('🔔 推送设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('每日推送时间'),
                  subtitle: Text('${widget.storage.pushHour.toString().padLeft(2, '0')}:${widget.storage.pushMinute.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickPushTime,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notification_add),
                  title: const Text('发送测试通知'),
                  subtitle: const Text('验证推送功能是否正常'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _sendTestNotification,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('通知权限'),
                  subtitle: Text(_notifStatus),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _requestNotificationPermission,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alarm),
                  title: const Text('精确闹钟（准点推送）'),
                  subtitle: Text(_alarmStatus),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openExactAlarmSettings,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // === 学习计时 ===
          const Text('⏱ 学习计时', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.battery_saver),
                  title: const Text('后台运行白名单'),
                  subtitle: Text(_batteryStatus),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _requestBatteryWhitelist,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '小米 / 华为等系统的一键省电会杀掉计时通知。加入白名单后计时更稳定；即使被系统杀掉，重新打开 App 也会自动恢复计时（时长不丢）。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // === 数据管理 ===
          const Text('📦 数据管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_sweep),
                  title: const Text('清除本地缓存'),
                  subtitle: const Text('删除缓存的周计划，下次同步重新下载'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await widget.storage.clearCache();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('缓存已清除')),
                    );
                  },
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('StudyPulse v1.0.0'),
                  subtitle: Text('你的 Obsidian 学习系统的安卓窗口'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
