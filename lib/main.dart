// StudyPulse —— 学习系统的执行终端
// 唯一闭环：今天做什么 → 打卡/计时 → 时间轴留痕 → 周日复盘
import 'package:flutter/material.dart';

import 'app_services.dart';
import 'data/github_source.dart';
import 'data/local_store.dart';
import 'services/notify_service.dart';
import 'services/sync_service.dart';
import 'services/timer_service.dart';
import 'ui/plan_page.dart';
import 'ui/settings_page.dart';
import 'ui/timeline_page.dart';
import 'ui/today_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  final github = GitHubSource();
  final notify = NotifyService();
  final services = AppServices(
    store: store,
    github: github,
    notify: notify,
    sync: SyncService(github: github, store: store, notify: notify),
    timer: TimerService(store),
  );
  // 先起界面，再后台同步（打开即有内容，不白屏）
  runApp(StudyPulseApp(services: services));
  // ignore: discarded_futures
  services.bootstrap();
}

class StudyPulseApp extends StatelessWidget {
  final AppServices services;
  const StudyPulseApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F6FED),
        useMaterial3: true,
      ),
      home: HomeShell(services: services),
    );
  }
}

class HomeShell extends StatefulWidget {
  final AppServices services;
  const HomeShell({super.key, required this.services});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    final pages = [
      TodayPage(services: s),
      PlanPage(services: s),
      TimelinePage(services: s),
      SettingsPage(services: s),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '今日'),
          NavigationDestination(icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week), label: '本周'),
          NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: '时间轴'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
