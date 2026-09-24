// 应用服务容器：集中装配 + 对外暴露可监听的界面状态
// 不引入状态管理库——用 ValueNotifier 足够，且改动可追踪
import 'package:flutter/foundation.dart';

import 'data/github_source.dart';
import 'data/local_store.dart';
import 'models/progress.dart';
import 'models/session.dart';
import 'models/weekly_plan.dart';
import 'services/notify_service.dart';
import 'services/sync_service.dart';
import 'services/timer_service.dart';

class AppServices {
  final LocalStore store;
  final GitHubSource github;
  final NotifyService notify;
  final SyncService sync;
  final TimerService timer;

  final ValueNotifier<WeeklyPlan?> plan = ValueNotifier(null);
  final ValueNotifier<PlanSource> source = ValueNotifier(PlanSource.none);
  final ValueNotifier<String?> syncError = ValueNotifier(null);
  final ValueNotifier<List<StudySession>> sessions = ValueNotifier(const []);
  final ValueNotifier<Set<String>> completed = ValueNotifier(const {});
  final ValueNotifier<bool> syncing = ValueNotifier(false);

  AppServices({
    required this.store,
    required this.github,
    required this.notify,
    required this.sync,
    required this.timer,
  });

  /// 启动：读本地 → 后台同步（不阻塞界面）
  Future<void> bootstrap() async {
    github.configure(owner: store.owner, repo: store.repo, token: store.token);
    _loadLocal();
    await notify.init();
    await refresh();
  }

  void _loadLocal() {
    sessions.value = store.sessions;
    completed.value = store.completedKeys;
    loadChecklist();
    final cached = store.cachedPlan;
    if (cached != null && cached.isNotEmpty) {
      plan.value = WeeklyPlan.parse(cached, fileName: 'cache.md');
      source.value = PlanSource.cache;
    }
  }

  /// 同步（可被下拉刷新 / 按钮触发）
  Future<void> refresh() async {
    syncing.value = true;
    try {
      final r = await sync.syncAndSchedule();
      plan.value = r.plan;
      source.value = r.source;
      syncError.value = r.error;
    } finally {
      syncing.value = false;
    }
  }

  // ---------- 任务完成 ----------
  static String completionKey(DateTime day, String subject) =>
      '${StudySession.dateKeyOf(day)}#$subject';

  bool isCompleted(DateTime day, String subject) =>
      completed.value.contains(completionKey(day, subject));

  Future<void> toggleTask(DateTime day, String subject, {int? minutes}) async {
    final key = completionKey(day, subject);
    final now = completed.value.contains(key);
    await store.setCompleted(key, !now);
    completed.value = store.completedKeys;
    // 打勾即写一条记录（时间轴可见）；取消打勾删除对应任务记录
    if (!now) {
      await timer.logTaskDone(subject, minutes: minutes ?? 0);
    } else {
      final list = store.sessions;
      final today = StudySession.dateKeyOf(day);
      list.removeWhere((s) => s.subject == subject && s.dateKey == today && s.source == SessionSource.task);
      await store.saveSessions(list);
    }
    sessions.value = store.sessions;
  }

  // ---------- 计时 ----------
  bool get isRunning => timer.isRunning;
  StudySession? get running => timer.running;

  Future<void> startTimer(String subject) async {
    await timer.start(subject);
    sessions.value = store.sessions;
  }

  Future<void> stopTimer() async {
    await timer.stop();
    sessions.value = store.sessions;
  }

  Future<void> cancelTimer() async {
    await timer.cancel();
    sessions.value = store.sessions;
  }

  Future<void> setNote(String id, String note) async {
    await timer.setNote(id, note);
    sessions.value = store.sessions;
  }

  /// 手动改时长（分钟）
  Future<void> setDuration(String id, int minutes) async {
    await timer.setDuration(id, minutes);
    sessions.value = store.sessions;
  }

  Future<void> deleteSession(String id) async {
    await store.deleteSession(id);
    sessions.value = store.sessions;
  }

  /// 批量删除（同时清理"完成任务"对应的勾选标记，避免完成率虚高）
  Future<int> deleteSessions(Iterable<String> ids) async {
    final idSet = ids.toSet();
    final all = store.sessions;
    final removed = all.where((x) => idSet.contains(x.id)).toList();
    if (removed.isEmpty) return 0;
    // 1) 删记录
    all.removeWhere((x) => idSet.contains(x.id));
    await store.saveSessions(all);
    // 2) 清勾选标记（任务来源的记录删掉后，完成状态也应取消）
    for (final x in removed) {
      if (x.source == SessionSource.task) {
        await store.setCompleted('${x.dateKey}#${x.subject}', false);
      }
    }
    sessions.value = store.sessions;
    completed.value = store.completedKeys;
    return removed.length;
  }

  /// 最近的计划同步时间（用于"数据新不新"的可见性）
  DateTime? get lastSync => store.lastSync;

  // ---------- 派生数据 ----------
  CompletionStat get weekCompletion => completionOf(
        plan: plan.value,
        completedKeys: completed.value,
      );

  int get streak => streakDays(sessions.value);

  WeeklyDigest get digest => buildDigest(
        plan: plan.value,
        sessions: sessions.value,
        completedKeys: completed.value,
      );

  List<StudySession> sessionsOfDay(DateTime d) => ofDate(sessions.value, d);

  // ---------- 验收清单 ----------
  final ValueNotifier<Set<String>> checklistChecked = ValueNotifier(const {});

  void loadChecklist() => checklistChecked.value = store.checklistDone;

  bool isChecklistDone(String planFile, int index) =>
      checklistChecked.value.contains('$planFile#$index');

  Future<void> toggleChecklist(String planFile, int index) async {
    final key = '$planFile#$index';
    final now = checklistChecked.value.contains(key);
    await store.setChecklistDone(key, !now);
    checklistChecked.value = store.checklistDone;
  }

  /// 按区间取时长分布（日/周/月切换用）
  Map<String, int> minutesIn(String range) {
    final now = DateTime.now();
    final list = switch (range) {
      'day' => ofDate(sessions.value, now),
      'month' => ofMonth(sessions.value, now: now),
      _ => ofWeek(sessions.value, now: now),
    };
    return minutesBySubject(list);
  }

  int minutesTotalIn(String range) {
    final m = minutesIn(range);
    return m.values.fold(0, (a, b) => a + b);
  }

  /// 保存 GitHub 配置（设置页用）
  Future<void> saveCredentials({
    required String token,
    required String owner,
    required String repo,
  }) async {
    await store.setCredentials(token: token, owner: owner, repo: repo);
    github.configure(owner: owner, repo: repo, token: token);
  }
}
