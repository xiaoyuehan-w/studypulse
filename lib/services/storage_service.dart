import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weekly_plan.dart';

/// 本地存储服务
/// - SharedPreferences: 保存 GitHub 配置、推送时间等设置
/// - 本地文件: 缓存最新周计划（离线可用）
class StorageService {
  static const String _keyToken = 'github_token';
  static const String _keyOwner = 'github_owner';
  static const String _keyRepo = 'github_repo';
  static const String _keyPushHour = 'push_hour';
  static const String _keyPushMinute = 'push_minute';
  static const String _cachedPlanFileName = 'latest_weekly_plan.md';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // === GitHub 配置 ===

  String get token => _prefs.getString(_keyToken) ?? '';
  Future<void> setToken(String v) => _prefs.setString(_keyToken, v);

  String get owner => _prefs.getString(_keyOwner) ?? '';
  Future<void> setOwner(String v) => _prefs.setString(_keyOwner, v);

  String get repo => _prefs.getString(_keyRepo) ?? '';
  Future<void> setRepo(String v) => _prefs.setString(_keyRepo, v);

  // === 推送时间设置 ===

  int get pushHour => _prefs.getInt(_keyPushHour) ?? 7;
  int get pushMinute => _prefs.getInt(_keyPushMinute) ?? 30;
  Future<void> setPushTime(int hour, int minute) async {
    await _prefs.setInt(_keyPushHour, hour);
    await _prefs.setInt(_keyPushMinute, minute);
  }

  // === 周计划本地缓存 ===

  /// 缓存最新周计划的原始 markdown
  Future<void> cacheWeeklyPlan(String markdown) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_cachedPlanFileName');
    await file.writeAsString(markdown);
  }

  /// 读取缓存的周计划
  Future<WeeklyPlan?> getCachedWeeklyPlan() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cachedPlanFileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return WeeklyPlan.parse(content, fileName: 'cached');
    } catch (_) {
      return null;
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_cachedPlanFileName');
    if (await file.exists()) await file.delete();
  }

  // === 今日任务完成状态 ===
  // 按日期隔离存储：completed_tasks_2026-09-23 -> ["高数|第3讲", ...]
  // 跨天自动切换到新 key，历史数据保留（供 V1.2/V1.3 打卡统计使用）

  String _completedKey(String dateStr) => 'completed_tasks_$dateStr';

  /// 获取某天已完成任务的键集合（任务键格式："科目|任务内容"）
  Set<String> getCompletedTasks(String dateStr) {
    final list = _prefs.getStringList(_completedKey(dateStr)) ?? const [];
    return list.toSet();
  }

  /// 设置某任务的完成状态并持久化
  Future<void> setTaskCompleted(
      String dateStr, String taskKey, bool completed) async {
    final tasks = getCompletedTasks(dateStr);
    if (completed) {
      tasks.add(taskKey);
    } else {
      tasks.remove(taskKey);
    }
    await _prefs.setStringList(_completedKey(dateStr), tasks.toList());
  }
}
