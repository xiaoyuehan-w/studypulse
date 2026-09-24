// 本地每日推送
// 设计要点（沿用已验证的推送根治经验，hub#45）：
//   · 只做本地定时通知，不经过任何服务器
//   · 按周计划的每日任务排定；无任务的天不排
//   · 权限体检：通知权限 + 精确闹钟，缺一则提示用户
//   · Android 侧需 App 自行在 manifest 声明 receiver/权限（插件不代劳）
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/weekly_plan.dart';

class NotifyService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static const _channelId = 'daily_plan';
  static const _channelName = '每日学习计划';

  Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {/* 取不到时区就用默认 */}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    _inited = true;
  }

  /// 通知权限是否已授予
  Future<bool> hasPermission() async {
    await init();
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await impl?.areNotificationsEnabled();
    return enabled ?? true;
  }

  Future<bool> requestPermission() async {
    await init();
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await impl?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// 是否允许精确闹钟（否则推送可能晚几分钟）
  Future<bool> canExactAlarm() async {
    await init();
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ok = await impl?.canScheduleExactNotifications();
    return ok ?? true;
  }

  Future<void> requestExactAlarm() async {
    await init();
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await impl?.requestExactAlarmsPermission();
  }

  /// 按周计划排定本周 7 天的推送
  Future<void> scheduleWeekly(WeeklyPlan plan, int hour, int minute) async {
    await init();
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var id = 1000;
    for (final day in plan.dailyTasks) {
      if (!day.hasTasks) continue;
      final when = _resolveDateTime(day, hour, minute, now);
      if (when == null || when.isBefore(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id++,
          '${plan.weekLabel} · ${day.weekday}',
          day.notificationBody,
          when,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: '每天推送当日学习任务',
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(''),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'today',
        );
      } catch (e) {
        debugPrint('排推送失败（${day.weekday}）：$e');
      }
    }
  }

  /// 立即发一条测试通知
  Future<void> showTest() async {
    await init();
    await _plugin.show(
      1,
      'StudyPulse 测试通知',
      '看到这条说明推送链路是通的',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// 把「周几 + 日期」解析成本周的具体时刻
  tz.TZDateTime? _resolveDateTime(
    DailyTask day,
    int hour,
    int minute,
    tz.TZDateTime now,
  ) {
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final idx = WeeklyPlan.weekdays.indexOf(day.weekday);
    if (idx < 0) return null;
    final base = weekStart.add(Duration(days: idx));
    final when = tz.TZDateTime(tz.local, base.year, base.month, base.day, hour, minute);
    if (when.isBefore(now)) {
      return when.add(const Duration(days: 7)); // 已过则排到下周同一时刻
    }
    return when;
  }
}
