// 契约解析测试（防止改动打坏 App 与 vault 的约定）
import 'package:flutter_test/flutter_test.dart';
import 'package:studypulse/models/weekly_plan.dart';

const _sample = '''
---
tags: [周计划]
week: 第1周
updated: 2026-09-24
---

# 第1周（2026.9.23 - 9.29）

---

## 本周章节目标

| 科目 | 两人 |
|------|------|
| 高数 | 第3讲：一元微分学概念（共4节） |
| 编程 | C语言入门 + LeetCode每天1道 |
| 408/线代 | 不动 |

---

## 每日安排

| 日期 | 高数 | 编程 | 英语 |
|------|------|------|------|
| 周三 9.23 | 导数的定义 [[31-导数的定义]] | C语言：变量+数据类型 | 单词 |
| 周四 9.24 | 导数的几何意义 [[32-导数的几何意义]] | LeetCode #1 两数之和 | 单词 |
| 周五 9.25 | 高阶导数 | C语言：循环+条件 | — |

---

## 验收清单

**高数：**
- [ ] 能默写导数定义
- [x] 能解释可导与连续的关系
''';

void main() {
  group('WeeklyPlan.parse', () {
    test('解析标题/目标/每日安排', () {
      final p = WeeklyPlan.parse(_sample, fileName: 'x.md');
      expect(p, isNotNull);
      expect(p!.weekLabel, '第1周');
      expect(p.dateRange, '2026.9.23 - 9.29');
      expect(p.startDate, DateTime(2026, 9, 23));
      expect(p.endDate, DateTime(2026, 9, 29));
      expect(p.goals.length, 3);
      expect(p.goals.first.subject, '高数');
      expect(p.dailyTasks.length, 3);
    });

    test('去掉 [[]] 括号但保留链接文字（与旧版行为一致）', () {
      final p = WeeklyPlan.parse(_sample, fileName: 'x.md')!;
      expect(p.dailyTasks[0].subjects['高数'], '导数的定义 31-导数的定义');
      expect(p.dailyTasks[1].subjects['高数'], '导数的几何意义 32-导数的几何意义');
    });

    test('hasTasks 与占位值', () {
      final p = WeeklyPlan.parse(_sample, fileName: 'x.md')!;
      expect(p.dailyTasks[0].hasTasks, isTrue);
      final friday = p.dailyTasks[2];
      expect(friday.subjects['英语'], '—');
      expect(friday.hasTasks, isTrue); // 高数/编程仍是真实任务
    });

    test('coversDate 判断本周', () {
      final p = WeeklyPlan.parse(_sample, fileName: 'x.md')!;
      expect(p.coversDate(DateTime(2026, 9, 24)), isTrue);
      expect(p.coversDate(DateTime(2026, 9, 30)), isFalse);
    });

    test('getTaskForDate 按周几匹配', () {
      final p = WeeklyPlan.parse(_sample, fileName: 'x.md')!;
      expect(p.getTaskForDate(DateTime(2026, 9, 24))!.weekday, '周四');
    });

    test('验收清单提取', () {
      final p = WeeklyPlan.parse(_sample, fileName: 'x.md')!;
      expect(p.checklistItems.length, 2);
      expect(p.checklistItems.first, '能默写导数定义');
    });

    test('空内容返回 null', () {
      expect(WeeklyPlan.parse('', fileName: 'x.md'), isNull);
      expect(WeeklyPlan.parse('   \n  ', fileName: 'x.md'), isNull);
    });
  });
}
