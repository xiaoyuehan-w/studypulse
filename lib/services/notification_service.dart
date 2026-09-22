import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/weekly_plan.dart';

/// 本地通知服务
/// 每天定时推送当天的学习任务
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'studypulse_daily';
  static const String _channelName = '每日学习计划';
  static const String _channelDesc = '每天定时推送当天的学习任务';

  bool _initialized = false;

  /// 初始化通知服务
  Future<void> init() async {
    if (_initialized) return;

    // 初始化时区
    tzdata.initializeTimeZones();
    final localName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localName));

    // Android 初始化
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);

    // 创建通知渠道
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  /// 请求通知权限（Android 13+ 需要）
  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// 根据周计划，设定未来 7 天的每日推送
  /// 每次调用会取消旧的通知并重新设定
  Future<void> scheduleWeeklyNotifications(
    WeeklyPlan plan, {
    int hour = 7,
    int minute = 30,
  }) async {
    // 取消所有旧通知
    await _notifications.cancelAll();

    final now = DateTime.now();

    for (final task in plan.dailyTasks) {
      if (!task.hasTasks) continue;

      // 计算这个周几的下一个日期
      final scheduledDate = _nextWeekday(task.weekday, hour, minute);

      // 如果是过去的时间（今天已经过了推送点），跳到下周
      if (scheduledDate.isBefore(now)) {
        // 不跳过，因为 _nextWeekday 已经处理了
      }

      // 通知 ID：用日期的年月日生成唯一 ID
      final id = _dateToId(scheduledDate);

      final title = '📚 ${task.weekday} ${task.date} 学习计划';
      final body = task.notificationBody;

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'daily_plan_${task.weekday}',
      );
    }
  }

  /// 立即发送一条测试通知
  Future<void> sendTestNotification() async {
    await _notifications.show(
      99999,
      '📚 StudyPulse 测试通知',
      '如果你看到这条通知，说明推送功能正常工作！',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// 取消所有通知
  Future<void> cancelAll() => _notifications.cancelAll();

  /// 计算"下一个周几"的具体日期时间
  /// weekday: 如 "周三"
  static DateTime _nextWeekday(String weekday, int hour, int minute) {
    const map = {
      '周一': 1,
      '周二': 2,
      '周三': 3,
      '周四': 4,
      '周五': 5,
      '周六': 6,
      '周日': 7,
    };
    final target = map[weekday] ?? 1;
    final now = DateTime.now();
    var result = DateTime(now.year, now.month, now.day, hour, minute);

    // 计算到目标周几的天数差
    final diff = (target - now.weekday) % 7;
    result = result.add(Duration(days: diff));

    // 如果今天就是目标周几但已经过了推送时间，加到下周
    if (diff == 0 && now.hour * 60 + now.minute >= hour * 60 + minute) {
      result = result.add(const Duration(days: 7));
    }

    return result;
  }

  /// 日期转唯一通知 ID
  static int _dateToId(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }
}
