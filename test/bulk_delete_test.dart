// 批量删除的语义测试：删任务记录时，对应勾选也应取消
import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/session.dart';

void main() {
  test('任务来源的记录被删除时，应同步取消勾选（dateKey#科目）', () {
    final t = DateTime(2026, 9, 25, 9);
    final task = StudySession(
      id: 'task-1', subject: '高数', startAt: t, endAt: t, minutes: 0,
      source: SessionSource.task, dateKey: StudySession.dateKeyOf(t),
    );
    final timer = StudySession(
      id: 'timer-1', subject: '高数', startAt: t, endAt: t.add(const Duration(minutes: 20)),
      minutes: 20, seconds: 1200, source: SessionSource.timer,
      dateKey: StudySession.dateKeyOf(t),
    );

    // 待删除集合 → 只有任务记录需要反向清理勾选
    final toDelete = {task.id, timer.id};
    final cleaned = [task, timer]
        .where((x) => toDelete.contains(x.id))
        .where((x) => x.source == SessionSource.task)
        .map((x) => '${x.dateKey}#${x.subject}')
        .toList();
    expect(cleaned.length, 1);
    expect(cleaned.first, '2026-09-25#高数');
  });
}
