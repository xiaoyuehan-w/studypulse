// 今日页：三块卡片（主科 / 编程 / 英语）+ 计时 + 打卡 + 完成率
import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/session.dart';
import '../models/weekly_plan.dart';

class TodayPage extends StatefulWidget {
  final AppServices services;
  const TodayPage({super.key, required this.services});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  Timer? _ticker;
  /// 秒表节拍：用 ValueNotifier 驱动局部刷新，
  /// 避免依赖父级 setState（此前出现"停在 16 秒不动、切页才刷新"的问题）
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick.value++; // 每秒 +1，界面按需监听
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyPulse'),
        actions: [
          IconButton(
            tooltip: '同步',
            icon: const Icon(Icons.refresh),
            onPressed: s.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListenableBuilder(
          // 同时监听：计划变化 / 记录变化（打卡·计时起停）/ 每秒节拍
          listenable: Listenable.merge([s.plan, s.sessions, _tick]),
          builder: (_, __) {
            final plan = s.plan.value; // 从服务容器读取最新计划
            return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(s, plan, today),
              if (s.running != null) _runningBar(s.running!),
              if (s.syncError.value != null) _errorBanner(s.syncError.value!),
              const SizedBox(height: 8),
              ..._subjectCards(s, plan, today),
              const SizedBox(height: 12),
              _footer(s),
            ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(AppServices s, WeeklyPlan? plan, DateTime today) {
    final c = s.weekCompletion;
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final wd = weekdays[today.weekday - 1];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$wd · ${today.year}年${today.month}月${today.day}日',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  plan == null ? '暂无周计划' : '${plan.weekLabel} · 本周完成 ${c.done}/${c.total}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const Spacer(),
                if (s.syncing.value)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) => Card(
        color: const Color(0xFFFFF4E5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
      );

  List<Widget> _subjectCards(AppServices s, WeeklyPlan? plan, DateTime today) {
    final task = plan?.getTaskForDate(today);
    if (plan == null) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('还没有周计划数据：\n请在「设置」确认 Token，然后下拉刷新', textAlign: TextAlign.center)),
          ),
        ),
      ];
    }
    if (task == null) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '当前显示的是${plan.weekLabel}（${plan.dateRange}）\n本周计划可能还没更新，点右上角刷新',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ];
    }

    final running = s.running;
    final entries = task.subjects.entries.where((e) => DailyTask.isRealTask(e.value)).toList();
    if (entries.isEmpty) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('今天没有安排学习任务，休息一下吧 ☕')),
          ),
        ),
      ];
    }

    return [
      for (final e in entries)
        _subjectCard(
          subject: e.key,
          content: e.value,
          done: s.isCompleted(today, e.key),
          running: running != null && running.subject == e.key,
          runningLabel: null, // 标签由 _elapsedOf 实时计算，避免闭包捕获旧值
        ),
    ];
  }

  Widget _subjectCard({
    required String subject,
    required String content,
    required bool done,
    required bool running,
    String? runningLabel,
  }) {
    final s = widget.services;
    final live = s.running;
    final isThisRunning = running && live != null && live.subject == subject;
    final elapsed = isThisRunning ? _elapsed(live) : runningLabel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Checkbox(
              value: done,
              onChanged: (_) => s.toggleTask(DateTime.now(), subject),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (done) ...[
                        const SizedBox(width: 6),
                        const Text('已完成', style: TextStyle(fontSize: 11, color: Colors.green)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(content, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                ],
              ),
            ),
            if (isThisRunning) ...[
              Text(elapsed ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(width: 4),
            ],
            // 同一个按钮，图形随状态切换：▶ 开始 ⇄ ⏹ 结束
            IconButton(
              tooltip: isThisRunning ? '结束计时' : '开始计时',
              icon: Icon(
                isThisRunning ? Icons.stop_circle : Icons.play_circle_outline,
                color: isThisRunning ? Colors.redAccent : null,
              ),
              onPressed: isThisRunning ? s.stopTimer : () => s.startTimer(subject),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部"正在计时"状态条（除了卡片，另一处可见的计时反馈）
  Widget _runningBar(StudySession x) {
    return Card(
      color: const Color(0xFFE8F0FE),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF2F6FED)),
            const SizedBox(width: 8),
            Expanded(child: Text('正在计时：${x.subject}')),
            Text(_elapsed(x), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _elapsed(StudySession s) {
    final m = s.effectiveMinutes;
    final sec = DateTime.now().difference(s.startAt).inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _footer(AppServices s) {
    return ValueListenableBuilder(
      valueListenable: s.sessions,
      builder: (_, __, ___) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('🔥'),
              const SizedBox(width: 8),
              Text('连续学习 ${s.streak} 天'),
              const Spacer(),
              Text('01:00 前睡', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
