import 'dart:async';

import '../models/weekly_plan.dart';
import 'github_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// 本次推送调度所基于的计划来源
enum PlanSource { network, cache, none }

/// 周计划同步与推送调度（启动自愈 + 缓存兜底）
///
/// 规则（对应 hub Issue #45 任务 A）：
/// 1. 已配置 GitHub → 拉最新周计划（带超时）；成功 → 写缓存 + 按其调度
/// 2. 拉取失败 / 超时 / 未配置 / 目录为空 → 用本地缓存调度（断网也保持推送）
/// 3. 两者皆无 → 静默跳过（首装未配置是正常态）
///
/// ensureScheduled 永不抛出——启动路径的失败只影响本次同步，绝不阻塞 App 打开；
/// 失败原因的具体呈现由首页 _loadPlan 的 UI 路径负责。
class PlanSyncService {
  PlanSyncService({
    required GitHubService github,
    required StorageService storage,
    required NotificationService notifications,
  })  : _github = github,
        _storage = storage,
        _notifications = notifications;

  final GitHubService _github;
  final StorageService _storage;
  final NotificationService _notifications;

  /// App 启动即调用：后台同步并确保推送已调度（配合 unawaited，不阻塞 UI）
  Future<PlanSource> ensureScheduled() async {
    final (_, source) = await resolve(
      configured: _github.isConfigured,
      fetchLatest: () =>
          _github.getLatestWeeklyPlan().timeout(const Duration(seconds: 15)),
      readCache: _storage.getCachedWeeklyPlan,
      onResolved: (plan) async {
        await _storage.cacheWeeklyPlan(plan.rawMarkdown);
        await _notifications.scheduleWeeklyNotifications(
          plan,
          hour: _storage.pushHour,
          minute: _storage.pushMinute,
        );
      },
      onSchedule: (plan) => _notifications.scheduleWeeklyNotifications(
        plan,
        hour: _storage.pushHour,
        minute: _storage.pushMinute,
      ),
    );
    return source;
  }

  /// 纯决策逻辑（可单测）：网络优先、缓存兜底。
  /// 返回 (采用的计划, 来源)；永不抛出。
  static Future<(WeeklyPlan?, PlanSource)> resolve({
    required bool configured,
    required Future<WeeklyPlan?> Function() fetchLatest,
    required Future<WeeklyPlan?> Function() readCache,
    required Future<void> Function(WeeklyPlan plan) onResolved,
    required Future<void> Function(WeeklyPlan plan) onSchedule,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      if (configured) {
        try {
          final plan = await fetchLatest().timeout(timeout);
          if (plan != null) {
            await onResolved(plan);
            return (plan, PlanSource.network);
          }
          // 目录为空等异常态：落缓存兜底
        } catch (_) {
          // 网络失败 / 超时：落缓存兜底
        }
      }
      final cached = await readCache();
      if (cached != null) {
        await onSchedule(cached);
        return (cached, PlanSource.cache);
      }
      return (null, PlanSource.none);
    } catch (_) {
      // 调度本身失败（如系统限制）也不能抛出
      return (null, PlanSource.none);
    }
  }
}
