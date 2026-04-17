import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
  Future<List<Skill>> getInstalledSkillsForAgent(String agentId) async {
    return _discoverSkillsForAgent(agentId);
  }

  /// 通过文件选择器上传并安装 Skill（仅支持 .zip）。
  ///
  /// 安装目标为该 Agent 的首选发现根目录（[_primaryDiscoveryRoot]），
  /// 安装完成后刷新即可从文件系统自动发现。
  Future<Skill?> installFromUpload({
    required String agentId,
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

    return _installFromZip(File(inputPath), agentId: agentId);
  }

  /// 从商店 URL 下载 zip 并安装 Skill 到 Agent 的首选发现根目录。
  Future<Skill> installFromStore({
    required String zipUrl,
    required Skill metadata,
    required String agentId,
  }) async {
    final http.Response response = await http.get(Uri.parse(zipUrl));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final Directory tempDir = await getTemporaryDirectory();
    final File zipFile = File('${tempDir.path}/${metadata.id}.zip');
    await zipFile.writeAsBytes(response.bodyBytes);

    return _installFromZip(
      zipFile,
      agentId: agentId,
      preferredName: metadata.id,
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

  /// 将默认 Agent（[defaultAgentId]）的所有 Skill 文件夹**物理复制**到目标 Agent（[targetAgentId]）的首选目录。
  ///
  /// 同步规则：
  /// 1. 扫描默认 Agent 的发现根目录，找到所有含 SKILL.md 的一级子目录。
  /// 2. 将每个 Skill 文件夹递归复制到目标 Agent 的首选发现根目录。
  /// 3. 同名则先删除旧文件夹再覆盖。
  /// 4. 无索引写入，刷新后从文件系统自动发现。
  ///
  /// 返回实际成功复制（新增 + 覆盖）的 Skill 数量。
  Future<int> syncSkillsFromDefaultAgent({
    required String defaultAgentId,
    required String targetAgentId,
  }) async {
    // 不允许将默认 Agent 的 skill 同步给自身
    if (defaultAgentId == targetAgentId) {
      return 0;
    }

    final List<String> homes = _homeCandidates();
    if (homes.isEmpty) {
      return 0;
    }

    // 收集默认 Agent 所有发现根目录下含 SKILL.md 的一级子目录
    final List<Directory> skillDirs = <Directory>[];
    final Set<String> permissionDeniedPaths = <String>{};

    for (final String home in homes) {
      final List<String> roots =
          _discoveryRoots(home)[defaultAgentId] ?? const <String>[];
      for (final String root in roots) {
        final Directory rootDir = Directory(root);
        if (!await rootDir.exists()) {
          continue;
        }
        final List<Directory> subs = await _listDirsSafe(
          rootDir,
          permissionDeniedPaths: permissionDeniedPaths,
        );
        for (final Directory sub in subs) {
          final String basename = _baseName(sub.path);
          // 忽略隐藏目录
          if (basename.isEmpty || basename.startsWith('.')) {
            continue;
          }
          // 只有包含 SKILL.md 的子目录才视为有效 Skill
          if (!await _hasSkillMd(
            sub,
            permissionDeniedPaths: permissionDeniedPaths,
          )) {
            continue;
          }
          skillDirs.add(Directory(sub.absolute.path));
        }
      }
    }

    if (skillDirs.isEmpty) {
      return 0;
    }

    // 确定目标 Agent 的首选存放目录（取第一个 home 的第一个 root）
    final String targetRoot =
        _primaryDiscoveryRoot(targetAgentId, homes.first);
    final Directory targetRootDir = Directory(targetRoot);
    if (!await targetRootDir.exists()) {
      await targetRootDir.create(recursive: true);
    }

    int syncedCount = 0;
    for (final Directory srcDir in skillDirs) {
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

  /// 从 zip 文件解压并安装 Skill 到 Agent 的首选发现根目录。
  ///
  /// zip 解压规则：
  /// - 若 zip 内存在唯一顶层目录（如 `my-skill/SKILL.md`），以该目录名作为 Skill 文件夹名，
  ///   并在解压时自动剥离顶层目录前缀。
  /// - 若 zip 内为平铺结构（`SKILL.md` 直接在根），则使用 [preferredName] 或 zip 文件名。
  Future<Skill> _installFromZip(
    File zipFile, {
    required String agentId,
    String? preferredName,
  }) async {
    final List<int> bytes = await zipFile.readAsBytes();
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    // 确定安装根目录
    final List<String> homes = _homeCandidates();
    if (homes.isEmpty) {
      throw Exception('无法获取 HOME 目录');
    }
    final String targetRoot = _primaryDiscoveryRoot(agentId, homes.first);
    final Directory targetRootDir = Directory(targetRoot);
    if (!await targetRootDir.exists()) {
      await targetRootDir.create(recursive: true);
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
          ? cleanPath
              .substring(folderName.length)
              .replaceAll(RegExp(r'^/'), '')
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

    return Skill(
      id: _genId('${agentId}_$folderName'),
      agentId: agentId,
      name: folderName,
      version: 'local',
      description: '已安装',
      author: 'unknown',
      source: 'upload',
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
  String _primaryDiscoveryRoot(String agentId, String home) {
    final List<String>? roots = _discoveryRoots(home)[agentId];
    if (roots == null || roots.isEmpty) {
      // 兜底：使用 ~/.skill_lake/<agentId>/skills
      return '$home/.skill_lake/$agentId/skills';
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
  Future<List<Skill>> _discoverSkillsForAgent(String agentId) async {
    final List<String> homeCandidates = _homeCandidates();
    if (homeCandidates.isEmpty) {
      return <Skill>[];
    }

    // 收集该 agent 所有需要扫描的根目录（去重）
    final Set<String> roots = <String>{};
    for (final String home in homeCandidates) {
      roots.addAll(_discoveryRoots(home)[agentId] ?? const <String>[]);
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
        try {
          // Read up to 8KB to avoid loading huge files into memory for frontmatter
          // But readAsString is simpler, SKILL.md is usually tiny.
          final String content = await skillMd.readAsString();
          final RegExp descExp = RegExp(r'^description:\s*(.+)$', multiLine: true);
          final RegExpMatch? match = descExp.firstMatch(content);
          if (match != null) {
            description = match.group(1)?.trim() ?? '';
          }
        } catch (_) {}

        // 使用真实绝对路径，确保展示路径与磁盘路径完全一致
        final String realPath = child.absolute.path;

        discovered.add(
          Skill(
            id: _genId('${agentId}_$realPath'),
            agentId: agentId,
            name: basename,
            version: 'local',
            description: description,
            author: 'local',
            source: 'auto:$root',
            installedPath: realPath,
          ),
        );
      }
    }

    if (discovered.isEmpty && permissionDeniedPaths.isNotEmpty) {
      throw SkillPermissionException(
        agentId: agentId,
        deniedPaths: permissionDeniedPaths.toList()..sort(),
      );
    }

    // 按名称排序，方便展示
    discovered.sort((Skill a, Skill b) => a.name.compareTo(b.name));
    return discovered;
  }

  /// 检测 [dir] 目录下是否存在名为 `SKILL.md` 的文件（文件名大小写不敏感）。
  Future<bool> _hasSkillMd(
    Directory dir, {
    required Set<String> permissionDeniedPaths,
  }) async {
    final List<File> files = await _listFilesSafe(
      dir,
      permissionDeniedPaths: permissionDeniedPaths,
    );
    return files.any(
      (File f) => _baseName(f.path).toLowerCase() == 'skill.md',
    );
  }

  /// 返回可能的 HOME 目录候选列表（通过环境变量推断）。
  List<String> _homeCandidates() {
    final Set<String> homes = <String>{};
    final String? envHome = Platform.environment['HOME'];
    if (envHome != null && envHome.trim().isNotEmpty) {
      homes.add(envHome.trim());
    }

    final String? user = Platform.environment['USER'];
    if (user != null && user.trim().isNotEmpty) {
      homes.add('/Users/${user.trim()}');
    }
    return homes.toList();
  }

  /// 返回各 Agent 的 skills 目录发现路径列表。
  /// 首选路径为各工具的官方约定目录，其余为兜底备用路径。
  /// - Cursor       : ~/.cursor/skills/
  /// - Claude Code  : ~/.claude/skills/
  /// - Codex CLI    : ~/.codex/skills/
  /// - Trae         : ~/.trae/skills/
  /// - Gemini CLI   : ~/.gemini/skills/
  /// - Antigravity  : ~/.gemini/antigravity/skills/
  /// - GitHub Copilot : ~/.copilot/skills/
  Map<String, List<String>> _discoveryRoots(String home) {
    return <String, List<String>>{
      // Cursor 官方 skills 目录
      'cursor': <String>[
        '$home/.cursor/skills',
        '$home/Library/Application Support/Cursor/skills',
      ],
      // Claude Code 官方 skills 目录
      'claude_code': <String>[
        '$home/.claude/skills',
        '$home/Library/Application Support/Claude/skills',
      ],
      // Codex CLI 官方 skills 目录
      'codex': <String>[
        '$home/.codex/skills',
        '$home/Library/Application Support/Codex/skills',
      ],
      // Trae 官方 skills 目录
      'trae': <String>[
        '$home/.trae/skills',
        '$home/Library/Application Support/Trae/skills',
      ],
      // Gemini CLI 官方 skills 目录
      'gemini_cli': <String>[
        '$home/.gemini/skills',
      ],
      // Antigravity 官方 skills 目录（位于 ~/.gemini/antigravity/skills/）
      'antigravity': <String>[
        '$home/.gemini/antigravity/skills',
        '$home/Library/Application Support/Antigravity/skills',
      ],
      // GitHub Copilot 官方 skills 目录
      'github_copilot': <String>[
        '$home/.copilot/skills',
      ],
    };
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
