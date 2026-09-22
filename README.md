# StudyPulse 📚

> 你的 Obsidian 学习系统的安卓窗口 —— 每日计划推送 + 周计划查看

## 这是什么

StudyPulse 是一个安卓 App，它不替代 Obsidian，而是把你 Obsidian 笔记库中已经做好的**周计划**和**学习状态**，以**推送通知 + 简洁界面**的方式送到你手机上。

- 🔔 **每天早上自动推送**当天的学习任务
- 📅 **查看本周计划**，按天分组，高亮今天
- 📊 **学习状态**一目了然
- 🔄 **数据来自 GitHub**，你的 Obsidian 笔记 push 后 App 自动同步
- 📱 **离线可用**，周计划缓存到本地

## 数据来源

App 通过 GitHub Contents API 读取你的 Obsidian 仓库：

```
GitHub 仓库 (learning-system, 私有)
└── 03-规划/
    ├── 周计划/周计划-第X周-YYYY.M.D.md   ← App 读取这个
    └── 共同路线/学习状态-共同.md           ← App 读取这个
```

电脑端 Agent 改完笔记 → `git push` → App 下次打开时自动获取最新。

## 技术栈

- **Flutter** (Dart) — 跨平台，一套代码出安卓 + Windows
- **GitHub REST API** — 读取 markdown 文件
- **flutter_local_notifications** — 每日定时推送
- **shared_preferences** — 本地设置存储
- **path_provider** — 本地文件缓存

## 项目结构

```
lib/
├── main.dart                          # 入口 + 底部导航
├── models/
│   └── weekly_plan.dart               # 周计划数据模型 + markdown 解析器
├── services/
│   ├── github_service.dart            # GitHub API 服务
│   ├── storage_service.dart           # 本地存储（设置 + 缓存）
│   └── notification_service.dart      # 本地通知服务
└── screens/
    ├── home_screen.dart               # 首页：今日任务
    ├── weekly_plan_screen.dart        # 本周计划
    └── settings_screen.dart           # 设置（Token/推送时间/测试）
docs/
├── architecture.md                    # 架构文档
└── ob-data-format.md                  # OB 数据格式说明
```

## 开发环境

- Flutter SDK: `E:\flutter`
- Android Studio: `C:\Program Files\Android\Android Studio`
- Android SDK: `E:\dev-tools\android-sdk`

## 编译运行

```bash
# 安装依赖
flutter pub get

# 查看连接的设备
flutter devices

# 运行到安卓手机（需开启USB调试）
flutter run

# 编译 release APK
flutter build apk --release
```

## 首次配置

1. 打开 App → 底部「设置」
2. 填入 GitHub Personal Access Token（勾 `repo` 权限）
3. 用户名 `xiaoyuehan-w`，仓库名 `learning-system`
4. 点「保存并验证」
5. 设置推送时间（默认 7:30）
6. 点「发送测试通知」验证推送功能
7. 回到首页，下拉同步最新周计划

## 版本

- v1.0.0 — 初始版本：今日任务、本周计划、每日推送、GitHub 同步
