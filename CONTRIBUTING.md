# 贡献指南

感谢你对 StudyPulse 的兴趣！我们欢迎所有形式的贡献——无论是代码、文档、bug 报告还是功能建议。

## 如何贡献

### 1. 报告 Bug
如果你发现了 bug，请在 GitHub Issues 中报告，并包含：
- 复现步骤
- 预期行为 vs 实际行为
- 手机型号、Android 版本
- 截图（如果适用）

### 2. 提交功能建议
在 Issues 中开启一个 `[Feature]` 标签的讨论，描述：
- 你想要什么功能
- 为什么需要它
- 可能的实现思路

### 3. 提交代码

#### 开发环境搭建
```bash
# Fork 并克隆
git clone https://github.com/<你的用户名>/studypulse.git
cd studypulse

# 安装依赖
flutter pub get

# 运行
flutter run
```

#### 提交规范
1. 创建功能分支：`git checkout -b feature/你的功能名`
2. 编写代码，确保：
   - 遵循现有代码风格
   - 添加必要的注释
   - 不引入硬编码的敏感信息（Token、密钥等）
3. 提交：`git commit -m "feat: 添加XX功能"`（使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范）
4. 推送：`git push origin feature/你的功能名`
5. 在 GitHub 上开启 Pull Request

#### Commit 信息格式
```
<type>(<scope>): <subject>

类型 type:
  feat:     新功能
  fix:      修复bug
  docs:     文档修改
  style:    代码格式（不影响功能）
  refactor: 重构
  test:     测试相关
  chore:    构建/工具相关

示例:
  feat(notification): 添加自定义推送铃声
  fix(home): 修复周计划日期解析错误
  docs: 更新README编译步骤
```

### 4. 代码审查
所有 PR 都需要经过审查。我们会关注：
- 功能是否正常工作
- 是否引入了新的依赖（尽量减少）
- 是否有安全隐患
- 代码风格是否一致

## 项目规范

### 安全
- **永远不要**在代码中硬编码 GitHub Token、API 密钥等敏感信息
- 所有敏感配置通过用户在设置页输入，存储在本地
- 提交前检查 `git diff`，确保没有意外提交敏感信息

### 国际化
- 目前 App 以中文为主
- 用户可见的字符串尽量集中管理，方便未来国际化

### 性能
- 网络请求要有超时和错误处理
- 大文件操作使用异步
- 注意内存泄漏（及时取消订阅、释放控制器）

## 学习资源

如果你是 Flutter 新手，这些资源可能有帮助：
- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言指南](https://dart.dev/guides)
- [Flutter 实战](https://book.flutterchina.club/)

## 行为准则

我们致力于提供一个友好、包容的社区环境。请：
- 尊重不同的观点和经验水平
- 接受建设性的批评
- 对其他贡献者保持友善

## 有问题？

如果在贡献过程中遇到问题，欢迎在 Issues 中提问，或者直接在 PR 中 @维护者。

再次感谢你的贡献！🎉
