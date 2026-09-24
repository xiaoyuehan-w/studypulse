import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/weekly_plan.dart';
import 'package:studypulse/services/plan_sync_service.dart';

/// PlanSyncService.resolve 纯决策逻辑单测（hub#45 任务 A）
/// 网络优先、缓存兜底、永不抛出
void main() {
  WeeklyPlan plan(String label) => WeeklyPlan(
        weekLabel: label,
        dateRange: '2026.9.23 - 9.29',
        goals: const [],
        dailyTasks: const [],
        rawMarkdown: '# $label',
        fileName: '$label.md',
      );

  test('网络成功：走 onResolved（缓存+调度），不走 onSchedule', () async {
    var handledWith = '';
    final (result, source) = await PlanSyncService.resolve(
      configured: true,
      fetchLatest: () async => plan('网络版'),
      readCache: () async => plan('缓存版'),
      onResolved: (p) async => handledWith = p.weekLabel,
      onSchedule: (p) async => handledWith = '不应调用:${p.weekLabel}',
    );
    expect(source, PlanSource.network);
    expect(result?.weekLabel, '网络版');
    expect(handledWith, '网络版');
  });

  test('网络失败：用缓存调度，不抛出', () async {
    var scheduledWith = '';
    final (result, source) = await PlanSyncService.resolve(
      configured: true,
      fetchLatest: () async => throw Exception('断网'),
      readCache: () async => plan('缓存版'),
      onResolved: (p) async {},
      onSchedule: (p) async => scheduledWith = p.weekLabel,
    );
    expect(source, PlanSource.cache);
    expect(result?.weekLabel, '缓存版');
    expect(scheduledWith, '缓存版');
  });

  test('网络超时：落入缓存兜底', () async {
    final (result, source) = await PlanSyncService.resolve(
      configured: true,
      fetchLatest: () => Completer<WeeklyPlan?>().future,
      readCache: () async => plan('缓存版'),
      onResolved: (p) async {},
      onSchedule: (p) async {},
      timeout: const Duration(milliseconds: 20),
    );
    expect(source, PlanSource.cache);
    expect(result?.weekLabel, '缓存版');
  });

  test('未配置 + 有缓存：按缓存调度，且不触发网络', () async {
    final (result, source) = await PlanSyncService.resolve(
      configured: false,
      fetchLatest: () async => throw StateError('configured=false 不应调用'),
      readCache: () async => plan('缓存版'),
      onResolved: (p) async {},
      onSchedule: (p) async {},
    );
    expect(source, PlanSource.cache);
    expect(result?.weekLabel, '缓存版');
  });

  test('网络返回 null（目录为空）：落缓存兜底', () async {
    final (result, source) = await PlanSyncService.resolve(
      configured: true,
      fetchLatest: () async => null,
      readCache: () async => plan('缓存版'),
      onResolved: (p) async {},
      onSchedule: (p) async {},
    );
    expect(source, PlanSource.cache);
    expect(result?.weekLabel, '缓存版');
  });

  test('未配置 + 无缓存：静默跳过（首装正常态）', () async {
    final (result, source) = await PlanSyncService.resolve(
      configured: false,
      fetchLatest: () async => null,
      readCache: () async => null,
      onResolved: (p) async {},
      onSchedule: (p) async {},
    );
    expect(source, PlanSource.none);
    expect(result, isNull);
  });

  test('调度回调失败：不抛出', () async {
    final (result, source) = await PlanSyncService.resolve(
      configured: true,
      fetchLatest: () async => plan('网络版'),
      readCache: () async => null,
      onResolved: (p) async => throw Exception('调度被系统拒绝'),
      onSchedule: (p) async {},
    );
    expect(source, PlanSource.none);
    expect(result, isNull);
  });
}
