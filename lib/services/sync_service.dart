// 同步编排：网络优先、缓存兜底、副作用不阻断显示
// 决策逻辑与副作用分离：决策是纯函数（可单测），副作用各自 try/catch（永不阻断显示）
import '../data/github_source.dart';
import '../data/local_store.dart';
import '../models/weekly_plan.dart';
import 'notify_service.dart';

/// 计划来源
enum PlanSource { github, cache, none }

class SyncResult {
  final WeeklyPlan? plan;
  final PlanSource source;
  final String? error; // 非空 = 可读的失败原因
  SyncResult({required this.plan, required this.source, this.error});
}

class SyncService {
  final GitHubSource github;
  final LocalStore store;
  final NotifyService notify;

  SyncService({required this.github, required this.store, required this.notify});

  /// 纯决策（可单测，永不抛出）：网络优先 → 缓存兜底 → 交代原因
  static Future<SyncResult> resolve({
    required bool configured,
    required Future<WeeklyPlan?> Function() fetch,
    required Future<WeeklyPlan?> Function() readCache,
  }) async {
    if (!configured) {
      final cached = await readCache();
      return SyncResult(
        plan: cached,
        source: cached == null ? PlanSource.none : PlanSource.cache,
        error: cached == null ? '还没配置 GitHub 访问：请在「设置」填入 Token' : null,
      );
    }
    try {
      final plan = await fetch();
      if (plan != null) return SyncResult(plan: plan, source: PlanSource.github);
      final cached = await readCache();
      return SyncResult(
        plan: cached,
        source: cached == null ? PlanSource.none : PlanSource.cache,
        error: cached == null ? '仓库里还没有周计划文件' : '仓库里暂无周计划文件，显示的是上次缓存',
      );
    } catch (e) {
      final cached = await readCache();
      return SyncResult(
        plan: cached,
        source: cached == null ? PlanSource.none : PlanSource.cache,
        error: '$e',
      );
    }
  }

  /// 同步 + 落缓存 + 排通知；返回可展示结果
  Future<SyncResult> syncAndSchedule() async {
    final r = await resolve(
      configured: github.isConfigured,
      fetch: github.fetchCurrentPlan,
      readCache: _readCache,
    );

    if (r.source == PlanSource.github && r.plan != null) {
      await _safeCache(r.plan!.rawMarkdown);
    }
    if (r.plan != null) {
      await _safeSchedule(r.plan!);
    }
    return r;
  }

  Future<WeeklyPlan?> _readCache() async {
    final raw = store.cachedPlan;
    if (raw == null || raw.isEmpty) return null;
    return WeeklyPlan.parse(raw, fileName: 'cache.md');
  }

  Future<void> _safeCache(String markdown) async {
    try {
      await store.cachePlan(markdown);
      await store.markSynced();
    } catch (_) {/* 缓存失败不影响显示 */}
  }

  Future<void> _safeSchedule(WeeklyPlan plan) async {
    try {
      await notify.scheduleWeekly(plan, store.pushHour, store.pushMinute);
    } catch (_) {/* 通知排程失败不影响显示 */}
  }
}
