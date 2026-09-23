import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 学习计时前台服务
///
/// 设计原则：计时的唯一事实来源是"开始时间戳"（由 StorageService 落盘），
/// 本服务只负责在通知栏实时展示。因此即使服务被国产 ROM 杀掉、手机重启，
/// 重新打开 App 也能从时间戳恢复计时，时长不丢。

/// 任务处理器：运行在独立 isolate，按 Repeat 事件刷新通知文本
class StudyTimerHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    refreshNotification();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// 根据服务侧保存的开始时间戳，刷新通知栏文本
Future<void> refreshNotification() async {
  final subject = await FlutterForegroundTask.getData<String>(key: 'study_subject');
  final startMs = await FlutterForegroundTask.getData<int>(key: 'study_start_ms');
  if (subject == null || subject.isEmpty || startMs == null || startMs == 0) {
    return;
  }
  final minutes = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(startMs))
      .inMinutes;
  await FlutterForegroundTask.updateService(
    notificationTitle: '正在学习：$subject',
    notificationText: '已学 $minutes 分钟 · 打开 App 结束计时',
  );
}

/// 服务启动入口（必须为顶层函数，且标注 vm:entry-point）
@pragma('vm:entry-point')
void studyTimerCallback() {
  FlutterForegroundTask.setTaskHandler(StudyTimerHandler());
}

class TimerService {
  static const int _serviceId = 1001;
  static const String _keySubject = 'study_subject';
  static const String _keyStartMs = 'study_start_ms';

  /// 初始化通知渠道与任务配置（App 启动时调用一次）
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'study_timer',
        channelName: '学习计时',
        channelDescription: '开始学习后常驻显示计时状态',
        onlyAlertOnce: true,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000), // 每分钟刷新"已学X分钟"
        autoRunOnBoot: false, // 恢复逻辑由 App 负责（基于时间戳，更可靠）
        allowWakeLock: true,
      ),
    );
  }

  /// 通知权限检查/申请（Android 13+ 前台服务通知必需）
  static Future<void> ensureNotificationPermission() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// 开始计时：写入状态并启动前台服务
  static Future<bool> start(String subject, DateTime startTime) async {
    await FlutterForegroundTask.saveData(key: _keySubject, value: subject);
    await FlutterForegroundTask.saveData(
        key: _keyStartMs, value: startTime.millisecondsSinceEpoch);

    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.restartService();
      return result is ServiceRequestSuccess;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: '正在学习：$subject',
      notificationText: '已学 0 分钟 · 打开 App 结束计时',
      callback: studyTimerCallback,
    );
    return result is ServiceRequestSuccess;
  }

  /// 结束计时：停止服务并清理服务侧状态
  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    await FlutterForegroundTask.removeData(key: _keySubject);
    await FlutterForegroundTask.removeData(key: _keyStartMs);
  }

  /// 是否已在电池优化白名单
  static Future<bool> isIgnoringBatteryOptimizations() =>
      FlutterForegroundTask.isIgnoringBatteryOptimizations;

  /// 请求加入电池优化白名单（跳转系统设置页）
  static Future<void> requestIgnoreBatteryOptimization() =>
      FlutterForegroundTask.requestIgnoreBatteryOptimization();
}
