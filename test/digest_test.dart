// 周数据文本测试：结构稳定（主 AI 依赖它落库）
import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/progress.dart';
import 'package:studypulse/models/session.dart';
import 'package:studypulse/models/weekly_plan.dart';

const _plan = '''
# 第2周（2026.9.28 - 10.4）

## 每日安排

| 日期 | 高数 | 编程 | 英语 |
|------|------|------|------|
| 周一 9.28 | A | B | 单词 |
| 周二 9.29 | C | 不动 | 单词 |
''';

StudySession _s(String subject, DateTime t, int seconds, {String note = ''}) => StudySession(
      id: subject, subject: subject, startAt: t,
      endAt: t.add(Duration(seconds: seconds)), minutes: seconds ~/ 60, seconds: seconds,
      source: SessionSource.timer, note: note, dateKey: StudySession.dateKeyOf(t),
    );

void main() {
  final mon = DateTime(2026, 9, 28, 20);
  final tue = DateTime(2026, 9, 29, 20);

  test('周数据包含固定字段（主 AI 解析依赖）', () {
    final plan = WeeklyPlan.parse(_plan, fileName: 'w2.md')!;
    final d = buildDigest(
      plan: plan,
      sessions: [_s('高数', mon, 3600, note: '导数搞懂了'), _s('编程', tue, 1500)],
      completedKeys: {'${StudySession.dateKeyOf(mon)}#高数'},
      now: tue,
    );
    final t = d.toCopyText();
    for (final key in ['【StudyPulse 周数据】', '总时长：', '完成率：', '连续天数：', '各科时长：', '每日完成：', '心得：', '未完成：']) {
      expect(t.contains(key), isTrue, reason: '缺少字段：$key');
    }
    expect(t.contains('导数搞懂了'), isTrue);
    expect(t.contains('9.28 周一'), isTrue);
  });

  test('每日行给出完成比与计时', () {
    final plan = WeeklyPlan.parse(_plan, fileName: 'w2.md')!;
    final d = buildDigest(
      plan: plan, sessions: [_s('高数', mon, 600)], completedKeys: {}, now: tue,
    );
    final line = d.dailyLines.firstWhere((l) => l.startsWith('9.28'));
    expect(line.contains('完成 0/3'), isTrue); // 周一有 高数+编程+英语 三块
    expect(line.contains('计时'), isTrue);
  });

  test('无记录时也不崩，给出明确提示', () {
    final plan = WeeklyPlan.parse(_plan, fileName: 'w2.md')!;
    final t = buildDigest(plan: plan, sessions: [], completedKeys: {}, now: tue).toCopyText();
    expect(t.contains('本周暂无计时记录'), isTrue);
  });
}
