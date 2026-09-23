// 学习统计聚合单元测试（PR-3）
// 覆盖：日汇总 / 周聚合（周一起始、跨天不混淆）/ 空数据

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypulse/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('学习统计聚合', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getDailyTotalMinutes 汇总当天各科目', () async {
      final storage = StorageService();
      await storage.init();
      const day = '2026-09-23';

      await storage.addCompletedSession(
          day, '高数', DateTime(2026, 9, 23, 9, 0), DateTime(2026, 9, 23, 9, 30));
      await storage.addCompletedSession(
          day, '英语', DateTime(2026, 9, 23, 10, 0), DateTime(2026, 9, 23, 10, 15));
      await storage.addCompletedSession(
          day, '高数', DateTime(2026, 9, 23, 14, 0), DateTime(2026, 9, 23, 14, 40));

      // 高数 30+40=70，英语 15 → 总 85
      expect(storage.getDailyMinutes(day), {'高数': 70, '英语': 15});
      expect(storage.getDailyTotalMinutes(day), 85);
    });

    test('getWeekDailyTotals 以周一为起始且只含本周 7 天', () async {
      final storage = StorageService();
      await storage.init();

      // 2026-09-23 是周三；本周一 = 2026-09-21
      await storage.addCompletedSession('2026-09-20', '高数', // 上周日——不应计入
          DateTime(2026, 9, 20, 9, 0), DateTime(2026, 9, 20, 9, 50));
      await storage.addCompletedSession('2026-09-21', '高数', // 周一 60 分钟
          DateTime(2026, 9, 21, 9, 0), DateTime(2026, 9, 21, 10, 0));
      await storage.addCompletedSession('2026-09-23', '英语', // 周三 30 分钟
          DateTime(2026, 9, 23, 9, 0), DateTime(2026, 9, 23, 9, 30));

      final week = storage.getWeekDailyTotals(now: DateTime(2026, 9, 23, 12));

      expect(week.length, 7);
      expect(week.keys.first, '2026-09-21'); // 周一起始
      expect(week.keys.last, '2026-09-27'); // 周日结束
      expect(week['2026-09-21'], 60);
      expect(week['2026-09-23'], 30);
      expect(week['2026-09-22'], 0); // 无记录的日子为 0
      expect(week.containsKey('2026-09-20'), isFalse); // 上周日不在本周
    });

    test('周日归属本周（周日→周一回退 6 天）', () async {
      final storage = StorageService();
      await storage.init();

      // 2026-09-27 是周日；它的本周一是 2026-09-21
      await storage.addCompletedSession('2026-09-27', '高数',
          DateTime(2026, 9, 27, 9, 0), DateTime(2026, 9, 27, 9, 25));

      final week = storage.getWeekDailyTotals(now: DateTime(2026, 9, 27, 20));
      expect(week.keys.first, '2026-09-21');
      expect(week['2026-09-27'], 25);
    });

    test('空数据返回全 0 且不抛异常', () async {
      final storage = StorageService();
      await storage.init();

      final week = storage.getWeekDailyTotals(now: DateTime(2026, 9, 23));
      expect(week.values.every((v) => v == 0), isTrue);
      expect(storage.getDailyTotalMinutes('2026-09-23'), 0);
      expect(storage.getDailyMinutes('2026-09-23'), isEmpty);
    });
  });
}
