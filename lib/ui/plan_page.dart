// 本周页：章节目标 + 7 天任务 + 验收清单（只读展示，S2 起可勾选）
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

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
              _reviewCard(context, s, plan),
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
              if (plan.checklistItems.isNotEmpty) _checklist(s, plan),
            ],
          );
        },
      ),
    );
  }

  /// 周日复盘卡：三个关键数字 + 一键复制周数据（发给主 AI 落库）
  Widget _reviewCard(BuildContext context, AppServices s, WeeklyPlan plan) {
    final d = s.digest;
    final c = s.weekCompletion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('本周复盘', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('${plan.weekLabel}（${d.range}）',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _num('完成率', '${(c.rate * 100).round()}%', sub: '${c.done}/${c.total}', strong: true),
                _num('总时长', '${d.totalMinutes ~/ 60}h${(d.totalMinutes % 60)}m'),
                _num('连续天数', '${s.streak} 天'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('复制本周数据（发给主 AI）'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: d.toCopyText()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制：粘贴给主 AI 即可写入周报')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 6),
            Text('每周日复盘一次：看三个数字 → 勾验收清单 → 复制数据发给主 AI',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _num(String label, String value, {String? sub, bool strong = false}) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                  fontSize: strong ? 20 : 16,
                  fontWeight: FontWeight.w700,
                  color: strong ? const Color(0xFF2F6FED) : null,
                )),
            const SizedBox(height: 2),
            Text(sub ?? label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      );

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

  /// 验收清单：可勾选（本地保存，不写回 vault；周日复盘时逐条确认）
  Widget _checklist(AppServices s, WeeklyPlan plan) {
    final items = plan.checklistItems;
    return ListenableBuilder(
      listenable: s.checklistChecked,
      builder: (_, __) {
        final doneCount = List.generate(items.length, (i) => i)
            .where((i) => s.isChecklistDone(plan.fileName, i))
            .length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('验收清单', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('$doneCount/${items.length}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < items.length; i++)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: s.isChecklistDone(plan.fileName, i),
                    onChanged: (_) => s.toggleChecklist(plan.fileName, i),
                    title: Text(items[i], style: const TextStyle(fontSize: 13)),
                  ),
                const SizedBox(height: 4),
                Text('勾选记在本机；周日复盘时我在周报里一起确认',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        );
      },
    );
  }
}
