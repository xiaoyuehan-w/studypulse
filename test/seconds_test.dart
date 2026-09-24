// 回归测试：秒级精度（修复"0 分钟导致不统计"）
import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/progress.dart';
import 'package:studypulse/models/session.dart';

StudySession _s(String subject, int seconds, {SessionSource src = SessionSource.timer}) {
  final t = DateTime(2026, 9, 24, 21, 24);
  return StudySession(
    id: 'x-$subject-$seconds-$src',
    subject: subject,
    startAt: t,
    endAt: t.add(Duration(seconds: seconds)),
    minutes: seconds ~/ 60,
    seconds: seconds,
    source: src,
    dateKey: StudySession.dateKeyOf(t),
  );
}

void main() {
  test('50 秒的记录不会被丢弃（向上取整为 1 分钟）', () {
    final list = [_s('高数', 50)];
    expect(secondsBySubject(list)['高数'], 50);
    expect(minutesBySubject(list)['高数'], 1); // 向上取整，不再是 0
  });

  test('0 秒的记录仍不计入时长', () {
    final list = [_s('高数', 0)];
    expect(secondsBySubject(list), isEmpty);
  });

  test('连续天数：有完成记录（0 秒）也算一天', () {
    final list = [_s('高数', 0, src: SessionSource.task)];
    expect(streakDays(list), 1);
  });

  test('总时长按秒累加、分钟向上取整', () {
    final list = [_s('高数', 90), _s('编程', 50)];
    expect(totalSeconds(list), 140);
    expect(totalMinutes(list), 3); // 2.33 分钟 → 3
  });

  test('旧数据（只有 minutes）仍可用', () {
    final t = DateTime(2026, 9, 24, 9, 0);
    final old = StudySession(
      id: 'old', subject: '英语', startAt: t,
      endAt: t.add(const Duration(minutes: 30)), minutes: 30,
      source: SessionSource.timer, dateKey: StudySession.dateKeyOf(t),
    );
    expect(old.effectiveSeconds, 1800);
    expect(totalMinutes([old]), 30);
  });
}
