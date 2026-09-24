// 自绘环形图（不加依赖）：各科时长占比 + 图例
import 'dart:math' as math;

import 'package:flutter/material.dart';

class SubjectSlice {
  final String name;
  final int minutes;
  final Color color;
  SubjectSlice({required this.name, required this.minutes, required this.color});
}

/// 固定色板（按占比降序分配，颜色稳定）
const List<Color> kSliceColors = [
  Color(0xFF2F6FED), // 蓝
  Color(0xFF16A34A), // 绿
  Color(0xFFF59E0B), // 橙
  Color(0xFF9333EA), // 紫
  Color(0xFF0891B2), // 青
  Color(0xFFDC2626), // 红
  Color(0xFF64748B), // 灰
];

class DonutChart extends StatelessWidget {
  final List<SubjectSlice> slices;
  final double size;
  final String centerTop;
  final String centerBottom;

  const DonutChart({
    super.key,
    required this.slices,
    this.size = 170,
    this.centerTop = '',
    this.centerBottom = '',
  });

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return SizedBox(
        height: size,
        child: Center(
          child: Text('这段时间还没有记录', style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(slices),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerTop.isNotEmpty)
                Text(centerTop, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (centerBottom.isNotEmpty)
                Text(centerBottom, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<SubjectSlice> slices;
  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (a, s) => a + s.minutes);
    if (total <= 0) return;

    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    const stroke = 22.0;
    var start = -math.pi / 2; // 从 12 点方向开始
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    for (final s in slices) {
      final sweep = 2 * math.pi * (s.minutes / total);
      paint.color = s.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices.length != slices.length ||
      !List.generate(slices.length, (i) => old.slices[i].minutes == slices[i].minutes).every((x) => x);
}

/// 图例：科目 · 时长 · 百分比
class DonutLegend extends StatelessWidget {
  final List<SubjectSlice> slices;
  const DonutLegend({super.key, required this.slices});

  static String hm(int minutes) => hmFromSeconds(minutes * 60);

  /// 秒 → 人类可读（**统计口径**：不足 1 分钟进位成 1 分；≥1 分钟按分钟向下取整）
  static String hmFromSeconds(int seconds) {
    if (seconds <= 0) return '0 分';
    if (seconds < 60) return '1 分';
    final m = seconds ~/ 60;
    if (m < 60) return '$m 分';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h 小时' : '$h 小时 $r 分';
  }

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (a, s) => a + s.minutes);
    if (total <= 0) return const SizedBox.shrink();
    return Column(
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(s.name, style: const TextStyle(fontSize: 13))),
                Text(hm(s.minutes * 60), style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text('${(s.minutes / total * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
