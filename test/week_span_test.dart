// 回归测试：计划是「周三→周二」（跨周）时，统计不能错配到本周的周一/周二
import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/progress.dart';
import 'package:studypulse/models/session.dart';
import 'package:studypulse/models/weekly_plan.dart';

const _wedToTue = '''
# 第1周（2026.9.23 - 9.29）

## 每日安排

| 日期 | 高数 | 编程 | 英语 |
|------|------|------|------|
| 周三 9.23 | A | B | 单词 |
| 周四 9.24 | C | D | 单词 |
| 周五 9.25 | E | F | 单词 |
| 周六 9.26 | G | H | 单词 |
| 周日 9.27 | I | J | 单词 |
| 周一 9.28 | K | L | 单词 |
| 周二 9.29 | M | N | 单词 |
''';

void main() {
  final plan = WeeklyPlan.parse(_wedToTue, fileName: 'w1.md')!;
  final thu = DateTime(2026, 9, 24); // 周四（今天）

  test('按日期匹配：周四 9.24 取到「周四」那行，而不是「周一 9.28」', () {
    final t = plan.getTaskForDate(thu);
    expect(t, isNotNull);
    expect(t!.weekday, '周四');
    expect(t.subjects['高数'], 'C');
  });

  test('未覆盖的日期不返回任务（9.21 周一不属于本计划）', () {
    expect(plan.getTaskForDate(DateTime(2026, 9, 21)), isNull);
  });

  test('覆盖日期解析正确', () {
    final dates = plan.coveredDates;
    expect(dates.first, DateTime(2026, 9, 23));
    expect(dates.last, DateTime(2026, 9, 29));
  });

  test('完成率只算到今天就止（0/6，而不是把下周一/二也算进来）', () {
    final c = completionOf(plan: plan, completedKeys: {}, now: thu);
    expect(c.total, 6); // 周三 3 + 周四 3
    expect(c.done, 0);
  });

  test('打勾后完成率正确', () {
    final keys = {
      '${StudySession.dateKeyOf(thu)}#高数',
      '${StudySession.dateKeyOf(thu)}#编程',
    };
    final c = completionOf(plan: plan, completedKeys: keys, now: thu);
    expect(c.done, 2);
    expect(c.total, 6);
  });
}
