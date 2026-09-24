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

  @override
  void initState() {
    super.initState();
    // 计时中每秒刷新时长显示
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.services.isRunning && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
        child: ValueListenableBuilder(
          valueListenable: s.plan,
          builder: (_, plan, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(s, plan, today),
              if (s.syncError.value != null) _errorBanner(s.syncError.value!),
              const SizedBox(height: 8),
              ..._subjectCards(s, plan, today),
              const SizedBox(height: 12),
              _footer(s),
            ],
          ),
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
          runningLabel: running != null && running.subject == e.key ? _elapsed(running) : null,
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
                  Text(subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(content, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                ],
              ),
            ),
            if (running)
              TextButton.icon(
                onPressed: s.stopTimer,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text('结束 $runningLabel'),
              )
            else
              IconButton(
                tooltip: '开始计时',
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () => s.startTimer(subject),
              ),
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
