// 学习记录（时间轴的最小单位）
// 一条记录 = 时间轴上的一行：谁（科目）· 什么时候 · 多久 · 怎么来的 · 心得
// 三个来源：计时（开始/结束）· 任务打勾 · 手动补录

/// 记录来源
enum SessionSource {
  timer, // 开始/结束学习计时
  task, // 今日任务打勾完成
  manual, // 手动补录
}

extension SessionSourceLabel on SessionSource {
  String get label => switch (this) {
        SessionSource.timer => '计时',
        SessionSource.task => '已完成',
        SessionSource.manual => '补录',
      };

  static SessionSource fromName(String? s) => switch (s) {
        'task' => SessionSource.task,
        'manual' => SessionSource.manual,
        _ => SessionSource.timer,
      };
}

class StudySession {
  final String id;
  final String subject; // 高数 / 编程 / 英语 / …
  final DateTime startAt;
  final DateTime? endAt; // 进行中为 null
  final int minutes; // 时长（分钟，兼容旧数据）
  final int seconds; // 真实时长（秒）——<1 分钟的记录不再归零
  final SessionSource source;
  final String note; // 心得（可空）
  final String dateKey; // yyyy-MM-dd（按本地日期分组）

  StudySession({
    required this.id,
    required this.subject,
    required this.startAt,
    this.endAt,
    required this.minutes,
    this.seconds = 0,
    required this.source,
    this.note = '',
    required this.dateKey,
  });

  bool get isRunning => endAt == null;

  /// 真实秒数：优先用 seconds（新数据）；旧数据回退 minutes*60；进行中按现在算
  int get effectiveSeconds {
    if (endAt != null) {
      if (seconds > 0) return seconds;
      return minutes * 60;
    }
    final d = DateTime.now().difference(startAt).inSeconds;
    return d < 0 ? 0 : d;
  }

  /// 秒 → 分钟（向上取整：用于**统计口径**，避免 50 秒被算成 0）
  int get effectiveMinutes => (effectiveSeconds + 59) ~/ 60;

  /// 计时显示用 mm:ss —— **向下取整**，从 00:00 起（修：此前用 effectiveMinutes 会 1 秒变 01:01）
  String get clockLabel {
    final sec = effectiveSeconds;
    final m = sec ~/ 60;
    final r = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  /// 展示用时间段：13:48–14:35 / 13:48–进行中
  String get timeRange {
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final end = endAt == null ? '进行中' : hm(endAt!);
    return '${hm(startAt)}–$end';
  }

  String get durationLabel {
    if (isRunning) return '';
    final sec = effectiveSeconds;
    if (sec < 60) return sec <= 0 ? '已完成' : '$sec 秒';
    final m = sec ~/ 60; // 向下取整：61 秒显示「1 分钟」，不夸大
    if (m < 60) return '$m 分钟';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h 小时' : '$h 小时 $r 分';
  }

  StudySession copyWith({DateTime? endAt, int? minutes, int? seconds, String? note}) => StudySession(
        id: id,
        subject: subject,
        startAt: startAt,
        endAt: endAt ?? this.endAt,
        minutes: minutes ?? this.minutes,
        seconds: seconds ?? this.seconds,
        source: source,
        note: note ?? this.note,
        dateKey: dateKey,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'minutes': minutes,
        'seconds': seconds,
        'source': source.name,
        'note': note,
        'dateKey': dateKey,
      };

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
        id: j['id'] as String? ?? '',
        subject: j['subject'] as String? ?? '未分类',
        startAt: DateTime.tryParse(j['startAt'] as String? ?? '') ?? DateTime.now(),
        endAt: j['endAt'] == null ? null : DateTime.tryParse('${j['endAt']}'),
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
        seconds: (j['seconds'] as num?)?.toInt() ?? 0,
        source: SessionSourceLabel.fromName(j['source'] as String?),
        note: j['note'] as String? ?? '',
        dateKey: j['dateKey'] as String? ?? '',
      );

  /// 本地日期键
  static String dateKeyOf(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
