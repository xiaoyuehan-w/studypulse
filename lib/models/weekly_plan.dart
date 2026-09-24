// 周计划数据模型 + 契约解析
// ⚠️ 数据契约（冻结）：路径 / 文件名 / section 名不可擅改，见 docs/数据契约.md
//   路径：10 项目/考研科软/周计划/周计划-第N周-YYYY.M.D.md
//   结构：frontmatter(week) + 「## 本周章节目标」表 + 「## 每日安排」表
// 纯逻辑（无 IO），可单测。

/// 单日任务
class DailyTask {
  final String weekday; // 「周三」
  final String date; // 「9.23」
  final Map<String, String> subjects; // 科目 -> 任务内容（已剥离 [[]]）

  DailyTask({required this.weekday, required this.date, required this.subjects});

  /// 占位值不算任务
  static const _placeholders = ['不动', '—', '-', '不学', '无', '休息'];

  static bool isRealTask(String v) {
    final t = v.trim();
    if (t.isEmpty) return false;
    return !_placeholders.contains(t);
  }

  /// 通知正文：高数：… | 编程：… | 英语：…
  String get notificationBody => subjects.entries
      .where((e) => isRealTask(e.value))
      .map((e) => '${e.key}：${e.value}')
      .join(' | ');

  bool get hasTasks => subjects.values.any(isRealTask);

  Map<String, dynamic> toJson() => {'weekday': weekday, 'date': date, 'subjects': subjects};

  factory DailyTask.fromJson(Map<String, dynamic> j) => DailyTask(
        weekday: j['weekday'] as String? ?? '',
        date: j['date'] as String? ?? '',
        subjects: (j['subjects'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {},
      );
}

/// 本周章节目标
class ChapterGoal {
  final String subject;
  final String content;
  ChapterGoal({required this.subject, required this.content});
}

/// 一周计划（已解析）
class WeeklyPlan {
  final String weekLabel;
  final String dateRange;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ChapterGoal> goals;
  final List<DailyTask> dailyTasks;
  final String rawMarkdown;
  final String fileName;

  WeeklyPlan({
    required this.weekLabel,
    required this.dateRange,
    required this.startDate,
    required this.endDate,
    required this.goals,
    required this.dailyTasks,
    required this.rawMarkdown,
    required this.fileName,
  });

  static const List<String> weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 取某天的任务：**先按日期精确匹配**（防止"周三→周二"这类跨周计划错配），
  /// 再退化为按「周几」匹配（仅当该行没有日期、且本计划覆盖这一天时）
  DailyTask? getTaskForDate(DateTime date) {
    final md = '${date.month}.${date.day}';
    // ① 日期精确匹配（行里写了日期）
    for (final t in dailyTasks) {
      if (t.date.isNotEmpty && t.date == md) return t;
    }
    // ② 无日期信息的行：按周几匹配，但必须落在本计划的日期范围内
    if (!coversDate(date)) return null;
    final wd = weekdays[date.weekday - 1];
    for (final t in dailyTasks) {
      if (t.date.isEmpty && t.weekday == wd) return t;
    }
    return null;
  }

  /// 行对应的具体日期（用于完成率/回归统计）；无法解析返回 null
  DateTime? dateOfTask(DailyTask t) {
    final m = RegExp(r'^(\d{1,2})\.(\d{1,2})$').firstMatch(t.date.trim());
    if (m == null) return null;
    final year = startDate?.year ?? DateTime.now().year;
    final month = int.parse(m.group(1)!);
    final day = int.parse(m.group(2)!);
    var d = DateTime(year, month, day);
    // 跨年计划（12月→1月）修正
    final s0 = startDate;
    if (s0 != null && d.isBefore(s0.subtract(const Duration(days: 3)))) {
      d = DateTime(year + 1, month, day);
    }
    return d;
  }

  /// 本计划覆盖的日期序列（按行日期；无日期的行用周几+周起点推算）
  List<DateTime> get coveredDates {
    final start = startDate;
    if (start == null) return const [];
    final out = <DateTime>[];
    for (final t in dailyTasks) {
      final d = dateOfTask(t) ??
          start.add(Duration(days: weekdays.indexOf(t.weekday).clamp(0, 6)));
      out.add(DateTime(d.year, d.month, d.day));
    }
    return out;
  }

  DailyTask? get todayTask => getTaskForDate(DateTime.now());

  /// 是否覆盖某天（无日期信息时视为覆盖，避免误报）
  bool coversDate(DateTime date) {
    final s = startDate, e = endDate;
    if (s == null || e == null) return true;
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  /// 解析；内容无效返回 null
  static WeeklyPlan? parse(String markdown, {required String fileName}) {
    if (markdown.trim().isEmpty) return null;

    var weekLabel = '';
    var dateRange = '';
    DateTime? startDate, endDate;
    final lines = markdown.split('\n');

    for (final line in lines) {
      final m = RegExp(r'^#\s+(第\d+周)[（(](.+?)[）)]').firstMatch(line);
      if (m != null) {
        weekLabel = m.group(1)!;
        dateRange = m.group(2)!;
        final dm = RegExp(r'(\d{4})\.(\d{1,2})\.(\d{1,2})\s*[-–]\s*(\d{1,2})\.(\d{1,2})')
            .firstMatch(dateRange);
        if (dm != null) {
          final y = int.parse(dm.group(1)!);
          startDate = DateTime(y, int.parse(dm.group(2)!), int.parse(dm.group(3)!));
          endDate = DateTime(y, int.parse(dm.group(4)!), int.parse(dm.group(5)!));
        }
        break;
      }
    }
    if (weekLabel.isEmpty) {
      for (final line in lines) {
        final m = RegExp(r'^week:\s*(.+)').firstMatch(line);
        if (m != null) {
          weekLabel = m.group(1)!.trim();
          break;
        }
      }
    }

    var dailyIdx = -1, goalIdx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('## 每日安排')) dailyIdx = i;
      if (lines[i].startsWith('## 本周章节目标')) goalIdx = i;
    }

    final goals = <ChapterGoal>[];
    if (goalIdx >= 0) {
      for (var i = goalIdx + 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('## ')) break;
        if (!line.startsWith('|')) continue;
        final cols = _splitRow(line);
        if (cols.length < 2 || _isSeparator(cols) || cols[0] == '科目') continue;
        goals.add(ChapterGoal(subject: cols[0], content: cols[1]));
      }
    }

    final dailyTasks = <DailyTask>[];
    if (dailyIdx >= 0) {
      var subjects = <String>[];
      for (var i = dailyIdx + 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('## ')) break;
        if (!line.startsWith('|')) continue;
        final cols = _splitRow(line);
        if (_isSeparator(cols)) continue;
        if (cols.isNotEmpty && (cols[0] == '日期' || cols[0] == '周几')) {
          subjects = cols.sublist(1);
          continue;
        }
        if (cols.length < 2) continue;
        final map = <String, String>{};
        for (var c = 1; c < cols.length; c++) {
          final key = (c - 1 < subjects.length) ? subjects[c - 1] : '科目$c';
          map[key] = _stripLinks(cols[c]);
        }
        final (wd, dt) = _splitWeekdayDate(cols[0]);
        dailyTasks.add(DailyTask(weekday: wd, date: dt, subjects: map));
      }
    }

    if (weekLabel.isEmpty && goals.isEmpty && dailyTasks.isEmpty) return null;

    return WeeklyPlan(
      weekLabel: weekLabel.isEmpty ? fileName : weekLabel,
      dateRange: dateRange,
      startDate: startDate,
      endDate: endDate,
      goals: goals,
      dailyTasks: dailyTasks,
      rawMarkdown: markdown,
      fileName: fileName,
    );
  }

  /// 该计划的验收清单（`## 验收清单` 里的 `- [ ]` 项，供复盘页使用）
  List<String> get checklistItems {
    final out = <String>[];
    var inChecklist = false;
    for (final line in rawMarkdown.split('\n')) {
      final t = line.trim();
      if (t.startsWith('## 验收清单')) {
        inChecklist = true;
        continue;
      }
      if (inChecklist && t.startsWith('## ')) break;
      if (inChecklist) {
        final m = RegExp(r'^-\s*\[[ xX]\]\s*(.+)$').firstMatch(t);
        if (m != null) out.add(m.group(1)!.trim());
      }
    }
    return out;
  }

  static List<String> _splitRow(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|').map((c) => c.trim()).toList();
  }

  static bool _isSeparator(List<String> cols) =>
      cols.isNotEmpty && cols.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));

  static String _stripLinks(String s) => s.replaceAllMapped(
        RegExp(r'\[\[([^\]|]+)(\|([^\]]+))?\]\]'),
        (m) => (m.group(3) ?? m.group(1) ?? '').trim(),
      ).trim();

  static (String, String) _splitWeekdayDate(String cell) {
    final m = RegExp(r'(周[一二三四五六日])\s*(\d{1,2}\.\d{1,2})?').firstMatch(cell);
    if (m != null) return (m.group(1)!, m.group(2) ?? '');
    final dm = RegExp(r'\d{1,2}\.\d{1,2}').firstMatch(cell);
    return ('', dm?.group(0) ?? cell.trim());
  }
}
