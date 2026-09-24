// S2 统计层测试：区间聚合（日/周/月）+ 占比口径
import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/progress.dart';
import 'package:studypulse/models/session.dart';

StudySession _s(String subject, DateTime start, int minutes) => StudySession(
      id: '$subject-${start.millisecondsSinceEpoch}',
      subject: subject,
      startAt: start,
      endAt: start.add(Duration(minutes: minutes)),
      minutes: minutes,
      source: SessionSource.timer,
      dateKey: StudySession.dateKeyOf(start),
    );

void main() {
  final today = DateTime(2026, 9, 24);           // 周四
  final yesterday = DateTime(2026, 9, 23);
  final lastMonth = DateTime(2026, 8, 20);
  final data = [
    _s('高数', yesterday, 90),
    _s('编程', today, 30),
    _s('英语', today, 10),
    _s('高数', lastMonth, 60),
  ];

  test('日区间：只含今天', () {
    final day = ofDate(data, today);
    expect(day.length, 2);
    expect(minutesBySubject(day)['编程'], 30);
  });

  test('周区间：含周三与周四，不含上月', () {
    final week = ofWeek(data, now: today);
    expect(week.length, 3);
    expect(totalMinutes(week), 130);
  });

  test('月区间：含上月以外，本月 3 条', () {
    final month = ofMonth(data, now: today);
    expect(month.length, 3);
    expect(minutesBySubject(month)['高数'], 90);
  });

  test('占比口径：各科合计等于总时长', () {
    final week = ofWeek(data, now: today);
    final m = minutesBySubject(week);
    expect(m.values.fold(0, (a, b) => a + b), totalMinutes(week));
  });

  test('活跃天数去重', () {
    expect(activeDays(ofWeek(data, now: today)), 2);
  });

  test('inRange 含首尾两天', () {
    final r = inRange(data, yesterday, today);
    expect(r.length, 3);
  });
}
