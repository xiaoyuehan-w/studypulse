// 学习计时
// 设计要点（沿用旧版已验证的设计）：**开始时间戳是唯一事实源**——
// 时长 = 现在 − 开始，所以杀进程/重启后时长不丢，重新打开即可恢复。
import '../data/local_store.dart';
import '../models/session.dart';

class TimerService {
  final LocalStore store;
  TimerService(this.store);

  /// 正在进行的那条记录（若有）
  StudySession? get running => store.runningSession;

  bool get isRunning => running != null;

  /// 开始一段学习（同一时刻只允许一段）
  Future<StudySession> start(String subject) async {
    final exist = running;
    if (exist != null) return exist; // 已在计时则返回现有
    final now = DateTime.now();
    final s = StudySession(
      id: '${now.millisecondsSinceEpoch}',
      subject: subject,
      startAt: now,
      minutes: 0,
      source: SessionSource.timer,
      dateKey: StudySession.dateKeyOf(now),
    );
    await store.addSession(s);
    return s;
  }

  /// 结束当前学习，落一条完成记录
  Future<StudySession?> stop() async {
    final s = running;
    if (s == null) return null;
    final now = DateTime.now();
    final secs = now.difference(s.startAt).inSeconds;
    final safe = secs < 0 ? 0 : secs;
    final done = s.copyWith(endAt: now, seconds: safe, minutes: safe ~/ 60);
    await store.updateSession(done);
    return done;
  }

  /// 取消当前学习（丢弃这条记录）
  Future<void> cancel() async {
    final s = running;
    if (s == null) return;
    await store.deleteSession(s.id);
  }

  /// 任务打勾 → 也在时间轴上留一条记录（控股人要求：划掉一个就进时间轴）
  Future<void> logTaskDone(String subject, {int minutes = 0}) async {
    final now = DateTime.now();
    final s = StudySession(
      id: 'task-${now.millisecondsSinceEpoch}',
      subject: subject,
      startAt: now,
      endAt: now,
      minutes: minutes,
      source: SessionSource.task,
      dateKey: StudySession.dateKeyOf(now),
    );
    await store.addSession(s);
  }

  /// 手动补录
  Future<void> logManual({
    required String subject,
    required DateTime start,
    required int minutes,
    String note = '',
  }) async {
    final end = start.add(Duration(minutes: minutes));
    final s = StudySession(
      id: 'manual-${start.millisecondsSinceEpoch}',
      subject: subject,
      startAt: start,
      endAt: end,
      minutes: minutes,
      source: SessionSource.manual,
      note: note,
      dateKey: StudySession.dateKeyOf(start),
    );
    await store.addSession(s);
  }

  /// 手动调节某条记录的时长（分钟）——控股人要求：方便测试与补录
  Future<void> setDuration(String id, int minutes) async {
    final list = store.sessions;
    for (final s in list) {
      if (s.id == id) {
        final sec = minutes * 60;
        await store.updateSession(s.copyWith(
          minutes: minutes,
          seconds: sec,
          endAt: s.endAt ?? s.startAt.add(Duration(seconds: sec)),
        ));
        return;
      }
    }
  }

  /// 写心得
  Future<void> setNote(String id, String note) async {
    final list = store.sessions;
    for (final s in list) {
      if (s.id == id) {
        await store.updateSession(s.copyWith(note: note));
        return;
      }
    }
  }
}
