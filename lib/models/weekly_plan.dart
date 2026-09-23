// 周计划数据模型
// 对应 vault 中「10 项目/考研科软/周计划/周计划-第X周-YYYY.M.D.md」的格式（PARA 迁移后路径）

/// 单日任务
class DailyTask {
  final String weekday; // 周几，如 "周三"
  final String date; // 日期，如 "9.23"
  final Map<String, String> subjects; // 科目 -> 任务内容（已去除 [[]] 链接）

  DailyTask({
    required this.weekday,
    required this.date,
    required this.subjects,
  });

  /// 获取当天所有任务的可读文本（用于推送通知）
  String get notificationBody {
    final parts = subjects.entries
        .where((e) => e.value.trim().isNotEmpty && e.value.trim() != '不动')
        .map((e) => '${e.key}：${e.value}')
        .toList();
    return parts.join('\n');
  }

  /// 当天是否有实际任务（排除"不动"）
  bool get hasTasks {
    return subjects.values.any((v) =>
        v.trim().isNotEmpty && v.trim() != '不动' && v.trim() != '—');
  }
}

/// 章节目标
class ChapterGoal {
  final String subject;
  final String content;

  ChapterGoal({required this.subject, required this.content});
}

/// 完整周计划
class WeeklyPlan {
  final String weekLabel; // 如 "第1周"
  final String dateRange; // 如 "2026.9.23 - 9.29"
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ChapterGoal> goals; // 本周章节目标
  final List<DailyTask> dailyTasks; // 每日安排
  final String rawMarkdown; // 原始 markdown（用于详情页渲染）
  final String fileName; // 文件名

  WeeklyPlan({
    required this.weekLabel,
    required this.dateRange,
    this.startDate,
    this.endDate,
    required this.goals,
    required this.dailyTasks,
    required this.rawMarkdown,
    required this.fileName,
  });

  /// 根据 DateTime 获取当天的任务
  DailyTask? getTaskForDate(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final wd = weekdays[date.weekday - 1];
    for (final task in dailyTasks) {
      if (task.weekday == wd) return task;
    }
    return null;
  }

  /// 获取今天的任务
  DailyTask? get todayTask => getTaskForDate(DateTime.now());

  /// 从 markdown 文本解析周计划
  static WeeklyPlan? parse(String markdown, {String fileName = ''}) {
    if (markdown.trim().isEmpty) return null;

    var weekLabel = '';
    var dateRange = '';
    DateTime? startDate;
    DateTime? endDate;
    final goals = <ChapterGoal>[];
    final dailyTasks = <DailyTask>[];

    final lines = markdown.split('\n');

    // 1. 解析标题行：# 第1周（2026.9.23 - 9.29）
    for (final line in lines) {
      final m = RegExp(r'^#\s+(第\d+周)[（(](.+?)[）)]').firstMatch(line);
      if (m != null) {
        weekLabel = m.group(1)!;
        dateRange = m.group(2)!;
        // 尝试解析日期
        final dm = RegExp(r'(\d{4})\.(\d{1,2})\.(\d{1,2})\s*[-–]\s*(\d{1,2})\.(\d{1,2})')
            .firstMatch(dateRange);
        if (dm != null) {
          final year = int.parse(dm.group(1)!);
          startDate = DateTime(year, int.parse(dm.group(2)!), int.parse(dm.group(3)!));
          endDate = DateTime(year, int.parse(dm.group(4)!), int.parse(dm.group(5)!));
        }
        break;
      }
    }
    if (weekLabel.isEmpty) {
      //  fallback：从 YAML 的 week 字段
      for (final line in lines) {
        final m = RegExp(r'^week:\s*(.+)').firstMatch(line);
        if (m != null) {
          weekLabel = m.group(1)!.trim();
          break;
        }
      }
    }

    // 2. 找到各 section 的行号
    var dailyIdx = -1;
    var goalIdx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('## 每日安排')) dailyIdx = i;
      if (lines[i].contains('## 本周章节目标')) goalIdx = i;
    }

    // 3. 解析本周章节目标表
    if (goalIdx >= 0) {
      for (var i = goalIdx + 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('## ')) break;
        if (line.startsWith('|') && !line.contains('---') && !line.contains('科目')) {
          final cells = _parseTableRow(line);
          if (cells.length >= 2) {
            goals.add(ChapterGoal(subject: cells[0], content: _cleanWikiLinks(cells[1])));
          }
        }
      }
    }

    // 4. 解析每日安排表
    if (dailyIdx >= 0) {
      List<String>? headers;
      for (var i = dailyIdx + 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('## ')) break;
        if (!line.startsWith('|')) continue;
        if (line.contains('---')) continue; // 分隔行

        final cells = _parseTableRow(line);
        if (cells.isEmpty) continue;

        // 第一行是表头
        if (headers == null) {
          headers = cells;
          continue;
        }

        // 数据行：第一列是"周几 日期"
        final firstCol = cells[0].trim();
        final wdMatch = RegExp(r'(周[一二三四五六日])\s*(\d+\.\d+)?').firstMatch(firstCol);
        if (wdMatch == null) continue;

        final weekday = wdMatch.group(1)!;
        final date = wdMatch.group(2) ?? '';

        final subjects = <String, String>{};
        for (var c = 1; c < headers.length && c < cells.length; c++) {
          subjects[headers[c].trim()] = _cleanWikiLinks(cells[c]);
        }

        dailyTasks.add(DailyTask(weekday: weekday, date: date, subjects: subjects));
      }
    }

    return WeeklyPlan(
      weekLabel: weekLabel,
      dateRange: dateRange,
      startDate: startDate,
      endDate: endDate,
      goals: goals,
      dailyTasks: dailyTasks,
      rawMarkdown: markdown,
      fileName: fileName,
    );
  }

  /// 解析 markdown 表格行，返回单元格列表
  static List<String> _parseTableRow(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
    return trimmed.split('|').map((c) => c.trim()).toList();
  }

  /// 去除 [[]] 链接标记，保留纯文本
  static String _cleanWikiLinks(String text) {
    // [[31-导数的定义]] -> 31-导数的定义
    // [[目标文件|显示文本]] -> 显示文本
    return text.replaceAllMapped(RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'), (m) {
      return m.group(2) ?? m.group(1)!;
    });
  }
}
