// 本地存储：Token / 设置 / 计划缓存 / 学习记录 / 完成标记
// 原则：App 只读 vault，一切写操作都落在本地（shared_preferences）
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

class LocalStore {
  static const _kToken = 'gh_token';
  static const _kOwner = 'gh_owner';
  static const _kRepo = 'gh_repo';
  static const _kCache = 'weekly_plan_cache';
  static const _kSessions = 'study_sessions';
  static const _kDone = 'completed_keys';
  static const _kPushHour = 'push_hour';
  static const _kPushMinute = 'push_minute';
  static const _kLastSync = 'last_sync_at';

  final SharedPreferences _p;
  LocalStore(this._p);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  // ---------- GitHub 配置 ----------
  String get token => _p.getString(_kToken) ?? '';
  String get owner => _p.getString(_kOwner) ?? '';
  String get repo => _p.getString(_kRepo) ?? '';
  bool get isConfigured => token.isNotEmpty && owner.isNotEmpty && repo.isNotEmpty;

  Future<void> setCredentials({
    required String token,
    required String owner,
    required String repo,
  }) async {
    await _p.setString(_kToken, token.trim());
    await _p.setString(_kOwner, owner.trim());
    await _p.setString(_kRepo, repo.trim());
  }

  // ---------- 推送时间 ----------
  int get pushHour => _p.getInt(_kPushHour) ?? 8;
  int get pushMinute => _p.getInt(_kPushMinute) ?? 0;
  Future<void> setPushTime(int hour, int minute) async {
    await _p.setInt(_kPushHour, hour);
    await _p.setInt(_kPushMinute, minute);
  }

  // ---------- 周计划缓存 ----------
  String? get cachedPlan => _p.getString(_kCache);
  Future<void> cachePlan(String markdown) => _p.setString(_kCache, markdown);
  Future<void> clearCache() async {
    await _p.remove(_kCache);
    await _p.remove(_kLastSync);
  }

  DateTime? get lastSync =>
      DateTime.tryParse(_p.getString(_kLastSync) ?? '');
  Future<void> markSynced() =>
      _p.setString(_kLastSync, DateTime.now().toIso8601String());

  // ---------- 学习记录 ----------
  List<StudySession> get sessions {
    final raw = _p.getString(_kSessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => StudySession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessions(List<StudySession> list) => _p.setString(
        _kSessions,
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );

  Future<void> addSession(StudySession s) async {
    final list = sessions..add(s);
    await saveSessions(list);
  }

  Future<void> updateSession(StudySession updated) async {
    final list = sessions;
    final i = list.indexWhere((s) => s.id == updated.id);
    if (i >= 0) {
      list[i] = updated;
    } else {
      list.add(updated);
    }
    await saveSessions(list);
  }

  Future<void> deleteSession(String id) async {
    final list = sessions..removeWhere((s) => s.id == id);
    await saveSessions(list);
  }

  /// 进行中的那条记录（若有）
  StudySession? get runningSession {
    for (final s in sessions) {
      if (s.isRunning) return s;
    }
    return null;
  }

  // ---------- 任务完成标记 ----------
  Set<String> get completedKeys =>
      (_p.getStringList(_kDone) ?? const <String>[]).toSet();

  Future<void> setCompleted(String key, bool done) async {
    final set = completedKeys;
    if (done) {
      set.add(key);
    } else {
      set.remove(key);
    }
    await _p.setStringList(_kDone, set.toList());
  }
}
