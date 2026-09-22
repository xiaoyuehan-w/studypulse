# StudyPulse 📚

> 把你的 Obsidian 学习计划推送到手机——每日定时提醒 + 周计划查看

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-blue.svg)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-green.svg)]()

## 这是什么

StudyPulse 是一个**学习计划推送 App**。它不替代 Obsidian，而是把你 Obsidian 笔记库里已经写好的**周计划**和**学习状态**，以**定时通知 + 简洁界面**的方式送到你手机上。

### 核心理念
- **数据唯一来源是 GitHub 上的 Obsidian 仓库**（只读，App 不编辑笔记）
- 电脑端 Agent 改完笔记 → `git push` → App 下次打开自动同步
- 专注"看计划"和"被提醒"，不做编辑和 AI 对话

## 功能特性

- 🔔 **每日定时推送**：每天早上自动推送当天的学习任务（默认 7:30，可自定义）
- 📅 **本周计划查看**：按天分组，高亮今天，可展开/收起
- 📊 **学习状态**：一目了然当前进度
- 🔄 **自动同步**：从 GitHub 仓库拉取最新 markdown，下拉刷新
- 📴 **离线可用**：周计划缓存到本地，没网也能看
- 🌙 **深色模式**：跟随系统
- 📱 **跨平台**：一套 Flutter 代码，未来支持 Android + Windows

## 工作原理

```
Obsidian 笔记库 (GitHub 仓库)
└── 03-规划/
    ├── 周计划/周计划-第X周-YYYY.M.D.md   ← App 读取这个
    └── 共同路线/学习状态-共同.md          ← App 读取这个

电脑端修改笔记 → git push → App 通过 GitHub Contents API 读取 → 展示 + 推送
```

App 通过 **GitHub REST API** 读取仓库中的 markdown 文件，解析后展示。需要你提供一个有仓库读取权限的 Personal Access Token。

## 快速开始

### 1. 环境要求
- Flutter SDK 3.47.5+
- Android SDK 36+（编译安卓）
- Visual Studio 2022（编译 Windows 端，可选）

### 2. 编译运行
```bash
# 克隆项目
git clone https://github.com/xiaoyuehan-w/studypulse.git
cd studypulse

# 安装依赖
flutter pub get

# 连接手机后运行（调试模式）
flutter run

# 编译 release APK
flutter build apk --release
```

### 3. 配置 App
1. 打开 App → 进入「设置」页
2. 填写：
   - **GitHub Token**：在 [github.com/settings/tokens](https://github.com/settings/tokens) 生成（勾选 `repo` 权限）
   - **Owner**：你的 GitHub 用户名
   - **Repo**：你的 Obsidian 笔记仓库名
3. 点「验证 Token」确认能访问
4. 回首页下拉刷新，即可看到周计划

### 4. 笔记格式要求
App 期望你的周计划 markdown 包含以下结构：
```markdown
---
（YAML frontmatter，可选）
---

## 每日安排

| 周一 9.23 | 周二 9.24 | ... |
|-----------|-----------|-----|
| 高数第3讲  | 线代第1讲  | ... |
```

App 会自动解析表格，提取每天的任务并生成推送内容。

## 技术栈

| 技术 | 用途 |
|------|------|
| **Flutter (Dart)** | 跨平台 UI 框架，一套代码出 Android + Windows |
| **GitHub REST API** | 读取仓库中的 markdown 文件 |
| **flutter_local_notifications** | 本地定时通知推送 |
| **shared_preferences** | 本地设置存储（Token、推送时间等） |
| **path_provider** | 本地文件缓存（离线周计划） |
| **http** | 网络请求 |
| **flutter_timezone** | 时区处理（确保推送时间准确） |

## 项目结构

```
lib/
├── main.dart                  # 应用入口 + 底部导航 + 主题
├── models/
│   └── weekly_plan.dart       # 周计划数据模型 + markdown 解析器
├── services/
│   ├── github_service.dart    # GitHub API 服务（列目录、读文件、验证Token）
│   ├── storage_service.dart   # 本地存储 + 周计划缓存
│   └── notification_service.dart # 定时通知服务
└── screens/
    ├── home_screen.dart       # 首页：今日任务
    ├── weekly_plan_screen.dart # 本周计划页
    └── settings_screen.dart   # 设置页：Token/仓库/推送时间
```

## 贡献指南

欢迎贡献！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

简单流程：
1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交修改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 路线图

- [x] V1.0：每日推送 + 周计划查看 + GitHub 同步
- [ ] V1.1：深色模式优化 + 错题本查看
- [ ] V1.2：学习状态可视化（进度条、统计）
- [ ] V2.0：Windows 桌面端
- [ ] V2.1：AI 学习助手（基于本地大模型）
- [ ] V3.0：多用户支持、社区计划分享

## 许可证

本项目基于 [MIT License](LICENSE) 开源，可自由使用、修改、分发。

## 致谢

- 感谢 [Flutter](https://flutter.dev/) 团队
- 感谢所有开源贡献者
- 这个项目源于一个大一学生对"更好的学习工具"的探索
