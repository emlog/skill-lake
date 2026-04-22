import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '../models/agent_target.dart';
import '../models/skill.dart';

/// Skill 操作权限异常：当读取某个 Agent 目录时遭遇系统权限拒绝时抛出。
class SkillPermissionException implements Exception {
  const SkillPermissionException({
    required this.agentId,
    required this.deniedPaths,
  });

  final String agentId;
  final List<String> deniedPaths;

  @override
  String toString() {
    return 'SkillPermissionException(agentId: $agentId, deniedPaths: $deniedPaths)';
  }
}

/// Skill 管理服务。
///
/// 采用纯文件系统模式：
/// - 不维护任何本地索引（skills.json 已废弃）。
/// - 所有列表操作均为实时扫描发现根目录。
/// - 删除操作直接物理删除 Skill 文件夹。
/// - 安装操作将 Skill 文件夹写入 Agent 的首选发现根目录，刷新后即可发现。
class SkillService {
  /// 获取指定 Agent 的全部已安装 Skill（实时扫描文件系统，无缓存）。
  Future<List<Skill>> getInstalledSkillsForAgent(AgentTarget agent) async {
    return _discoverSkillsForAgent(agent);
  }

  /// 通过文件选择器上传并安装 Skill（仅支持 .zip）。
  ///
  /// 安装目标为该 Agent 的首选发现根目录（[_primaryDiscoveryRoot]），
  /// 安装完成后刷新即可从文件系统自动发现。
  Future<Skill?> installFromUpload({
    required AgentTarget agent,
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final PlatformFile picked = result.files.single;
    if (picked.path == null || picked.path!.isEmpty) {
      throw Exception('文件选择失败：未获得有效文件路径');
    }

    final String inputPath = picked.path!;
    final String ext = inputPath.split('.').last.toLowerCase();

    if (ext != 'zip') {
      throw Exception('仅支持 .zip 文件');
    }

    return _installFromZip(File(inputPath), agent: agent);
  }

  /// 从商店 URL 下载 zip 并安装 Skill 到 Agent 的首选发现根目录。
  Future<Skill> installFromStore({
    required String zipUrl,
    required Skill metadata,
    required AgentTarget agent,
    Map<String, String>? extraMetadata,
  }) async {
    final http.Response response = await http.get(Uri.parse(zipUrl));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final Directory tempDir = await getTemporaryDirectory();
    final File zipFile = File('${tempDir.path}/${metadata.id}.zip');
    await zipFile.writeAsBytes(response.bodyBytes);

    final Map<String, String> fm = {
      'name': metadata.name,
      'version': metadata.version,
      'description': metadata.description,
      'author': metadata.author,
      'source': metadata.source,
    };
    if (extraMetadata != null) {
      fm.addAll(extraMetadata);
    }

    return _installFromZip(
      zipFile,
      agent: agent,
      preferredName: metadata.id,
      metadata: fm,
    );
  }

  /// 检查 Skill 是否有更新。
  /// 返回远程版本号，如果没有更新则返回 null。
  Future<String?> checkForUpdate(Skill skill) async {
    final Map<String, String> fm = skill.metadata;
    final String? owner = fm['github_owner'];
    final String? repo = fm['github_repo'];
    final String? branch = fm['github_branch'];
    final String? skillsPath = fm['github_skills_path'];
    final String? skillDir = fm['github_skill_dir'];

    if (owner == null || repo == null || skillDir == null) {
      return null;
    }

    final String b = branch ?? 'main';
    final String sp = skillsPath ?? 'skills';
    final String url =
        'https://raw.githubusercontent.com/$owner/$repo/$b/$sp/$skillDir/SKILL.md';

    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return null;
      }
      final Map<String, String> remoteFm = _parseYamlFrontmatter(response.body);
      final String? remoteVersion = remoteFm['version'] ?? remoteFm['v'];
      if (remoteVersion != null && remoteVersion != skill.version) {
        return remoteVersion;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// 更新 Skill。
  Future<Skill> updateSkill(Skill skill, AgentTarget agent) async {
    final Map<String, String> fm = skill.metadata;
    final String? owner = fm['github_owner'];
    final String? repo = fm['github_repo'];
    final String? branch = fm['github_branch'];
    final String? skillsPath = fm['github_skills_path'];
    final String? skillDir = fm['github_skill_dir'];

    if (owner == null || repo == null || skillDir == null) {
      throw Exception('Skill 缺少更新所需的源信息');
    }

    final String b = branch ?? 'main';
    final String repoZipUrl =
        'https://api.github.com/repos/$owner/$repo/zipball/$b';

    // 重新下载并安装
    // 获取最新的 metadata (从远程 SKILL.md 解析)
    final String sp = skillsPath ?? 'skills';
    final String mdUrl =
        'https://raw.githubusercontent.com/$owner/$repo/$b/$sp/$skillDir/SKILL.md';
    final http.Response mdResponse = await http.get(Uri.parse(mdUrl));
    if (mdResponse.statusCode != 200) {
      throw Exception('无法获取远程元数据');
    }
    final Map<String, String> remoteFm = _parseYamlFrontmatter(mdResponse.body);

    final Skill metadata = Skill(
      id: skill.id,
      agentId: agent.id,
      name: remoteFm['name'] ?? skill.name,
      version: remoteFm['version'] ?? remoteFm['v'] ?? 'latest',
      description: remoteFm['description'] ?? skill.description,
      author: remoteFm['author'] ?? skill.author,
      source: remoteFm['source'] ?? skill.source,
    );

    return installFromGitHub(
      repoZipUrl: repoZipUrl,
      owner: owner,
      repo: repo,
      branch: b,
      skillsPath: sp,
      skillDirName: skillDir,
      metadata: metadata,
      agent: agent,
    );
  }

  /// 从 GitHub 下载并安装 Skill。
  /// 由于 GitHub 不支持单目录 zip 下载，需要下载整个仓库后按路径过滤解压。
  Future<Skill> installFromGitHub({
    required String repoZipUrl,
    required String owner,
    required String repo,
    required String branch,
    required String skillsPath,
    required String skillDirName,
    required Skill metadata,
    required AgentTarget agent,
  }) async {
    final http.Response response = await http.get(
      Uri.parse(repoZipUrl),
      headers: <String, String>{'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('下载失败：HTTP ${response.statusCode}');
    }

    final Archive archive = ZipDecoder().decodeBytes(response.bodyBytes);
    final String skillSubPath = '$skillsPath/$skillDirName/';

    // 过滤出属于目标 Skill 的文件
    final List<ArchiveFile> skillFiles = archive
        .where((ArchiveFile f) => f.name.contains(skillSubPath))
        .toList();

    if (skillFiles.isEmpty) {
      throw Exception('在仓库 zip 中未找到 $skillDirName 目录');
    }

    // 确定安装根目录
    final List<String> homes = _homeCandidates();
    if (homes.isEmpty) {
      throw Exception('无法获取 HOME 目录');
    }
    final String targetRoot = _primaryDiscoveryRoot(agent, homes.first);
    final Directory outputDir = Directory('$targetRoot/$skillDirName');

    // 同名先删除再安装
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
    await outputDir.create(recursive: true);

    // 解压目标 skill 的文件
    for (final ArchiveFile file in skillFiles) {
      final int skillPathStart = file.name.indexOf(skillSubPath);
      if (skillPathStart == -1) {
        continue;
      }
      final String relativePath =
          file.name.substring(skillPathStart + skillSubPath.length);
      if (relativePath.isEmpty) {
        continue;
      }

      final String outPath = '${outputDir.path}/$relativePath';
      if (file.isFile) {
        final File outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    // 更新 SKILL.md 元数据，记录 GitHub 信息以便后续更新
    final Map<String, String> fm = {
      'name': metadata.name,
      'version': metadata.version,
      'description': metadata.description,
      'author': metadata.author,
      'source': metadata.source,
      'github_owner': owner,
      'github_repo': repo,
      'github_branch': branch,
      'github_skills_path': skillsPath,
      'github_skill_dir': skillDirName,
    };

    final File skillMdFile = File('${outputDir.path}/SKILL.md');
    String content = '';
    if (await skillMdFile.exists()) {
      content = await skillMdFile.readAsString();
      // 移除原有的 frontmatter
      if (content.trim().startsWith('---')) {
        final int secondDash = content.indexOf('---', 3);
        if (secondDash != -1) {
          content = content.substring(secondDash + 3).trim();
        }
      }
    }

    final StringBuffer sb = StringBuffer('---\n');
    fm.forEach((key, value) {
      sb.writeln('$key: "$value"');
    });
    sb.writeln('---');
    if (content.isNotEmpty) {
      sb.writeln();
      sb.write(content.trim());
    }
    await skillMdFile.writeAsString(sb.toString());

    return Skill(
      id: _genId('${agent.id}_$skillDirName'),
      agentId: agent.id,
      name: metadata.name,
      version: metadata.version,
      description: metadata.description,
      author: metadata.author,
      source: metadata.source,
      installedPath: outputDir.absolute.path,
      metadata: fm,
    );
  }

  /// 删除 Skill：物理删除 [skill.installedPath] 对应的文件夹。
  ///
  /// 若路径为空或不存在则抛出异常，调用方应处理该异常。
  Future<void> deleteSkill(Skill skill) async {
    final String? path = skill.installedPath;
    if (path == null || path.isEmpty) {
      throw Exception('Skill「${skill.name}」没有有效的安装路径，无法删除');
    }
    final Directory dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 删除指定 Agent 的所有 Skill
  Future<void> deleteAllSkillsForAgent(AgentTarget agent) async {
    final List<Skill> skills = await getInstalledSkillsForAgent(agent);
    for (final Skill skill in skills) {
      try {
        await deleteSkill(skill);
      } catch (e) {
        // 忽略删除单个 Skill 时的异常，继续处理其他 Skill
      }
    }
  }

  /// 将 [sourceAgent] 的所有 Skill 文件夹**物理复制**到目标 Agent（[targetAgent]）的首选目录。
  ///
  /// 同步规则：
  /// 1. 获取源 Agent 的所有 Skill 文件夹。
  /// 2. 将每个 Skill 文件夹递归复制到目标 Agent 的首选发现根目录。
  /// 3. 同名则先删除旧文件夹再覆盖。
  /// 4. 无索引写入，刷新后从文件系统自动发现。
  ///
  /// 返回实际成功复制（新增 + 覆盖）的 Skill 数量。
  Future<int> syncAllSkills({
    required AgentTarget sourceAgent,
    required AgentTarget targetAgent,
  }) async {
    // 不允许同步给自身
    if (sourceAgent.id == targetAgent.id) {
      return 0;
    }

    final List<Skill> sourceSkills =
        await getInstalledSkillsForAgent(sourceAgent);
    if (sourceSkills.isEmpty) {
      return 0;
    }

    final List<String> homes = _homeCandidates();
    if (homes.isEmpty) {
      return 0;
    }

    // 确定目标 Agent 的首选存放目录（取第一个 home 的第一个 root）
    final String targetRoot = _primaryDiscoveryRoot(targetAgent, homes.first);
    final Directory targetRootDir = Directory(targetRoot);
    if (!await targetRootDir.exists()) {
      throw Exception('目标 Skill 目录不存在：$targetRoot\n请先确认该 Agent 是否已正确安装。');
    }

    int syncedCount = 0;
    for (final Skill skill in sourceSkills) {
      final String? path = skill.installedPath;
      if (path == null || path.isEmpty) continue;

      final Directory srcDir = Directory(path);
      if (!await srcDir.exists()) continue;

      final String skillName = _baseName(srcDir.path);
      final Directory destDir = Directory('${targetRootDir.path}/$skillName');

      // 若目标已存在同名文件夹，先删除再复制（覆盖语义）
      if (await destDir.exists()) {
        await destDir.delete(recursive: true);
      }

      // 递归复制 Skill 文件夹到目标 Agent 目录
      await _copySkillDir(srcDir, destDir);
      syncedCount++;
    }

    return syncedCount;
  }

  /// 将指定的 [skill] **物理复制**到目标 Agent（[targetAgent]）的首选目录。
  Future<void> syncSingleSkill({
    required Skill skill,
    required AgentTarget targetAgent,
  }) async {
    if (skill.agentId == targetAgent.id) return;

    final String? path = skill.installedPath;
    if (path == null || path.isEmpty) {
      throw Exception('Skill「${skill.name}」没有有效的安装路径，无法同步');
    }

    final Directory srcDir = Directory(path);
    if (!await srcDir.exists()) {
      throw Exception('Skill「${skill.name}」目录不存在，无法同步');
    }

    final List<String> homes = _homeCandidates();
    if (homes.isEmpty) {
      throw Exception('无法获取 HOME 目录');
    }

    final String targetRoot = _primaryDiscoveryRoot(targetAgent, homes.first);
    final Directory targetRootDir = Directory(targetRoot);
    if (!await targetRootDir.exists()) {
      throw Exception('目标 Skill 目录不存在：$targetRoot\n请先确认该 Agent 是否已正确安装。');
    }

    final String skillName = _baseName(srcDir.path);
    final Directory destDir = Directory('${targetRootDir.path}/$skillName');

    if (await destDir.exists()) {
      await destDir.delete(recursive: true);
    }
    await _copySkillDir(srcDir, destDir);
  }

  /// 从 zip 文件解压并安装 Skill 到 Agent 的首选发现根目录。
  ///
  /// zip 解压规则：
  /// - 若 zip 内存在唯一顶层目录（如 `my-skill/SKILL.md`），以该目录名作为 Skill 文件夹名，
  ///   并在解压时自动剥离顶层目录前缀。
  /// - 若 zip 内为平铺结构（`SKILL.md` 直接在根），则使用 [preferredName] 或 zip 文件名。
  Future<Skill> _installFromZip(
    File zipFile, {
    required AgentTarget agent,
    String? preferredName,
    Map<String, String>? metadata,
  }) async {
    final List<int> bytes = await zipFile.readAsBytes();
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    // 确定安装根目录
    final List<String> homes = _homeCandidates();
    if (homes.isEmpty) {
      throw Exception('无法获取 HOME 目录');
    }
    final String targetRoot = _primaryDiscoveryRoot(agent, homes.first);
    final Directory targetRootDir = Directory(targetRoot);
    if (!await targetRootDir.exists()) {
      throw Exception('目标 Skill 目录不存在：$targetRoot\n请先确认该 Agent 是否已正确安装。');
    }

    // 检测 zip 内是否存在唯一顶层目录
    final Set<String> topDirs = <String>{};
    for (final ArchiveFile f in archive) {
      final String clean = _sanitizeZipEntry(f.name);
      if (clean.isEmpty) continue;
      final String top = clean.split('/').first;
      if (top.isNotEmpty) topDirs.add(top);
    }

    final bool hasSingleTopDir = topDirs.length == 1;
    final String folderName = hasSingleTopDir
        ? topDirs.first
        : (preferredName ??
            zipFile.uri.pathSegments.last.replaceAll('.zip', ''));

    final Directory outputDir = Directory('${targetRootDir.path}/$folderName');
    // 同名先删除再安装（覆盖语义）
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
    await outputDir.create(recursive: true);

    // 解压 zip 内容
    for (final ArchiveFile file in archive) {
      final String cleanPath = _sanitizeZipEntry(file.name);
      if (cleanPath.isEmpty) continue;

      // 去掉顶层目录前缀（若有）
      final String relativePath = hasSingleTopDir
          ? cleanPath.substring(folderName.length).replaceAll(RegExp(r'^/'), '')
          : cleanPath;
      if (relativePath.isEmpty) continue;

      final String outPath = '${outputDir.path}/$relativePath';
      if (file.isFile) {
        final File outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(_toByteList(file.content));
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    // 写入/更新 SKILL.md 的元数据
    if (metadata != null) {
      final File skillMdFile = File('${outputDir.path}/SKILL.md');
      String content = '';
      if (await skillMdFile.exists()) {
        content = await skillMdFile.readAsString();
      }

      // 移除原有的 frontmatter
      if (content.trim().startsWith('---')) {
        final int secondDash = content.indexOf('---', 3);
        if (secondDash != -1) {
          content = content.substring(secondDash + 3).trim();
        }
      }

      final StringBuffer sb = StringBuffer('---\n');
      metadata.forEach((key, value) {
        sb.writeln('$key: "$value"');
      });
      sb.writeln('---');
      if (content.isNotEmpty) {
        sb.writeln();
        sb.write(content.trim());
      }
      await skillMdFile.writeAsString(sb.toString());
    }

    return Skill(
      id: _genId('${agent.id}_$folderName'),
      agentId: agent.id,
      name: metadata?['name'] ?? folderName,
      version: metadata?['version'] ?? 'local',
      description: metadata?['description'] ?? '已安装',
      author: metadata?['author'] ?? 'unknown',
      source: metadata?['source'] ?? 'upload',
      installedPath: outputDir.absolute.path,
    );
  }

  /// 递归将 [src] 目录的全部内容复制到 [dest] 目录。
  /// [dest] 不存在时自动创建。
  Future<void> _copySkillDir(Directory src, Directory dest) async {
    if (!await dest.exists()) {
      await dest.create(recursive: true);
    }
    await for (final FileSystemEntity entity
        in src.list(recursive: false, followLinks: true)) {
      final String name = _baseName(entity.path);
      if (entity is File) {
        // 复制文件
        await entity.copy('${dest.path}/$name');
      } else if (entity is Directory) {
        // 递归复制子目录
        await _copySkillDir(entity, Directory('${dest.path}/$name'));
      }
    }
  }

  /// 返回指定 Agent 在 [home] 下的**首选**存放目录（即 _discoveryRoots 的第一个路径）。
  /// 用于确定同步/安装时文件的写入位置。
  String _primaryDiscoveryRoot(AgentTarget agent, String home) {
    final List<String> roots = _getRootsForAgent(agent, home);
    if (roots.isEmpty) {
      // 兜底：根据平台构造默认技能目录
      final String sep = Platform.pathSeparator;
      return '$home$sep.skill_lake$sep${agent.id}${sep}skills';
    }
    return roots.first;
  }

  /// 自动发现指定 Agent 的已安装 Skill 列表（纯文件系统实时扫描）。
  ///
  /// 发现规则：
  /// 1. 遍历 [_discoveryRoots] 中该 Agent 的所有 roots 目录。
  /// 2. 对每个 root 下的**直接子目录**进行检测。
  /// 3. 子目录内含有 `SKILL.md`（文件名大小写不敏感）时，才视为有效 Skill。
  /// 4. installedPath 使用目录的真实绝对路径，确保与磁盘路径一致。
  Future<List<Skill>> _discoverSkillsForAgent(AgentTarget agent) async {
    final List<String> homeCandidates = _homeCandidates();
    if (homeCandidates.isEmpty) {
      return <Skill>[];
    }

    // 收集该 agent 所有需要扫描的根目录（去重）
    final Set<String> roots = <String>{};
    for (final String home in homeCandidates) {
      roots.addAll(_getRootsForAgent(agent, home));
    }

    final List<Skill> discovered = <Skill>[];
    final Set<String> permissionDeniedPaths = <String>{};

    for (final String root in roots) {
      final Directory dir = Directory(root);
      if (!await dir.exists()) {
        continue;
      }

      // 列出 root 下的直接子目录
      final List<Directory> subDirs = await _listDirsSafe(
        dir,
        permissionDeniedPaths: permissionDeniedPaths,
      );

      for (final Directory child in subDirs) {
        final String basename = _baseName(child.path);
        // 忽略隐藏目录
        if (basename.isEmpty || basename.startsWith('.')) {
          continue;
        }

        // 获取子目录文件列表
        final List<File> childFiles = await _listFilesSafe(
          child,
          permissionDeniedPaths: permissionDeniedPaths,
        );
        final Iterable<File> skillMds = childFiles.where(
          (File f) => _baseName(f.path).toLowerCase() == 'skill.md',
        );

        // 仅当目录内含 SKILL.md 时才视为有效 Skill
        if (skillMds.isEmpty) {
          continue;
        }
        final File skillMd = skillMds.first;

        String description = '';
        String version = 'local';
        String author = 'local';
        String name = basename;
        String? source;

        try {
          final String content = await skillMd.readAsString();
          final Map<String, String> frontmatter =
              _parseYamlFrontmatter(content);

          if (frontmatter.containsKey('description')) {
            description = frontmatter['description'] ?? '';
          }
          if (frontmatter.containsKey('version') ||
              frontmatter.containsKey('v')) {
            version = frontmatter['version'] ?? frontmatter['v'] ?? 'local';
          }
          if (frontmatter.containsKey('author')) {
            author = frontmatter['author'] ?? 'local';
          }
          if (frontmatter.containsKey('name')) {
            name = frontmatter['name'] ?? basename;
          }
          if (frontmatter.containsKey('source')) {
            source = frontmatter['source'];
          }

          // 使用真实绝对路径，确保展示路径与磁盘路径完全一致
          final String realPath = child.absolute.path;

          discovered.add(
            Skill(
              id: _genId('${agent.id}_$realPath'),
              agentId: agent.id,
              name: name,
              version: version,
              description: description,
              author: author,
              source: source ?? 'auto:$root',
              installedPath: realPath,
              metadata: frontmatter,
            ),
          );
        } catch (_) {}
      }
    }

    if (discovered.isEmpty && permissionDeniedPaths.isNotEmpty) {
      throw SkillPermissionException(
        agentId: agent.id,
        deniedPaths: permissionDeniedPaths.toList()..sort(),
      );
    }

    // 按照安装时间（目录最后修改时间）降序排序，最近安装的排在前面
    discovered.sort((Skill a, Skill b) {
      DateTime getTime(Skill s) {
        if (s.installedPath == null || s.installedPath!.isEmpty) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
        try {
          return FileStat.statSync(s.installedPath!).modified;
        } catch (_) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
      }

      return getTime(b).compareTo(getTime(a));
    });

    return discovered;
  }

  /// 解析 SKILL.md 内容中的 YAML frontmatter。
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

    final String yamlString = trimmed.substring(3, secondDash).trim();
    try {
      final dynamic doc = loadYaml(yamlString);
      if (doc is YamlMap) {
        doc.forEach((key, value) {
          if (key is String) {
            result[key] = value?.toString() ?? '';
          }
        });
      }
    } catch (_) {
      // 降级到简易解析
      for (final String line in yamlString.split('\n')) {
        final int colonIndex = line.indexOf(':');
        if (colonIndex == -1) continue;
        final String key = line.substring(0, colonIndex).trim();
        final String value = line.substring(colonIndex + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          result[key] =
              value.replaceAll(RegExp(r'^["' "'" r']|["' "'" r']$'), '').trim();
        }
      }
    }

    return result;
  }

  /// 返回可能的 HOME 目录候选列表（通过环境变量推断）。
  List<String> _homeCandidates() {
    final Set<String> homes = <String>{};

    if (Platform.isWindows) {
      final String? userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.trim().isNotEmpty) {
        homes.add(userProfile.trim());
      }
      final String? homeDrive = Platform.environment['HOMEDRIVE'];
      final String? homePath = Platform.environment['HOMEPATH'];
      if (homeDrive != null && homePath != null) {
        homes.add('${homeDrive.trim()}${homePath.trim()}');
      }
    } else {
      final String? envHome = Platform.environment['HOME'];
      if (envHome != null && envHome.trim().isNotEmpty) {
        homes.add(envHome.trim());
      }

      final String? user = Platform.environment['USER'];
      if (user != null && user.trim().isNotEmpty) {
        homes.add('/Users/${user.trim()}');
      }
    }

    return homes.toList();
  }

  /// 返回各 Agent 的 skills 目录发现路径列表。
  List<String> _getRootsForAgent(AgentTarget agent, String home) {
    if (agent.skillsDirectory != null && agent.skillsDirectory!.isNotEmpty) {
      // 支持用 ~ 代替 home
      final String dir = agent.skillsDirectory!.replaceAll('~', home);
      return <String>[dir];
    }

    final bool isWin = Platform.isWindows;
    final String? appData = Platform.environment['APPDATA'];
    final String? localAppData = Platform.environment['LOCALAPPDATA'];

    final Map<String, List<String>> builtin = <String, List<String>>{
      // Cursor 官方 skills 目录
      'cursor': isWin
          ? <String>[
              '$home\\.cursor\\skills',
              if (appData != null) '$appData\\Cursor\\skills',
              if (localAppData != null) '$localAppData\\Cursor\\skills',
            ]
          : <String>[
              '$home/.cursor/skills',
              '$home/Library/Application Support/Cursor/skills',
            ],
      // Claude Code 官方 skills 目录
      'claude_code': isWin
          ? <String>[
              '$home\\.claude\\skills',
              if (appData != null) '$appData\\Claude\\skills',
            ]
          : <String>[
              '$home/.claude/skills',
              '$home/Library/Application Support/Claude/skills',
            ],
      // Codex CLI 官方 skills 目录
      'codex': isWin
          ? <String>[
              '$home\\.codex\\skills',
              if (appData != null) '$appData\\Codex\\skills',
            ]
          : <String>[
              '$home/.codex/skills',
              '$home/Library/Application Support/Codex/skills',
            ],
      // Trae 官方 skills 目录
      'trae': isWin
          ? <String>[
              '$home\\.trae\\skills',
              if (appData != null) '$appData\\Trae\\skills',
            ]
          : <String>[
              '$home/.trae/skills',
              '$home/Library/Application Support/Trae/skills',
            ],
      // Gemini CLI 官方 skills 目录
      'gemini_cli': isWin
          ? <String>[
              '$home\\.gemini\\skills',
              if (appData != null) '$appData\\Gemini\\skills',
            ]
          : <String>[
              '$home/.gemini/skills',
            ],
      // Antigravity 官方 skills 目录
      'antigravity': isWin
          ? <String>[
              '$home\\.gemini\\antigravity\\skills',
              if (appData != null) '$appData\\Antigravity\\skills',
            ]
          : <String>[
              '$home/.gemini/antigravity/skills',
              '$home/Library/Application Support/Antigravity/skills',
            ],
      // GitHub Copilot 官方 skills 目录
      'github_copilot': isWin
          ? <String>[
              '$home\\.copilot\\skills',
              if (appData != null) '$appData\\Copilot\\skills',
            ]
          : <String>[
              '$home/.copilot/skills',
            ],
    };
    return builtin[agent.id] ?? const <String>[];
  }

  /// 安全列出 [dir] 下所有直接子目录（含符号链接指向的目录）。
  /// 权限错误时记录到 [permissionDeniedPaths] 并继续。
  Future<List<Directory>> _listDirsSafe(
    Directory dir, {
    required Set<String> permissionDeniedPaths,
  }) async {
    final List<Directory> results = <Directory>[];
    try {
      await for (final FileSystemEntity entity
          in dir.list(recursive: false, followLinks: true)) {
        if (entity is Directory) {
          results.add(entity);
        } else if (entity is Link) {
          final String targetPath = await entity.resolveSymbolicLinks();
          final Directory target = Directory(targetPath);
          if (await target.exists()) {
            results.add(target);
          }
        }
      }
    } catch (err) {
      if (_isPermissionDeniedError(err)) {
        permissionDeniedPaths.add(dir.path);
      }
      // 忽略目录列举错误，继续扫描其他路径
    }
    return results;
  }

  /// 安全列出 [dir] 下所有直接子文件。
  /// 权限错误时记录到 [permissionDeniedPaths] 并继续。
  Future<List<File>> _listFilesSafe(
    Directory dir, {
    required Set<String> permissionDeniedPaths,
  }) async {
    final List<File> results = <File>[];
    try {
      await for (final FileSystemEntity entity
          in dir.list(recursive: false, followLinks: true)) {
        if (entity is File) {
          results.add(entity);
        }
      }
    } catch (err) {
      if (_isPermissionDeniedError(err)) {
        permissionDeniedPaths.add(dir.path);
      }
      // 忽略目录列举错误，继续扫描其他路径
    }
    return results;
  }

  /// 判断异常是否为文件系统权限拒绝错误。
  bool _isPermissionDeniedError(Object error) {
    if (error is! FileSystemException) {
      return false;
    }
    final int? code = error.osError?.errorCode;
    if (code == 1 || code == 13) {
      return true;
    }
    final String msg = error.message.toLowerCase();
    final String osMsg = (error.osError?.message ?? '').toLowerCase();
    return msg.contains('permission denied') ||
        msg.contains('operation not permitted') ||
        osMsg.contains('permission denied') ||
        osMsg.contains('operation not permitted');
  }

  /// 取路径最后一段（文件/目录名）。
  String _baseName(String path) {
    final List<String> parts = path
        .replaceAll('\\', '/')
        .split('/')
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    return parts.last;
  }

  /// 清理 zip 条目路径，防止路径穿越攻击。
  String _sanitizeZipEntry(String name) {
    final String normalized = name.replaceAll('\\', '/').trim();
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('../')) {
      return '';
    }
    return normalized;
  }

  /// 将 archive 文件内容转为字节列表。
  List<int> _toByteList(dynamic content) {
    if (content == null) {
      return <int>[];
    }
    if (content is Uint8List) {
      return content;
    }
    if (content is List<int>) {
      return content;
    }
    if (content is InputStream) {
      return content.toUint8List();
    }
    throw Exception('Unsupported archive content type: ${content.runtimeType}');
  }

  /// 将原始字符串转换为合法的 ID（小写字母、数字、下划线）。
  String _genId(String raw) {
    final String lower = raw.toLowerCase();
    return lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll('_zip', '');
  }
}
