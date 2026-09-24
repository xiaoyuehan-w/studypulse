// 进度聚合（纯函数，可单测）
// 全部基于「学习记录」计算：时长分布 / 完成率 / 连续天数 / 周报数据
import 'session.dart';
import 'weekly_plan.dart';

/// 某范围内的时长分布：科目 -> 分钟（降序由调用方处理）
Map<String, int> minutesBySubject(Iterable<StudySession> sessions) {
  final out = <String, int>{};
  for (final s in sessions) {
    final m = s.effectiveMinutes;
    if (m <= 0) continue;
    out[s.subject] = (out[s.subject] ?? 0) + m;
  }
  return out;
}

/// 总分钟
int totalMinutes(Iterable<StudySession> sessions) =>
    sessions.fold(0, (sum, s) => sum + (s.effectiveMinutes > 0 ? s.effectiveMinutes : 0));

/// 按日期过滤（dateKey = yyyy-MM-dd）
List<StudySession> ofDate(List<StudySession> sessions, DateTime date) =>
    sessions.where((s) => s.dateKey == StudySession.dateKeyOf(date)).toList();

/// 本周（周一起算）范围
DateTime weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// 本周记录
List<StudySession> ofWeek(List<StudySession> sessions, {DateTime? now}) {
  final start = weekStart(now ?? DateTime.now());
  final end = start.add(const Duration(days: 7));
  return sessions.where((s) {
    final t = s.startAt;
    return !t.isBefore(start) && t.isBefore(end);
  }).toList();
}

/// 完成率：已打勾任务数 / 有任务的天数×科目数（按当日计划）
class CompletionStat {
  final int done; // 已完成的科目块数
  final int total; // 计划内的科目块总数
  double get rate => total == 0 ? 0 : done / total;
  CompletionStat({required this.done, required this.total});
}

CompletionStat completionOf({
  required WeeklyPlan? plan,
  required Set<String> completedKeys, // 形如 "2026-09-24#高数"
  DateTime? now,
}) {
  if (plan == null) return CompletionStat(done: 0, total: 0);
  final today = now ?? DateTime.now();
  final t0 = DateTime(today.year, today.month, today.day);
  var done = 0, total = 0;
  // 按计划**实际覆盖的日期**统计（不再假设"周一起算"，也不再只看周几）
  for (final day in plan.coveredDates) {
    if (day.isAfter(t0)) break; // 未来不计
    if (day.isBefore(weekStart(t0))) continue; // 只算本周
    final task = plan.getTaskForDate(day);
    if (task == null) continue;
    for (final e in task.subjects.entries) {
      if (!DailyTask.isRealTask(e.value)) continue;
      total++;
      if (completedKeys.contains('${StudySession.dateKeyOf(day)}#${e.key}')) done++;
    }
  }
  return CompletionStat(done: done, total: total);
}

/// 连续学习天数（含今天；今天没学也允许从昨天起算）
int streakDays(List<StudySession> sessions, {DateTime? now}) {
  final keys = sessions
      .where((s) => s.effectiveMinutes > 0)
      .map((s) => s.dateKey)
      .toSet();
  if (keys.isEmpty) return 0;
  final today = now ?? DateTime.now();
  var d = DateTime(today.year, today.month, today.day);
  if (!keys.contains(StudySession.dateKeyOf(d))) {
    d = d.subtract(const Duration(days: 1)); // 今天还没学，允许从昨天续
  }
  var n = 0;
  while (keys.contains(StudySession.dateKeyOf(d))) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

/// 周报数据（供复盘页「一键复制」用；格式固定，便于主 AI 解析）
class WeeklyDigest {
  final String weekLabel;
  final String range;
  final Map<String, int> minutesBySubject;
  final int totalMinutes;
  final CompletionStat completion;
  final int streak;
  final List<String> notes; // 本周心得（非空）
  final List<String> pendingTasks; // 未完成的任务项

  WeeklyDigest({
    required this.weekLabel,
    required this.range,
    required this.minutesBySubject,
    required this.totalMinutes,
    required this.completion,
    required this.streak,
    required this.notes,
    required this.pendingTasks,
  });

  /// 人类可读 + 机器可解析的固定格式（主 AI 收到后可直接落库）
  String toCopyText() {
    final sb = StringBuffer()
      ..writeln('【StudyPulse 周数据】$weekLabel（$range）')
      ..writeln('总时长：${_hm(totalMinutes)}')
      ..writeln('完成率：${completion.done}/${completion.total}'
          '（${(completion.rate * 100).round()}%）')
      ..writeln('连续天数：$streak 天')
      ..writeln('各科时长：');
    final entries = minutesBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in entries) {
      sb.writeln('  - ${e.key}：${_hm(e.value)}');
    }
    if (notes.isNotEmpty) {
      sb.writeln('心得：');
      for (final n in notes) {
        sb.writeln('  - $n');
      }
    }
    if (pendingTasks.isNotEmpty) {
      sb.writeln('未完成：');
      for (final p in pendingTasks) {
        sb.writeln('  - $p');
      }
    }
    return sb.toString();
  }

  static String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h 小时 $m 分';
  }
}

/// 组装周报数据
WeeklyDigest buildDigest({
  required WeeklyPlan? plan,
  required List<StudySession> sessions,
  required Set<String> completedKeys,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final week = ofWeek(sessions, now: today);
  final start = weekStart(today);
  final end = start.add(const Duration(days: 6));
  final range = '${start.month}.${start.day} - ${end.month}.${end.day}';

  final pending = <String>[];
  if (plan != null) {
    for (final day in plan.coveredDates) {
      if (day.isAfter(today)) break;
      final task = plan.getTaskForDate(day);
      if (task == null) continue;
      for (final e in task.subjects.entries) {
        if (!DailyTask.isRealTask(e.value)) continue;
        if (!completedKeys.contains('${StudySession.dateKeyOf(day)}#${e.key}')) {
          pending.add('${day.month}.${day.day} ${e.key}：${e.value}');
        }
      }
    }
  }

  return WeeklyDigest(
    weekLabel: plan?.weekLabel ?? '本周',
    range: range,
    minutesBySubject: minutesBySubject(week),
    totalMinutes: totalMinutes(week),
    completion: completionOf(plan: plan, completedKeys: completedKeys, now: today),
    streak: streakDays(sessions, now: today),
    notes: week.where((s) => s.note.trim().isNotEmpty).map((s) => '${s.subject}：${s.note.trim()}').toList(),
    pendingTasks: pending,
  );
}

/// 某区间内的记录（含起止）
List<StudySession> inRange(List<StudySession> sessions, DateTime from, DateTime to) {
  final f = DateTime(from.year, from.month, from.day);
  final t = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
  return sessions.where((s) => !s.startAt.isBefore(f) && s.startAt.isBefore(t)).toList();
}

/// 某月记录
List<StudySession> ofMonth(List<StudySession> sessions, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final from = DateTime(t.year, t.month, 1);
  final to = DateTime(t.year, t.month + 1, 0); // 当月最后一天
  return inRange(sessions, from, to);
}

/// 有记录的天数（当月，用于"账目感"）
int activeDays(Iterable<StudySession> sessions) =>
    sessions.where((s) => s.effectiveMinutes > 0).map((s) => s.dateKey).toSet().length;
