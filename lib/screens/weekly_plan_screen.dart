import 'package:flutter/material.dart';
import '../models/weekly_plan.dart';
import '../services/github_service.dart';
import '../services/storage_service.dart';

/// 本周计划页：展示一周 7 天的任务安排
class WeeklyPlanScreen extends StatefulWidget {
  final GitHubService github;
  final StorageService storage;

  const WeeklyPlanScreen({
    super.key,
    required this.github,
    required this.storage,
  });

  @override
  State<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends State<WeeklyPlanScreen> {
  WeeklyPlan? _plan;
  bool _loading = true;

  static const List<String> _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    setState(() => _loading = true);
    try {
      if (widget.github.isConfigured) {
        _plan = await widget.github.getLatestWeeklyPlan();
      }
      _plan ??= await widget.storage.getCachedWeeklyPlan();
    } catch (_) {
      _plan = await widget.storage.getCachedWeeklyPlan();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_plan?.weekLabel ?? '本周计划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlan,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plan == null
              ? const Center(child: Text('暂无周计划数据'))
              : RefreshIndicator(
                  onRefresh: _loadPlan,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _plan!.dailyTasks.length,
                    itemBuilder: (context, index) {
                      final task = _plan!.dailyTasks[index];
                      final now = DateTime.now();
                      final todayWd = _weekdays[now.weekday - 1];
                      final isToday = task.weekday == todayWd;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: isToday
                            ? RoundedRectangleBorder(
                                side: const BorderSide(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: ExpansionTile(
                          initiallyExpanded: isToday,
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isToday ? Colors.blue : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  task.weekday,
                                  style: TextStyle(
                                    color: isToday ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                task.date,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 8),
                                const Text('今天', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ],
                          ),
                          subtitle: task.hasTasks
                              ? Text(
                                  task.subjects.entries
                                      .where((e) => e.value.trim().isNotEmpty && e.value.trim() != '不动')
                                      .map((e) => e.key)
                                      .join(' · '),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                )
                              : Text('休息', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: task.subjects.entries
                                    .where((e) => e.value.trim().isNotEmpty)
                                    .map((e) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 60,
                                                child: Text(
                                                  e.key,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  e.value == '不动' ? '—' : e.value,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    height: 1.4,
                                                    color: e.value == '不动' ? Colors.grey[400] : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
