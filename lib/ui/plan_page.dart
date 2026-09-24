// 本周页：章节目标 + 7 天任务 + 验收清单（只读展示，S2 起可勾选）
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/weekly_plan.dart';

class PlanPage extends StatelessWidget {
  final AppServices services;
  const PlanPage({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final s = services;
    return Scaffold(
      appBar: AppBar(title: const Text('本周计划')),
      body: ValueListenableBuilder(
        valueListenable: s.plan,
        builder: (_, plan, __) {
          if (plan == null) {
            return const Center(child: Text('暂无周计划数据'));
          }
          final today = DateTime.now();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${plan.weekLabel}（${plan.dateRange}）',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...plan.goals.map((g) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 64,
                                  child: Text(g.subject,
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                                Expanded(child: Text(g.content)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...plan.dailyTasks.map((d) => _dayCard(s, d, today)),
              if (plan.checklistItems.isNotEmpty) _checklist(plan),
            ],
          );
        },
      ),
    );
  }

  Widget _dayCard(AppServices s, DailyTask d, DateTime today) {
    final isToday = _isToday(d, today);
    return Card(
      shape: isToday
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF2F6FED), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ExpansionTile(
        initiallyExpanded: isToday,
        title: Row(
          children: [
            Text(d.weekday, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(d.date, style: TextStyle(color: Colors.grey[600])),
            if (isToday) ...[
              const SizedBox(width: 8),
              const Text('今天', style: TextStyle(color: Color(0xFF2F6FED), fontSize: 12)),
            ],
          ],
        ),
        subtitle: Text(
          d.subjects.entries.where((e) => DailyTask.isRealTask(e.value)).map((e) => e.key).join(' · '),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        children: [
          for (final e in d.subjects.entries)
            ListTile(
              dense: true,
              leading: DailyTask.isRealTask(e.value)
                  ? Icon(
                      s.isCompleted(_dateOf(d, today), e.key)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                    )
                  : const Icon(Icons.remove, size: 20),
              title: Text('${e.key}：${e.value}'),
            ),
        ],
      ),
    );
  }

  bool _isToday(DailyTask d, DateTime today) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return d.weekday == weekdays[today.weekday - 1];
  }

  DateTime _dateOf(DailyTask d, DateTime today) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final idx = weekdays.indexOf(d.weekday);
    if (idx < 0) return today;
    final start = today.subtract(Duration(days: today.weekday - 1));
    return start.add(Duration(days: idx));
  }

  Widget _checklist(WeeklyPlan plan) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('验收清单', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...plan.checklistItems.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_box_outline_blank, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              Text(
                '（打勾功能在下一版开放；当前可在周日的「周数据」里一并确认）',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
}
