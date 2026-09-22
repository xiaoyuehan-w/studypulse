import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/github_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/weekly_plan_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化服务
  final storage = StorageService();
  await storage.init();

  final github = GitHubService(
    owner: storage.owner,
    repo: storage.repo,
    token: storage.token,
  );

  final notifications = NotificationService();
  await notifications.init();
  await notifications.requestPermission();

  runApp(StudyPulseApp(
    storage: storage,
    github: github,
    notifications: notifications,
  ));
}

class StudyPulseApp extends StatelessWidget {
  final StorageService storage;
  final GitHubService github;
  final NotificationService notifications;

  const StudyPulseApp({
    super.key,
    required this.storage,
    required this.github,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: MainScreen(
        storage: storage,
        github: github,
        notifications: notifications,
      ),
    );
  }
}

/// 主界面：底部导航栏
class MainScreen extends StatefulWidget {
  final StorageService storage;
  final GitHubService github;
  final NotificationService notifications;

  const MainScreen({
    super.key,
    required this.storage,
    required this.github,
    required this.notifications,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        github: widget.github,
        storage: widget.storage,
        notifications: widget.notifications,
      ),
      WeeklyPlanScreen(
        github: widget.github,
        storage: widget.storage,
      ),
      SettingsScreen(
        github: widget.github,
        storage: widget.storage,
        notifications: widget.notifications,
        onConfigured: () {
          // 配置变更后切回首页刷新
          setState(() => _currentIndex = 0);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '本周',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
