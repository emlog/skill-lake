import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/skill.dart';

/// 商店源抽象类
abstract class SkillSource {
  const SkillSource();

  /// 完整的显示名称
  String get displayName;
}

/// GitHub Skill 仓库源定义，包含仓库所有者、仓库名和 skill 子目录路径。
class GitHubSkillSource extends SkillSource {
  const GitHubSkillSource({
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.skillsPath = 'skills',
  });

  /// 仓库所有者（如 anthropics）
  final String owner;

  /// 仓库名（如 skills）
  final String repo;

  /// 分支名
  final String branch;

  /// 仓库内 skills 目录的路径
  final String skillsPath;

  /// 完整的显示名称（owner/repo）
  @override
  String get displayName => '$owner/$repo';

  /// GitHub API：获取 skills 目录下的子目录列表
  String get contentsApiUrl =>
      'https://api.github.com/repos/$owner/$repo/contents/$skillsPath?ref=$branch';

  /// 获取某个 skill 的 SKILL.md 原始内容 URL
  String skillMdRawUrl(String skillName) =>
      'https://raw.githubusercontent.com/$owner/$repo/$branch/$skillsPath/$skillName/SKILL.md';

  /// 获取某个 skill 目录的 zip 下载地址（GitHub archive API：下载整个仓库 zip）
  /// 注意：GitHub 不支持单目录下载 zip，因此使用仓库级别的 archive
  String get repoZipUrl =>
      'https://api.github.com/repos/$owner/$repo/zipball/$branch';
}

/// Skillsmp 搜索源
class SkillsmpSkillSource extends SkillSource {
  const SkillsmpSkillSource();

  @override
  String get displayName => 'skillsmp';
}

/// 商店中展示的 Skill 条目。
class StoreSkillItem {
  const StoreSkillItem({
    required this.skill,
    required this.source,
    required this.skillDirName,
  });

  /// Skill 基本元数据
  final Skill skill;

  /// 来源仓库信息
  final GitHubSkillSource source;

  /// Skill 在仓库中的文件夹名
  final String skillDirName;

  /// 获取该 skill 的 SKILL.md 原始文件 URL
  String get skillMdUrl => source.skillMdRawUrl(skillDirName);

  /// 获取该 skill 所在仓库的 zip 下载地址
  String get repoZipUrl => source.repoZipUrl;

  /// 将该条目序列化为 JSON Map
  Map<String, dynamic> toJson() => <String, dynamic>{
        'skill': skill.toMap(),
        'owner': source.owner,
        'repo': source.repo,
        'branch': source.branch,
        'skillsPath': source.skillsPath,
        'skillDirName': skillDirName,
      };

  /// 从 JSON Map 反序列化为 StoreSkillItem
  factory StoreSkillItem.fromJson(Map<String, dynamic> map) {
    return StoreSkillItem(
      skill: Skill.fromMap(map['skill'] as Map<String, dynamic>),
      source: GitHubSkillSource(
        owner: map['owner'] as String? ?? '',
        repo: map['repo'] as String? ?? '',
        branch: map['branch'] as String? ?? 'main',
        skillsPath: map['skillsPath'] as String? ?? 'skills',
      ),
      skillDirName: map['skillDirName'] as String? ?? '',
    );
  }
}

/// Skill 商店服务：从多个 GitHub 仓库源读取 Skill 列表。
///
/// 功能特性：
/// - 从 GitHub API 读取仓库 skills 目录，自动发现 skill 子目录
/// - 解析每个 skill 的 SKILL.md YAML frontmatter 提取 name 和 description
/// - 支持本地文件缓存，避免重复请求 GitHub API
/// - 支持强制刷新缓存
class StoreService {
  const StoreService();

  /// 内置的 Skill 仓库源列表
  static const List<SkillSource> builtInSources = <SkillSource>[
    GitHubSkillSource(owner: 'anthropics', repo: 'skills'),
    GitHubSkillSource(owner: 'obra', repo: 'superpowers'),
    SkillsmpSkillSource(),
  ];

  /// 获取缓存文件路径（按 owner/repo 区分）
  Future<File> _cacheFile(GitHubSkillSource source) async {
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory cacheDir = Directory('${appDir.path}/skill_store_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/${source.owner}_${source.repo}.json');
  }

  /// 从缓存中读取 Skill 列表（如果缓存存在且未过期）
  Future<List<StoreSkillItem>?> _readCache(GitHubSkillSource source) async {
    try {
      final File file = await _cacheFile(source);
      if (!await file.exists()) {
        return null;
      }
      final String content = await file.readAsString();
      final Map<String, dynamic> cached =
          json.decode(content) as Map<String, dynamic>;

      // 检查缓存是否过期（24 小时）
      final int? ts = cached['timestamp'] as int?;
      if (ts != null) {
        final DateTime cachedAt =
            DateTime.fromMillisecondsSinceEpoch(ts);
        if (DateTime.now().difference(cachedAt).inHours > 24) {
          return null; // 缓存已过期
        }
      }

      final List<dynamic> items = cached['items'] as List<dynamic>? ?? <dynamic>[];
      return items
          .map((dynamic e) =>
              StoreSkillItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 将 Skill 列表写入缓存
  Future<void> _writeCache(
    GitHubSkillSource source,
    List<StoreSkillItem> items,
  ) async {
    try {
      final File file = await _cacheFile(source);
      final Map<String, dynamic> data = <String, dynamic>{
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'items': items.map((StoreSkillItem e) => e.toJson()).toList(),
      };
      await file.writeAsString(json.encode(data));
    } catch (_) {
      // 缓存写入失败不影响主流程
    }
  }

  /// 从单个 GitHub 仓库源获取 Skill 列表。
  ///
  /// [forceRefresh] 为 true 时忽略本地缓存，强制从 GitHub 重新拉取。
  Future<List<StoreSkillItem>> fetchSkillsFromSource(
    GitHubSkillSource source, {
    bool forceRefresh = false,
  }) async {
    // 尝试读取缓存
    if (!forceRefresh) {
      final List<StoreSkillItem>? cached = await _readCache(source);
      if (cached != null) {
        return cached;
      }
    }

    final List<StoreSkillItem> items = <StoreSkillItem>[];

    try {
      // 1. 通过 GitHub Contents API 获取 skills 目录下的子目录列表
      final http.Response dirResponse =
          await http.get(Uri.parse(source.contentsApiUrl));
      if (dirResponse.statusCode != 200) {
        return items;
      }

      final List<dynamic> dirs =
          json.decode(dirResponse.body) as List<dynamic>;

      // 2. 对每个子目录，请求其 SKILL.md 文件并解析 YAML frontmatter
      for (final dynamic entry in dirs) {
        final Map<String, dynamic> dirInfo = entry as Map<String, dynamic>;
        final String name = dirInfo['name'] as String? ?? '';
        final String type = dirInfo['type'] as String? ?? '';

        // 仅处理目录类型
        if (type != 'dir' || name.isEmpty || name.startsWith('.')) {
          continue;
        }

        // 获取 SKILL.md 内容
        try {
          final String skillMdUrl = source.skillMdRawUrl(name);
          final http.Response mdResponse =
              await http.get(Uri.parse(skillMdUrl));
          if (mdResponse.statusCode != 200) {
            // 没有 SKILL.md，跳过
            continue;
          }

          // 解析 YAML frontmatter 提取 name 和 description
          final Map<String, String> frontmatter =
              _parseYamlFrontmatter(mdResponse.body);

          final String skillName =
              frontmatter['name'] ?? name;
          final String skillDescription =
              frontmatter['description'] ?? '无描述';

          items.add(
            StoreSkillItem(
              skill: Skill(
                id: '${source.owner}_${source.repo}_$name',
                agentId: '',
                name: skillName,
                version: 'latest',
                description: skillDescription,
                author: source.owner,
                source: source.displayName,
              ),
              source: source,
              skillDirName: name,
            ),
          );
        } catch (_) {
          // 单个 skill 解析失败不影响其他
          continue;
        }
      }

      // 按名称排序
      items.sort((StoreSkillItem a, StoreSkillItem b) =>
          a.skill.name.compareTo(b.skill.name));

      // 写入缓存
      await _writeCache(source, items);
    } catch (_) {
      // 网络或解析错误，返回空列表
    }

    return items;
  }

  /// 解析 SKILL.md 内容中的 YAML frontmatter。
  ///
  /// 格式示例：
  /// ```
  /// ---
  /// name: pdf
  /// description: Use this skill for PDF tasks.
  /// ---
  /// ```
  ///
  /// 返回解析后的键值对 Map。
  Map<String, String> _parseYamlFrontmatter(String content) {
    final Map<String, String> result = <String, String>{};
    final String trimmed = content.trim();

    // 检查是否以 --- 开头
    if (!trimmed.startsWith('---')) {
      return result;
    }

    // 找到第二个 ---
    final int secondDash = trimmed.indexOf('---', 3);
    if (secondDash == -1) {
      return result;
    }

    final String frontmatter = trimmed.substring(3, secondDash).trim();
    // 简易 YAML 解析：按行处理 key: value 对
    for (final String line in frontmatter.split('\n')) {
      final int colonIndex = line.indexOf(':');
      if (colonIndex == -1) {
        continue;
      }
      final String key = line.substring(0, colonIndex).trim();
      final String value = line.substring(colonIndex + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        result[key] = value;
      }
    }

    return result;
  }

  /// 搜索 skillsmp API
  Future<List<StoreSkillItem>> searchSkillsmp(String query, String apiKey) async {
    if (query.trim().isEmpty) {
      return <StoreSkillItem>[];
    }
    try {
      final Uri url = Uri.parse(
          'https://skillsmp.com/api/v1/skills/ai-search?q=${Uri.encodeComponent(query)}');
      final Map<String, String> headers = <String, String>{};
      if (apiKey.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final http.Response response = await http.get(url, headers: headers);
      if (response.statusCode != 200) {
        return <StoreSkillItem>[];
      }

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        return <StoreSkillItem>[];
      }

      final Map<String, dynamic> pageData = data['data'] as Map<String, dynamic>;
      final List<dynamic> items = pageData['data'] as List<dynamic>? ?? <dynamic>[];
      final List<StoreSkillItem> results = <StoreSkillItem>[];

      for (final dynamic e in items) {
        final Map<String, dynamic> itemMap = e as Map<String, dynamic>;
        final Map<String, dynamic>? skillMap = itemMap['skill'] as Map<String, dynamic>?;
        if (skillMap == null) {
          continue;
        }

        final String githubUrl = skillMap['githubUrl'] as String? ?? '';
        final GitHubSkillSource? parsedSource = _parseGitHubUrl(githubUrl);
        if (parsedSource != null) {
          final List<String> segments = Uri.parse(githubUrl).pathSegments;
          final String skillDirName = segments.last;

          results.add(
            StoreSkillItem(
              skill: Skill(
                id: skillMap['id'] as String? ?? '',
                agentId: '',
                name: skillMap['name'] as String? ?? skillDirName,
                version: 'latest',
                description: skillMap['description'] as String? ?? '无描述',
                author: skillMap['author'] as String? ?? parsedSource.owner,
                source: 'skillsmp',
              ),
              source: parsedSource,
              skillDirName: skillDirName,
            ),
          );
        }
      }
      return results;
    } catch (_) {
      return <StoreSkillItem>[];
    }
  }

  /// 从 GitHub URL 中解析目标仓库源信息
  /// URL 格式例如：https://github.com/booklib-ai/booklib/tree/main/skills/web-scraping-python
  GitHubSkillSource? _parseGitHubUrl(String url) {
    if (url.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'github.com') {
      return null;
    }
    final List<String> segments = uri.pathSegments;
    if (segments.length >= 5 && segments[2] == 'tree') {
      final String owner = segments[0];
      final String repo = segments[1];
      final String branch = segments[3];
      // 第 4 部分到倒数第 2 部分组成 skillsPath
      final List<String> pathSegments = segments.sublist(4, segments.length - 1);
      final String skillsPath = pathSegments.join('/');

      return GitHubSkillSource(
        owner: owner,
        repo: repo,
        branch: branch,
        skillsPath: skillsPath,
      );
    }
    return null;
  }
}
