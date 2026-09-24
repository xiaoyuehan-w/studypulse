// 时间轴页：学习记录（每次学习 / 每次打勾都会在这里留一行）
// 支持：写心得、删除记录、查看各科时长；周数据一键复制（S3 完善，此处先提供）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../models/session.dart';

class TimelinePage extends StatelessWidget {
  final AppServices services;
  const TimelinePage({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final s = services;
    return Scaffold(
      appBar: AppBar(
        title: const Text('时间轴'),
        actions: [
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
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
            Text(x.durationLabel, style: const TextStyle(fontSize: 12)),
            if (x.isRunning)
              const Text('进行中', style: TextStyle(fontSize: 11, color: Color(0xFF2F6FED))),
          ],
        ),
        onTap: () => _editNote(context, s, x),
        onLongPress: () => _confirmDelete(context, s, x),
      ),
    );
  }

  Future<void> _editNote(BuildContext context, AppServices s, StudySession x) async {
    final ctrl = TextEditingController(text: x.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${x.subject} · 心得'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: '今天学到/卡住了什么？'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) await s.setNote(x.id, ctrl.text.trim());
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
