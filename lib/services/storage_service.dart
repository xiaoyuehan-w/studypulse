import 'dart:convert';
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

  // === 学习计时 ===
  // current_session: 进行中的会话（开始时间戳实时落盘，杀进程/重启可恢复）
  // study_sessions_YYYY-MM-DD: { "科目": [ {start_ts, end_ts, duration_min}, ... ] }

  static const String _keyCurrentSession = 'current_session';

  String _sessionsKey(String dateStr) => 'study_sessions_$dateStr';

  /// 进行中的学习会话（{subject, start_ts}），无则返回 null
  Map<String, dynamic>? getCurrentSession() {
    final raw = _prefs.getString(_keyCurrentSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 开始计时：写入进行中会话（时间戳落盘）
  Future<void> startSession(String subject, DateTime start) async {
    await _prefs.setString(
      _keyCurrentSession,
      jsonEncode(
          {'subject': subject, 'start_ts': start.millisecondsSinceEpoch}),
    );
  }

  /// 结束计时：清除进行中会话
  Future<void> clearCurrentSession() => _prefs.remove(_keyCurrentSession);

  Map<String, dynamic> _readDaySessions(String dateStr) {
    final raw = _prefs.getString(_sessionsKey(dateStr));
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 记录一条已完成会话（manualMinutes 非空时以手动值为准）
  Future<void> addCompletedSession(
    String dateStr,
    String subject,
    DateTime start,
    DateTime end, {
    int? manualMinutes,
  }) async {
    final day = _readDaySessions(dateStr);
    final list = (day[subject] as List?) ?? <dynamic>[];
    list.add({
      'start_ts': start.millisecondsSinceEpoch,
      'end_ts': end.millisecondsSinceEpoch,
      'duration_min': manualMinutes ?? end.difference(start).inMinutes,
    });
    day[subject] = list;
    await _prefs.setString(_sessionsKey(dateStr), jsonEncode(day));
  }

  /// 调整某天某科目的总时长：差值从最后一条会话往前分摊，明细结构不变
  Future<void> adjustDailyTotalMinutes(
      String dateStr, String subject, int deltaMinutes) async {
    if (deltaMinutes == 0) return;
    final day = _readDaySessions(dateStr);
    final list = (day[subject] as List?) ?? <dynamic>[];
    if (list.isEmpty) return;

    var remaining = deltaMinutes;
    for (var i = list.length - 1; i >= 0 && remaining != 0; i--) {
      final item = Map<String, dynamic>.from(list[i] as Map);
      var current = (item['duration_min'] as num?)?.toInt() ?? 0;
      if (remaining > 0) {
        current += remaining;
        remaining = 0;
      } else if (current + remaining >= 0) {
        current += remaining;
        remaining = 0;
      } else {
        remaining += current; // 本条减到 0，剩余缺口继续往前扣
        current = 0;
      }
      item['duration_min'] = current;
      list[i] = item;
    }
    day[subject] = list;
    await _prefs.setString(_sessionsKey(dateStr), jsonEncode(day));
  }

  /// 某天各科目总学习时长（分钟）—— 供 UI 展示与 PR-3 打卡统计复用
  Map<String, int> getDailyMinutes(String dateStr) {
    final day = _readDaySessions(dateStr);
    final result = <String, int>{};
    day.forEach((subject, value) {
      final list = (value as List?) ?? const [];
      var total = 0;
      for (final item in list) {
        total += ((item as Map)['duration_min'] as num?)?.toInt() ?? 0;
      }
      if (total > 0) result[subject] = total;
    });
    return result;
  }
}
