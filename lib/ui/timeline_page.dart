// 时间轴页：学习记录（每次学习 / 每次打勾都会在这里留一行）
// 支持：写心得、删除记录、查看各科时长；周数据一键复制（S3 完善，此处先提供）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../models/session.dart';
import 'widgets/donut_chart.dart';

class TimelinePage extends StatefulWidget {
  final AppServices services;
  const TimelinePage({super.key, required this.services});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  String _range = 'week'; // day / week / month
  bool _selecting = false; // 多选模式
  final Set<String> _selected = {};

  AppServices get services => widget.services;

  @override
  Widget build(BuildContext context) {
    final s = services;
    return Scaffold(
      appBar: AppBar(
        title: const Text('时间轴'),
        actions: [
          if (_selecting) ...[
            TextButton(
              onPressed: () => setState(() {
                final all = s.sessions.value.map((e) => e.id).toSet();
                if (_selected.length == all.length) {
                  _selected.clear();
                } else {
                  _selected
                    ..clear()
                    ..addAll(all);
                }
              }),
              child: Text(_selected.length == s.sessions.value.length ? '取消全选' : '全选'),
            ),
            IconButton(
              tooltip: '删除选中',
              icon: const Icon(Icons.delete_outline),
              onPressed: _selected.isEmpty ? null : () => _confirmBulkDelete(context, s),
            ),
            IconButton(
              tooltip: '退出多选',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selecting = false;
                _selected.clear();
              }),
            ),
          ] else ...[
            IconButton(
              tooltip: '批量删除',
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _selecting = true),
            ),
            IconButton(
              tooltip: '复制本周数据（发给主 AI）',
              icon: const Icon(Icons.copy_all),
              onPressed: () async {
                final text = s.digest.toCopyText();
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('本周数据已复制，粘贴给主 AI 即可落库')),
                  );
                }
              },
            ),
          ],
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: s.sessions,
        builder: (_, sessions, __) {
          if (sessions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '还没有记录。\n回「今日」点科目右边的 ▶ 开始计时，或直接勾选完成——\n这里就会出现时间轴。',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final grouped = _groupByDate(sessions);
          final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
          if (_selecting) _selectBar(s);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statsCard(s),
              const SizedBox(height: 8),
              _summary(s),
              const SizedBox(height: 8),
              for (final d in dates) ...[
                Text(_dateLabel(d),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 6),
                ...grouped[d]!.map((x) => _sessionCard(context, s, x)),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  /// 统计卡：区间切换 + 环形图 + 图例（S2 核心）
  Widget _statsCard(AppServices s) {
    return ListenableBuilder(
      listenable: Listenable.merge([s.sessions, s.completed]),
      builder: (_, __) {
        final map = s.minutesIn(_range);
        final entries = map.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final slices = <SubjectSlice>[];
        for (var i = 0; i < entries.length; i++) {
          slices.add(SubjectSlice(
            name: entries[i].key,
            minutes: entries[i].value,
            color: kSliceColors[i % kSliceColors.length],
          ));
        }
        final total = s.minutesTotalIn(_range);
        final c = s.weekCompletion;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('学习分布', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    SegmentedButton<String>(
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(value: 'day', label: Text('日')),
                        ButtonSegment(value: 'week', label: Text('周')),
                        ButtonSegment(value: 'month', label: Text('月')),
                      ],
                      selected: {_range},
                      onSelectionChanged: (v) => setState(() => _range = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DonutChart(
                  slices: slices,
                  centerTop: total == 0 ? '' : DonutLegend.hm(total),
                  centerBottom: total == 0 ? '' : '总计',
                ),
                const SizedBox(height: 12),
                DonutLegend(slices: slices),
                const Divider(height: 24),
                Row(
                  children: [
                    _metric('完成率', '${(c.rate * 100).round()}%',
                        sub: '${c.done}/${c.total}', emphasize: true),
                    _metric('总时长', DonutLegend.hm(total)),
                    _metric('连续天数', '${s.streak} 天'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metric(String label, String value, {String? sub, bool emphasize = false}) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: emphasize ? 20 : 16,
                fontWeight: FontWeight.w700,
                color: emphasize ? const Color(0xFF2F6FED) : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(sub ?? label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      );

  Widget _selectBar(AppServices s) => Container(
        color: const Color(0xFFE8F0FE),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text('已选 ${_selected.length} 条', style: const TextStyle(fontSize: 13)),
            const Spacer(),
            const Text('点条目勾选 · 右上角可全选/删除', style: TextStyle(fontSize: 11)),
          ],
        ),
      );

  Widget _summary(AppServices s) {
    final c = s.weekCompletion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text('本周完成 ${c.done}/${c.total}'),
            const SizedBox(width: 16),
            Text('连续 ${s.streak} 天'),
            const Spacer(),
            Text('记录 ${s.sessions.value.length} 条',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(BuildContext context, AppServices s, StudySession x) {
    final checked = _selected.contains(x.id);
    return Card(
      child: ListTile(
        dense: true,
        leading: _selecting
            ? Checkbox(
                value: checked,
                onChanged: (_) => setState(() {
                  if (checked) {
                    _selected.remove(x.id);
                  } else {
                    _selected.add(x.id);
                  }
                }),
              )
            : CircleAvatar(
                radius: 16,
                child: Text(x.subject.characters.first, style: const TextStyle(fontSize: 13)),
              ),
        title: Row(
          children: [
            Text(x.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(x.timeRange, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        subtitle: Text(
          x.note.trim().isEmpty
              ? '点击填写心得 · ${x.source.label}'
              : '${x.note} · ${x.source.label}',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 完成记录不显示"0 分钟"（豆包顾问意见）
            Text(
              x.source == SessionSource.task ? '已完成' : x.durationLabel,
              style: const TextStyle(fontSize: 12),
            ),
            if (x.isRunning)
              const Text('进行中', style: TextStyle(fontSize: 11, color: Color(0xFF2F6FED))),
          ],
        ),
        onTap: _selecting
            ? () => setState(() {
                  if (checked) {
                    _selected.remove(x.id);
                  } else {
                    _selected.add(x.id);
                  }
                })
            : () => _editSession(context, s, x),
        onLongPress: () => _confirmDelete(context, s, x),
      ),
    );
  }

  /// 编辑这条记录：**时长（分钟）+ 心得**——时长可手动调节（方便测试与补录）
  Future<void> _editSession(BuildContext context, AppServices s, StudySession x) async {
    final noteCtrl = TextEditingController(text: x.note);
    final minCtrl = TextEditingController(
      text: x.source == SessionSource.task ? '' : '${x.effectiveMinutes}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${x.subject} · ${x.timeRange}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (x.source != SessionSource.task)
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '时长（分钟）',
                  helperText: '可手动修改，立即计入统计',
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '心得（今天学到/卡住了什么？）'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    await s.setNote(x.id, noteCtrl.text.trim());
    if (x.source != SessionSource.task) {
      final m = int.tryParse(minCtrl.text.trim());
      if (m != null && m >= 0) await s.setDuration(x.id, m);
    }
  }

  Future<void> _confirmBulkDelete(BuildContext context, AppServices s) async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除选中的 $n 条记录？'),
        content: const Text('删除后统计会同步更新；若删的是"完成"记录，对应勾选也会取消。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await s.deleteSessions(_selected.toList());
    if (!context.mounted) return;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除 $removed 条记录')));
  }

  Future<void> _confirmDelete(BuildContext context, AppServices s, StudySession x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text('${x.subject} · ${x.timeRange} · ${x.durationLabel}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) await s.deleteSession(x.id);
  }

  Map<String, List<StudySession>> _groupByDate(List<StudySession> list) {
    final out = <String, List<StudySession>>{};
    for (final x in list) {
      out.putIfAbsent(x.dateKey, () => []).add(x);
    }
    for (final v in out.values) {
      v.sort((a, b) => b.startAt.compareTo(a.startAt));
    }
    return out;
  }

  String _dateLabel(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final isToday = StudySession.dateKeyOf(DateTime.now()) == key;
    return '${d.month}月${d.day}日 ${weekdays[d.weekday - 1]}${isToday ? ' · 今天' : ''}';
  }
}
