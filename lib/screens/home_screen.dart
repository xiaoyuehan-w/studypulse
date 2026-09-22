import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weekly_plan.dart';
import '../services/github_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';

/// 首页：今日学习任务
class HomeScreen extends StatefulWidget {
  final GitHubService github;
  final StorageService storage;
  final NotificationService notifications;

  const HomeScreen({
    super.key,
    required this.github,
    required this.storage,
    required this.notifications,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeeklyPlan? _plan;
  bool _loading = false;
  String? _error;

  static const List<String> _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  /// 加载周计划：优先从 GitHub 拉取，失败则用本地缓存
  Future<void> _loadPlan() async {
    if (!widget.github.isConfigured) {
      // 未配置 Token，尝试读缓存
      final cached = await widget.storage.getCachedWeeklyPlan();
      setState(() {
        _plan = cached;
        _error = cached == null ? '未配置 GitHub 访问，请先到「设置」配置 Token' : null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plan = await widget.github.getLatestWeeklyPlan();
      if (plan != null) {
        await widget.storage.cacheWeeklyPlan(plan.rawMarkdown);
        // 重新设定通知
        await widget.notifications.scheduleWeeklyNotifications(
          plan,
          hour: widget.storage.pushHour,
          minute: widget.storage.pushMinute,
        );
      }
      setState(() => _plan = plan);
    } catch (e) {
      // GitHub 拉取失败，用缓存
      final cached = await widget.storage.getCachedWeeklyPlan();
      setState(() {
        _plan = cached;
        _error = '同步失败（${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}），显示的是缓存内容';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekday = _weekdays[now.weekday - 1];
    final dateStr = DateFormat('yyyy年M月d日').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyPulse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadPlan,
            tooltip: '同步最新计划',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    github: widget.github,
                    storage: widget.storage,
                    notifications: widget.notifications,
                    onConfigured: _loadPlan,
                  ),
                ),
              );
            },
            tooltip: '设置',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPlan,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 日期头部
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$weekday · $dateStr',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _plan?.weekLabel ?? '暂无周计划',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          if (_plan?.dateRange != null && _plan!.dateRange.isNotEmpty)
                            Text(
                              '本周：${_plan!.dateRange}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 错误提示
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ),

                  // 今日任务
                  const Text(
                    '📋 今日任务',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildTodayTasks(weekday),

                  const SizedBox(height: 24),

                  // 本周章节目标
                  if (_plan != null && _plan!.goals.isNotEmpty) ...[
                    const Text(
                      '🎯 本周目标',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._plan!.goals.map((g) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(g.subject.substring(0, 1)),
                            ),
                            title: Text(g.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(g.content),
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  /// 构建今日任务列表
  Widget _buildTodayTasks(String weekday) {
    if (_plan == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('暂无周计划数据，请先同步或配置 GitHub 访问')),
        ),
      );
    }

    final todayTask = _plan!.todayTask;
    if (todayTask == null || !todayTask.hasTasks) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.free_breakfast, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('今天没有安排学习任务，休息一下吧 ☕', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: todayTask.subjects.entries
          .where((e) => e.value.trim().isNotEmpty && e.value.trim() != '不动' && e.value.trim() != '—')
          .map((e) => Card(
                child: ListTile(
                  leading: _subjectIcon(e.key),
                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(e.value, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                  isThreeLine: true,
                ),
              ))
          .toList(),
    );
  }

  /// 科目图标
  Widget _subjectIcon(String subject) {
    IconData icon;
    Color color;
    if (subject.contains('高数') || subject.contains('数学')) {
      icon = Icons.calculate;
      color = Colors.blue;
    } else if (subject.contains('编程') || subject.contains('C语言') || subject.contains('Leet')) {
      icon = Icons.code;
      color = Colors.green;
    } else if (subject.contains('英语')) {
      icon = Icons.language;
      color = Colors.purple;
    } else if (subject.contains('408') || subject.contains('线代') || subject.contains('政治')) {
      icon = Icons.book;
      color = Colors.orange;
    } else {
      icon = Icons.assignment;
      color = Colors.grey;
    }
    return CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color));
  }
}
