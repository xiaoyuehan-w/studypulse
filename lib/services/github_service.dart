import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weekly_plan.dart';

/// GitHub API 服务
/// 通过 GitHub Contents API 读取 OB 仓库中的 markdown 文件
/// 文档：https://docs.github.com/en/rest/repos/contents
class GitHubService {
  String owner;
  String repo;
  String token;

  static const String _baseUrl = 'https://api.github.com';

  GitHubService({
    this.owner = '',
    this.repo = '',
    this.token = '',
  });

  /// 是否配置好了 Token
  bool get isConfigured => token.isNotEmpty && owner.isNotEmpty && repo.isNotEmpty;

  Map<String, String> get _headers => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3.raw',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  /// 列出指定目录下的文件
  Future<List<RepoFile>> listDirectory(String path) async {
    final url = Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$path');
    final resp = await http.get(url, headers: _headers);

    if (resp.statusCode == 404) return [];
    if (resp.statusCode != 200) {
      throw GitHubException('列出目录失败 (${resp.statusCode}): ${resp.body}');
    }

    final List<dynamic> data = json.decode(resp.body);
    return data
        .where((f) => f['type'] == 'file')
        .map((f) => RepoFile(
              name: f['name'] as String,
              path: f['path'] as String,
              size: f['size'] as int? ?? 0,
              downloadUrl: f['download_url'] as String?,
            ))
        .toList();
  }

  /// 读取文件的原始文本内容
  Future<String> getFileContent(String path) async {
    final url = Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$path');
    final resp = await http.get(url, headers: _headers);

    if (resp.statusCode == 404) {
      throw GitHubException('文件不存在: $path');
    }
    if (resp.statusCode != 200) {
      throw GitHubException('读取文件失败 (${resp.statusCode}): ${resp.body}');
    }

    // Accept: vnd.github.v3.raw 时直接返回文件内容
    return resp.body;
  }

  // ⚠️ 数据契约（冻结）：以下路径/文件名规则是 App 的读取契约，
  // 改动必须配套 App 发版 + 用户重装，详见 docs/数据契约.md（hub Issue #45）
  /// 获取周计划目录下所有文件，按文件名中的日期降序排列
  Future<List<RepoFile>> listWeeklyPlans() async {
    final files = await listDirectory('10 项目/考研科软/周计划');
    // 文件名格式：周计划-第1周-2026.9.23.md
    // 按日期排序（从文件名提取日期）
    files.sort((a, b) {
      final da = _extractDateFromFileName(a.name);
      final db = _extractDateFromFileName(b.name);
      return db.compareTo(da); // 降序，最新的在前
    });
    return files;
  }

  /// 获取最新的周计划（已解析）
  Future<WeeklyPlan?> getLatestWeeklyPlan() async {
    final files = await listWeeklyPlans();
    if (files.isEmpty) {
      // 目录为空有两种可能：仓库里确实没有周计划，或 Token 无权访问该私有仓库。
      // Contents API 对「无权限」与「路径不存在」都返回 404（listDirectory 需按空处理），
      // 这里用仓库接口再判一次，否则用户只看到「暂无数据」，误以为是自己没配置好。
      if (!await validateToken()) {
        throw GitHubException(
          '无法访问仓库 $owner/$repo（404）：Token 缺少私有库权限或 owner/repo 填写不精确',
        );
      }
      return null;
    }

    final latest = files.first;
    final content = await getFileContent(latest.path);
    return WeeklyPlan.parse(content, fileName: latest.name);
  }

  /// 获取学习状态文件内容
  Future<String> getLearningStatus() async {
    return getFileContent('10 项目/考研科软/学习状态-共同.md');
  }

  /// 验证 Token 是否有效（能访问仓库）
  Future<bool> validateToken() async {
    try {
      final url = Uri.parse('$_baseUrl/repos/$owner/$repo');
      final resp = await http.get(url, headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      });
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 从文件名提取日期用于排序
  /// 文件名格式：周计划-第1周-2026.9.23.md
  static DateTime _extractDateFromFileName(String name) {
    final m = RegExp(r'(\d{4})\.(\d{1,2})\.(\d{1,2})').firstMatch(name);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    return DateTime(2000); // 无法解析的排最后
  }
}

/// 仓库文件信息
class RepoFile {
  final String name;
  final String path;
  final int size;
  final String? downloadUrl;

  RepoFile({
    required this.name,
    required this.path,
    required this.size,
    this.downloadUrl,
  });
}

/// GitHub API 异常
class GitHubException implements Exception {
  final String message;
  GitHubException(this.message);

  @override
  String toString() => 'GitHubException: $message';
}
