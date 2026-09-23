// 周计划解析器单元测试
// 替换原模板测试（引用不存在的 MyApp，导致 flutter analyze 报 error）

import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/weekly_plan.dart';

void main() {
  group('WeeklyPlan.parse', () {
    const sampleMarkdown = '''
---
week: 第1周
---

# 第1周（2026.9.23 - 9.29）

## 本周章节目标

| 科目 | 内容 |
|------|------|
| 高数 | 第3讲 导数定义 |

## 每日安排

| 日期 | 高数 | 英语 |
|------|------|------|
| 周三 9.23 | [[31-导数的定义]] | 背单词50个 |
| 周四 9.24 | 不动 | 背单词50个 |
''';

    test('解析周标题与日期范围', () {
      final plan = WeeklyPlan.parse(sampleMarkdown);
      expect(plan, isNotNull);
      expect(plan!.weekLabel, '第1周');
      expect(plan.dateRange, '2026.9.23 - 9.29');
      expect(plan.startDate, DateTime(2026, 9, 23));
      expect(plan.endDate, DateTime(2026, 9, 29));
    });

    test('解析每日安排并去除 wikilink 标记', () {
      final plan = WeeklyPlan.parse(sampleMarkdown)!;
      expect(plan.dailyTasks, hasLength(2));

      final wed = plan.dailyTasks[0];
      expect(wed.weekday, '周三');
      expect(wed.date, '9.23');
      expect(wed.subjects['高数'], '31-导数的定义');
      expect(wed.subjects['英语'], '背单词50个');
    });

    test('解析章节目标', () {
      final plan = WeeklyPlan.parse(sampleMarkdown)!;
      expect(plan.goals, hasLength(1));
      expect(plan.goals[0].subject, '高数');
      expect(plan.goals[0].content, '第3讲 导数定义');
    });

    test('空文本返回 null', () {
      expect(WeeklyPlan.parse(''), isNull);
      expect(WeeklyPlan.parse('   \n  '), isNull);
    });

    test('hasTasks 排除"不动"与"—"', () {
      final idle = DailyTask(weekday: '周四', date: '9.24', subjects: {'高数': '不动'});
      expect(idle.hasTasks, isFalse);

      final dash = DailyTask(weekday: '周五', date: '9.25', subjects: {'高数': '—'});
      expect(dash.hasTasks, isFalse);

      final active = DailyTask(weekday: '周三', date: '9.23', subjects: {'高数': '第3讲'});
      expect(active.hasTasks, isTrue);
    });
  });
}
