// GitHub 读取（**只读**：Contents API，不做任何写操作）
// 契约（冻结，见 docs/数据契约.md）：
//   周计划目录：10 项目/考研科软/周计划
//   学习状态：  10 项目/考研科软/学习状态-共同.md
// 设计要点：
//   · 优先返回「日期范围覆盖今天」的那一周（可安全提前生成多周）
//   · 失败必须可解释：仓库 200 但目录 404 → 明确指向 Token 权限
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weekly_plan.dart';

class GitHubException implements Exception {
  final String message;
  GitHubException(this.message);
  @override
  String toString() => message;
}

class RepoFile {
  final String name;
  final String path;
  RepoFile({required this.name, required this.path});
}

class GitHubSource {
  String owner;
  String repo;
  String token;

  GitHubSource({this.owner = '', this.repo = '', this.token = ''});

  void configure({required String owner, required String repo, required String token}) {
    this.owner = owner.trim();
    this.repo = repo.trim();
    this.token = token.trim();
  }

  bool get isConfigured => token.isNotEmpty && owner.isNotEmpty && repo.isNotEmpty;

  static const String _base = 'https://api.github.com';
  static const String planDir = '10 项目/考研科软/周计划';
  static const String statusFile = '10 项目/考研科软/学习状态-共同.md';

  Map<String, String> get _headers => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3.raw',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  // ---------- 基础读取 ----------
  Future<List<RepoFile>> listDirectory(String path) async {
    final resp = await http.get(
      Uri.parse('$_base/repos/$owner/$repo/contents/$path'),
      headers: _headers,
    );
    if (resp.statusCode == 404) return []; // Contents API 对「无权限」与「不存在」都回 404
    if (resp.statusCode != 200) {
      throw GitHubException('目录读取失败（HTTP ${resp.statusCode}）');
    }
    final data = json.decode(resp.body);
    if (data is! List) return [];
    return data
        .where((f) => f['type'] == 'file')
        .map((f) => RepoFile(name: '${f['name']}', path: '${f['path']}'))
        .toList();
  }

  Future<String> getFileContent(String path) async {
    final resp = await http.get(
      Uri.parse('$_base/repos/$owner/$repo/contents/$path'),
      headers: _headers,
    );
    if (resp.statusCode == 404) throw GitHubException('文件不存在：$path');
    if (resp.statusCode != 200) {
      throw GitHubException('文件读取失败（HTTP ${resp.statusCode}）');
    }
    return resp.body;
  }

  /// 仓库是否可访问（能读元数据 ≠ 能读文件，见 #47 的教训）
  Future<bool> validate() async {
    try {
      final resp = await http.get(
        Uri.parse('$_base/repos/$owner/$repo'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------- 业务读取 ----------
  /// 周计划文件名形如：周计划-第1周-2026.9.23.md（按文件名日期降序）
  Future<List<RepoFile>> listWeeklyPlans() async {
    final files = await listDirectory(planDir);
    files.sort((a, b) => _dateOf(b.name).compareTo(_dateOf(a.name)));
    return files;
  }

  /// 取「覆盖今天」的那一周；取不到回退最新（提前生成多周也不会串周）
  Future<WeeklyPlan?> fetchCurrentPlan() async {
    final files = await listWeeklyPlans();
    if (files.isEmpty) {
      if (!await validate()) {
        throw GitHubException(
          '无法读取仓库 $owner/$repo：Token 缺少私有库权限（classic 需勾 repo；'
          'fine-grained 需设 Contents: Read-only），或 owner/repo 填写不精确',
        );
      }
      return null; // 仓库正常，只是还没有周计划文件
    }

    final now = DateTime.now();
    WeeklyPlan? newest;
    for (final f in files) {
      final content = await getFileContent(f.path);
      final plan = WeeklyPlan.parse(content, fileName: f.name);
      if (plan == null) continue;
      newest ??= plan;
      if (plan.coversDate(now)) return plan;
    }
    return newest;
  }

  /// 学习状态文件（预留：后续用于展示进度对照）
  Future<String> fetchLearningStatus() => getFileContent(statusFile);

  /// 同步自查：逐步给出真实 HTTP 状态码与判读（配置排查用）
  Future<List<String>> diagnostics() async {
    final out = <String>['仓库：$owner/$repo'];
    if (!isConfigured) {
      out.add('Token / 用户名 / 仓库名：有未填写项');
      return out;
    }
    out.add('Token：已填写（长度 ${token.length}，不显示内容）');

    Future<void> probe(String label, String path) async {
      try {
        final resp = await http.get(
          Uri.parse('$_base/repos/$owner/$repo/contents/$path'),
          headers: _headers,
        );
        var extra = '';
        if (resp.statusCode == 200) {
          try {
            final d = json.decode(resp.body);
            if (d is List) {
              extra = '（条目 ${d.length}，文件 ${d.where((f) => f['type'] == 'file').length}）';
            }
          } catch (_) {}
        }
        out.add('$label：HTTP ${resp.statusCode}$extra');
      } catch (e) {
        out.add('$label：请求异常（$e）');
      }
    }

    final ok = await validate();
    out.add('① 仓库元数据：${ok ? "HTTP 200" : "不可访问"}');
    await probe('② 周计划目录', planDir);
    await probe('③ 学习状态文件', statusFile);
    out.add('——');
    out.add('判读：①可访问但 ②③ 非 200 → Token 缺「读文件」权限；'
        '三者皆 200 → 数据链路正常，问题在网络或缓存');
    return out;
  }

  static DateTime _dateOf(String name) {
    final m = RegExp(r'(\d{4})\.(\d{1,2})\.(\d{1,2})').firstMatch(name);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    return DateTime(2000);
  }
}
