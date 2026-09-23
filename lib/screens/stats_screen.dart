import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// 统计页（PR-3）：今日学习时长 / 本周每日时长 / 按科目分类
/// 数据来源：storage 的计时记录（study_sessions），不新建存储结构
class StatsScreen extends StatefulWidget {
  final StorageService storage;

  const StatsScreen({super.key, required this.storage});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const List<String> _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtMinutes(int minutes) {
    if (minutes <= 0) return '0 分钟';
    if (minutes < 60) return '$minutes 分钟';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h 小时' : '$h 小时 $m 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final todayBySubject = widget.storage.getDailyMinutes(todayKey);
    final todayTotal = todayBySubject.values.fold(0, (a, b) => a + b);

    final weekTotals = widget.storage.getWeekDailyTotals(now: now);
    final weekTotal = weekTotals.values.fold(0, (a, b) => a + b);

    final weekBySubject = <String, int>{};
    for (final key in weekTotals.keys) {
      for (final entry in widget.storage.getDailyMinutes(key).entries) {
        weekBySubject[entry.key] = (weekBySubject[entry.key] ?? 0) + entry.value;
      }
    }

    final hasAnyData = weekTotal > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (!hasAnyData)
              _buildEmptyState()
            else ...[
              _buildTodayCard(todayTotal, todayBySubject),
              const SizedBox(height: 16),
              _buildWeekCard(weekTotals, weekTotal, todayKey),
              const SizedBox(height: 16),
              _buildSubjectCard(weekBySubject, weekTotal),
            ],
          ],
        ),
      ),
    );
  }

  /// 空数据状态：引导用户去计时
  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.insights_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              '还没有学习记录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '去「今日」页点科目卡上的「开始学习」计时，\n结束后这里就会显示你的学习统计。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 今日学习卡
  Widget _buildTodayCard(int todayTotal, Map<String, int> bySubject) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今日学习', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _fmtMinutes(todayTotal),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 8),
                if (bySubject.isNotEmpty)
                  Text(
                    '${bySubject.length} 个科目',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            if (bySubject.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._subjectRows(bySubject, todayTotal),
            ],
          ],
        ),
      ),
    );
  }

  /// 本周概览卡（周一起始，7 天进度条）
  Widget _buildWeekCard(
      Map<String, int> weekTotals, int weekTotal, String todayKey) {
    final entries = weekTotals.entries.toList();
    final maxMinutes =
        entries.fold<int>(0, (max, e) => e.value > max ? e.value : max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('本周概览',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  '共 ${_fmtMinutes(weekTotal)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < entries.length; i++) ...[
              _weekDayRow(
                label: _weekdays[i],
                minutes: entries[i].value,
                maxMinutes: maxMinutes,
                isToday: entries[i].key == todayKey,
              ),
              if (i < entries.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _weekDayRow({
    required String label,
    required int minutes,
    required int maxMinutes,
    required bool isToday,
  }) {
    final ratio = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? Colors.blue[700] : null,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(
            minutes > 0 ? '$minutes 分' : '—',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: minutes > 0 ? Colors.grey[800] : Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }

  /// 科目分类卡（本周汇总）
  Widget _buildSubjectCard(Map<String, int> bySubject, int weekTotal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('按科目（本周）',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._subjectRows(bySubject, weekTotal),
          ],
        ),
      ),
    );
  }

  /// 科目行（今日/本周共用）：名称 + 时长占比 + 进度条
  List<Widget> _subjectRows(Map<String, int> bySubject, int total) {
    final entries = bySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) {
      final ratio = total > 0 ? e.value / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(e.key, style: const TextStyle(fontSize: 13)),
                ),
                Text(
                  '${_fmtMinutes(e.value)} · ${(ratio * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
