import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weekly_plan.dart';
import '../services/github_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/timer_service.dart';
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
  Set<String> _completed = {};

  /// 进行中的学习会话 {subject, start_ts}
  Map<String, dynamic>? _currentSession;

  /// 今日各科目已学分钟（供卡片展示；PR-3 打卡统计直接复用底层数据）
  Map<String, int> _dailyMinutes = {};

  /// 刷新"已学 X 分钟"显示的定时器
  Timer? _ticker;

  static const List<String> _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _restoreSession();
    _loadPlan();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 今日日期键（yyyy-MM-dd），跨天自动切换
  String get _todayDateKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// 恢复未结束的计时（杀进程/重启手机后仍能续上，时长基于时间戳）
  Future<void> _restoreSession() async {
    final session = widget.storage.getCurrentSession();
    if (session == null) return;
    final subject = session['subject'] as String? ?? '';
    final startMs = (session['start_ts'] as num?)?.toInt() ?? 0;
    if (subject.isEmpty || startMs <= 0) return;

    setState(() => _currentSession = session);
    _startTicker();
    // 确保前台服务在跑（被系统杀掉时重启通知栏计时）
    await TimerService.start(
        subject, DateTime.fromMillisecondsSinceEpoch(startMs));
  }

  /// 计时显示刷新（半分钟一次即可满足分钟级精度，省电）
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _currentSession != null) setState(() {});
    });
  }

  /// 本次计时已进行的分钟数
  int _elapsedMinutes() {
    final session = _currentSession;
    if (session == null) return 0;
    final startMs = (session['start_ts'] as num?)?.toInt() ?? 0;
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(startMs))
        .inMinutes;
  }

  /// 开始学习某科目
  Future<void> _startStudy(String subject) async {
    final now = DateTime.now();
    await widget.storage.startSession(subject, now);
    final serviceOk = await TimerService.start(subject, now);
    if (!mounted) return;
    setState(() {
      _currentSession = {
        'subject': subject,
        'start_ts': now.millisecondsSinceEpoch,
      };
    });
    _startTicker();
    if (!serviceOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('计时已开始（通知栏服务启动失败，请检查通知权限）'),
      ));
    }
  }

  /// 结束学习并记录时长
  Future<void> _stopStudy() async {
    final session = _currentSession;
    if (session == null) return;
    final subject = session['subject'] as String? ?? '';
    final startMs = (session['start_ts'] as num?)?.toInt() ?? 0;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final end = DateTime.now();
    final minutes = end.difference(start).inMinutes;

    await widget.storage.addCompletedSession(_todayDateKey, subject, start, end);
    await widget.storage.clearCurrentSession();
    await TimerService.stop();
    _ticker?.cancel();

    if (!mounted) return;
    setState(() {
      _currentSession = null;
      _dailyMinutes = widget.storage.getDailyMinutes(_todayDateKey);
    });

    // 非阻塞提示：10 秒自动消失，无操作按钮；调整入口在科目卡片上
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已记录：$subject $minutes 分钟'),
      duration: const Duration(seconds: 10),
    ));
  }

  /// 打开调整面板（用户主动点击卡片时长区才进入，非阻塞设计）
  Future<void> _openAdjustSheet(String subject) async {
    final original = _dailyMinutes[subject] ?? 0;
    var current = original;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '调整「$subject」今日时长',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '当前 $original 分钟 · 忘记按结束时在此修正',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _stepButton('−5', current >= 5 ? () => setSheetState(() => current -= 5) : null),
                  _stepButton('−1', current >= 1 ? () => setSheetState(() => current -= 1) : null),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$current 分钟',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  _stepButton('+1', () => setSheetState(() => current += 1)),
                  _stepButton('+5', () => setSheetState(() => current += 5)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final delta = current - original;
                        if (delta != 0) {
                          await widget.storage.adjustDailyTotalMinutes(
                              _todayDateKey, subject, delta);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() => _dailyMinutes =
                            widget.storage.getDailyMinutes(_todayDateKey));
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepButton(String label, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(50, 40),
            padding: EdgeInsets.zero,
          ),
          child: Text(label),
        ),
      );

  /// 加载今日完成状态与学习时长
  void _loadLocalState() {
    final completed = widget.storage.getCompletedTasks(_todayDateKey);
    final daily = widget.storage.getDailyMinutes(_todayDateKey);
    if (mounted) {
      setState(() {
        _completed = completed;
        _dailyMinutes = daily;
      });
    }
  }

  /// 切换任务完成状态并持久化
  Future<void> _toggleTask(String taskKey) async {
    final willComplete = !_completed.contains(taskKey);
    setState(() {
      if (willComplete) {
        _completed.add(taskKey);
      } else {
        _completed.remove(taskKey);
      }
    });
    await widget.storage.setTaskCompleted(_todayDateKey, taskKey, willComplete);
  }

  /// 加载周计划：优先从 GitHub 拉取，失败则用本地缓存
  Future<void> _loadPlan() async {
    _loadLocalState(); // 同步刷新完成状态与学习时长（跨天时读取新日期）

    if (!widget.github.isConfigured) {
      // 未配置 Token，尝试读缓存
      final cached = await widget.storage.getCachedWeeklyPlan();
      if (cached != null) {
        // 缓存兜底调度：未配置/断网期间推送也不丢（hub#45）
        await widget.notifications.scheduleWeeklyNotifications(
          cached,
          hour: widget.storage.pushHour,
          minute: widget.storage.pushMinute,
        );
      }
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
        // 写缓存与排通知属于副作用：失败也不能阻断本次显示，
        // 否则「拉到数据但首页仍空白」这类问题会被归因到 Token/网络，误导排查。
        try {
          await widget.storage.cacheWeeklyPlan(plan.rawMarkdown);
          await widget.notifications.scheduleWeeklyNotifications(
            plan,
            hour: widget.storage.pushHour,
            minute: widget.storage.pushMinute,
          );
        } catch (_) {
          // 忽略：缓存/通知失败不影响首页展示
        }
        setState(() {
          _plan = plan;
          _error = null;
        });
      } else {
        // 拉取成功但仓库里没有周计划文件：同样要兜缓存。
        // 否则首页显示空态而「本周计划」页有缓存数据，两页不一致、误导排查。
        final cached = await widget.storage.getCachedWeeklyPlan();
        if (cached != null) {
          try {
            await widget.notifications.scheduleWeeklyNotifications(
              cached,
              hour: widget.storage.pushHour,
              minute: widget.storage.pushMinute,
            );
          } catch (_) {}
        }
        setState(() {
          _plan = cached;
          _error = cached == null
              ? '仓库中暂无周计划文件，请先同步周计划'
              : '仓库中暂无周计划文件，显示的是缓存内容';
        });
      }
    } catch (e) {
      // GitHub 拉取失败，用缓存
      final cached = await widget.storage.getCachedWeeklyPlan();
      if (cached != null) {
        // 缓存兜底调度：断网期间推送不丢（旧计划总比没提醒好，hub#45）
        try {
          await widget.notifications.scheduleWeeklyNotifications(
            cached,
            hour: widget.storage.pushHour,
            minute: widget.storage.pushMinute,
          );
        } catch (_) {}
      }
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
          child: Center(
            child: Text(
              '暂无周计划数据\n请在「设置」点「保存并验证」，确认 Token 能访问仓库（私有库需勾选 repo 权限）\n或检查网络后下拉刷新',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final todayTask = _plan!.todayTask;
    // 当前计划是否覆盖今天：不覆盖说明拿到的不是本周（计划未更新 / 提前生成了别的周）
    final s = _plan!.startDate;
    final e = _plan!.endDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final coversToday = (s == null || e == null || (!today.isBefore(s) && !today.isAfter(e)));
    if (!coversToday) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.update, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  '当前显示的是${_plan!.weekLabel}（${_plan!.dateRange}）\n本周计划可能还没更新，点右上角刷新同步',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
          .map((e) {
        final taskKey = '${e.key}|${e.value}';
        final done = _completed.contains(taskKey);
        final isStudying =
            (_currentSession?['subject'] as String?) == e.key;
        final todayMinutes = _dailyMinutes[e.key] ?? 0;

        return Card(
          child: Column(
            children: [
              ListTile(
                onTap: () => _toggleTask(taskKey),
                leading: _subjectIcon(e.key),
                title: Text(
                  e.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? Colors.grey : null,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? Colors.grey : null,
                    ),
                  ),
                ),
                isThreeLine: true,
                trailing: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? Colors.green : Colors.grey[400],
                ),
              ),
              // 学习计时行
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: isStudying
                          ? Text(
                              '正在学习 · 已学 ${_elapsedMinutes()} 分钟',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            )
                          : (todayMinutes > 0
                              ? InkWell(
                                  onTap: () => _openAdjustSheet(e.key),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '今日已学 $todayMinutes 分钟',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.edit_outlined,
                                            size: 13,
                                            color: Colors.grey[500]),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink()),
                    ),
                    if (isStudying)
                      TextButton.icon(
                        onPressed: _stopStudy,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: const Text('结束学习'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[600],
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: _currentSession == null
                            ? () => _startStudy(e.key)
                            : null, // 同时只允许一门科目计时
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: const Text('开始学习'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
    return CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color));
  }
}
