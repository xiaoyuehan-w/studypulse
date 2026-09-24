// 记录与聚合测试：时长分布 / 完成率 / 连续天数 / 周报文本
import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/progress.dart';
import 'package:studypulse/models/session.dart';
import 'package:studypulse/models/weekly_plan.dart';

StudySession _s(String subject, DateTime start, int minutes, {String note = ''}) => StudySession(
      id: '$subject-${start.millisecondsSinceEpoch}',
      subject: subject,
      startAt: start,
      endAt: start.add(Duration(minutes: minutes)),
      minutes: minutes,
      source: SessionSource.timer,
      note: note,
      dateKey: StudySession.dateKeyOf(start),
    );

void main() {
  final mon = DateTime(2026, 9, 21); // 周一
  final tue = DateTime(2026, 9, 22);

  group('聚合', () {
    test('分钟按科目汇总', () {
      final list = [_s('高数', mon, 60), _s('高数', tue, 30), _s('编程', tue, 45)];
      final m = minutesBySubject(list);
      expect(m['高数'], 90);
      expect(m['编程'], 45);
      expect(totalMinutes(list), 135);
    });

    test('周范围（周一起算）', () {
      final list = [
        _s('高数', DateTime(2026, 9, 20), 60), // 上周日 → 不算
        _s('高数', mon, 60), // 本周一 → 算
      ];
      final week = ofWeek(list, now: tue);
      expect(week.length, 1);
    });

    test('连续天数（今天没学可从昨天续）', () {
      final list = [_s('高数', mon, 10), _s('高数', tue, 10)];
      expect(streakDays(list, now: tue), 2);
      final wed = DateTime(2026, 9, 23);
      expect(streakDays(list, now: wed), 2); // 周三还没学，仍算 2
      final fri = DateTime(2026, 9, 25);
      expect(streakDays(list, now: fri), 0); // 断档
    });

    test('会话 JSON 往返', () {
      final s = _s('数学', mon, 25, note: '卡在复合函数');
      final back = StudySession.fromJson(s.toJson());
      expect(back.subject, '数学');
      expect(back.minutes, 25);
      expect(back.note, '卡在复合函数');
      expect(back.dateKey, s.dateKey);
      expect(back.source, SessionSource.timer);
    });
  });

  group('完成率与周报', () {
    test('完成率统计（只算到今天）', () {
      final plan = WeeklyPlan.parse('''
# 第1周（2026.9.21 - 9.27）

## 每日安排

| 日期 | 高数 | 编程 |
|------|------|------|
| 周一 9.21 | A | B |
| 周二 9.22 | C | 不动 |
| 周三 9.23 | D | E |
''', fileName: 'x.md')!;
      final keys = {
        '${StudySession.dateKeyOf(mon)}#高数',
        '${StudySession.dateKeyOf(mon)}#编程',
      };
      final c = completionOf(plan: plan, completedKeys: keys, now: tue);
      expect(c.done, 2);
      expect(c.total, 3); // 周一2 + 周二1（不动不计）
      expect(c.rate, closeTo(2 / 3, 0.001));
    });

    test('周报文本包含关键字段', () {
      final d = buildDigest(
        plan: null,
        sessions: [_s('高数', mon, 90), _s('英语', mon, 20, note: '单词第3天')],
        completedKeys: {},
        now: tue,
      );
      final text = d.toCopyText();
      expect(text, contains('总时长'));
      expect(text, contains('高数'));
      expect(text, contains('单词第3天'));
      expect(text, contains('连续天数'));
    });
  });
}
