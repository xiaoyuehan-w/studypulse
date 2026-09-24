// 回归测试：计时显示从 00:00 起（此前 1 秒显示成 01:01）
import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/session.dart';

StudySession _running(int secondsAgo) {
  final start = DateTime.now().subtract(Duration(seconds: secondsAgo));
  return StudySession(
    id: 'r', subject: '高数', startAt: start, minutes: 0,
    source: SessionSource.timer, dateKey: StudySession.dateKeyOf(start),
  );
}

StudySession _done(int seconds) {
  final t = DateTime(2026, 9, 24, 21, 0);
  return StudySession(
    id: 'd', subject: '高数', startAt: t, endAt: t.add(Duration(seconds: seconds)),
    minutes: seconds ~/ 60, seconds: seconds,
    source: SessionSource.timer, dateKey: StudySession.dateKeyOf(t),
  );
}

void main() {
  test('刚点开始 → 00:00 起（不出现 01:xx）', () {
    expect(_running(0).clockLabel, anyOf('00:00', '00:01'));
  });

  test('1 秒 → 00:01（而不是 01:01）', () {
    expect(_running(1).clockLabel, anyOf('00:01', '00:02'));
  });

  test('61 秒 → 01:01', () {
    expect(_done(61).clockLabel, '01:01');
  });

  test('单项记录 61 秒 → 「1 分钟」（向下取整，不夸大）', () {
    expect(_done(61).durationLabel, '1 分钟');
  });

  test('50 秒记录 → 「50 秒」', () {
    expect(_done(50).durationLabel, '50 秒');
  });
}
