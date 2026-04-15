import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/skill.dart';

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

class SkillService {
  static const String _indexFileName = 'skills.json';

  Future<List<Skill>> getInstalledSkillsForAgent(String agentId) async {
    final List<Skill> indexed = await _getIndexedSkillsForAgent(agentId);
    final List<Skill> discovered = await _discoverSkillsForAgent(agentId);
    final Map<String, Skill> merged = <String, Skill>{};

    for (final Skill skill in indexed) {
      merged[_fingerprint(skill)] = skill;
    }
    for (final Skill skill in discovered) {
      merged.putIfAbsent(_fingerprint(skill), () => skill);
    }
    final List<Skill> result = merged.values.toList()
      ..sort((Skill a, Skill b) => a.name.compareTo(b.name));
    return result;
  }

  Future<List<Skill>> _getIndexedSkillsForAgent(String agentId) async {
    final File file = await _getIndexFile();
    if (!await file.exists()) {
      return <Skill>[];
    }

    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <Skill>[];
    }

    final List<dynamic> data = json.decode(raw) as List<dynamic>;
    return data
        .map((dynamic e) => Skill.fromMap(e as Map<String, dynamic>))
        .where((Skill skill) => skill.agentId == agentId)
        .toList();
  }

  Future<List<Skill>> getIndexedSkills() async {
    final File file = await _getIndexFile();
    if (!await file.exists()) {
      return <Skill>[];
    }
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <Skill>[];
    }
    final List<dynamic> data = json.decode(raw) as List<dynamic>;
    return data
        .map((dynamic e) => Skill.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSkills(List<Skill> skills) async {
    final File file = await _getIndexFile();
    final String content =
        json.encode(skills.map((Skill e) => e.toMap()).toList());
    await file.writeAsString(content);
  }

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
    final File source = File(inputPath);
    final String ext = inputPath.split('.').last.toLowerCase();

    if (ext != 'zip' && ext != 'json') {
      throw Exception('仅支持 .zip 或 .json 文件');
    }

    if (ext == 'zip') {
      return _installFromZip(
        source,
        sourcePathLabel: 'upload',
        agentId: agentId,
      );
    }

    if (ext == 'json') {
      final Skill parsed =
          Skill.fromJson(await source.readAsString()).copyWith(agentId: agentId);
      return _persistSkill(parsed, sourcePath: inputPath);
    }

    return _persistSkill(
      Skill(
        id: _genId(source.uri.pathSegments.last),
        agentId: agentId,
        name: source.uri.pathSegments.last,
        version: '0.0.1',
        description: 'Imported from local file',
        author: 'unknown',
        source: 'upload',
      ),
      sourcePath: inputPath,
    );
  }

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
      sourcePathLabel: zipUrl,
      metadata: metadata.copyWith(agentId: agentId),
      agentId: agentId,
    );
  }

  Future<void> deleteSkill(String skillId) async {
    final List<Skill> all = await getIndexedSkills();
    final int index = all.indexWhere((Skill s) => s.id == skillId);
    if (index == -1) {
      return;
    }
    final Skill target = all[index];

    if (target.installedPath != null) {
      final Directory dir = Directory(target.installedPath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    all.removeAt(index);
    await saveSkills(all);
  }

  Future<void> updateSkill(Skill updated) async {
    final List<Skill> all = await getIndexedSkills();
    final int index = all.indexWhere((Skill s) => s.id == updated.id);
    if (index == -1) {
      throw Exception('Skill not found: ${updated.id}');
    }
    all[index] = updated;
    await saveSkills(all);
  }

  /// 将默认 Agent（[defaultAgentId]）的所有 Skill（含自动发现的）全量同步到目标 Agent（[targetAgentId]）。
  ///
  /// 同步规则：
  /// - 通过 getInstalledSkillsForAgent 获取默认 Agent 的全部 Skill（索引 + 自动发现）
  /// - 同名 skill 直接覆盖更新
  /// - 只复制索引记录（共享同一 installedPath），不复制文件
  /// - 目标 Agent 不能是默认 Agent 本身
  ///
  /// 返回实际同步（新增 + 覆盖）的 Skill 数量。
  Future<int> syncSkillsFromDefaultAgent({
    required String defaultAgentId,
    required String targetAgentId,
  }) async {
    // 不允许将默认 Agent 的 skill 同步给自身
    if (defaultAgentId == targetAgentId) {
      return 0;
    }

    // 获取默认 Agent 的全部 Skill（包含索引和自动发现的）
    final List<Skill> defaultSkills =
        await getInstalledSkillsForAgent(defaultAgentId);

    if (defaultSkills.isEmpty) {
      return 0;
    }

    // 读取当前索引文件（同步结果写回索引）
    final List<Skill> all = await getIndexedSkills();

    // 构建目标 Agent 现有 skill 的 name → index 映射，用于覆盖
    final Map<String, int> existingNameIndex = <String, int>{};
    for (int i = 0; i < all.length; i++) {
      if (all[i].agentId == targetAgentId) {
        existingNameIndex[all[i].name] = i;
      }
    }

    int syncedCount = 0;
    for (final Skill source in defaultSkills) {
      final Skill synced = source.copyWith(
        id: _genId('${targetAgentId}_sync_${source.name}'),
        agentId: targetAgentId,
      );

      if (existingNameIndex.containsKey(source.name)) {
        // 同名 skill 已存在 → 覆盖更新
        all[existingNameIndex[source.name]!] = synced;
      } else {
        // 不存在 → 新增
        all.add(synced);
      }
      syncedCount++;
    }

    if (syncedCount > 0) {
      await saveSkills(all);
    }
    return syncedCount;
  }

  Future<Skill> _installFromZip(
    File zipFile, {
    required String sourcePathLabel,
    required String agentId,
    Skill? metadata,
  }) async {
    final List<int> bytes = await zipFile.readAsBytes();
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    final Directory root = await _getSkillRootDir();
    final String folderName = metadata?.id ?? _genId(zipFile.uri.pathSegments.last);
    final Directory outputDir = Directory('${root.path}/$folderName');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    for (final ArchiveFile file in archive) {
      final String cleanPath = _sanitizeZipEntry(file.name);
      if (cleanPath.isEmpty) {
        continue;
      }
      final String outPath = '${outputDir.path}/$cleanPath';
      if (file.isFile) {
        final File outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(_toByteList(file.content));
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    final Skill skill = (metadata ??
            Skill(
              id: folderName,
              agentId: agentId,
              name: folderName,
              version: '0.0.1',
              description: 'Installed from zip package',
              author: 'unknown',
              source: sourcePathLabel,
            ))
        .copyWith(
          installedPath: outputDir.path,
          source: sourcePathLabel,
          agentId: agentId,
        );

    return _persistSkill(skill, sourcePath: outputDir.path);
  }

  Future<Skill> _persistSkill(
    Skill skill, {
    required String sourcePath,
  }) async {
    final List<Skill> all = await getIndexedSkills();
    final int index = all.indexWhere((Skill s) => s.id == skill.id);

    final Skill normalized = skill.copyWith(
      installedPath: skill.installedPath ?? sourcePath,
    );
    if (index >= 0) {
      all[index] = normalized;
    } else {
      all.add(normalized);
    }

    await saveSkills(all);
    return normalized;
  }

  Future<List<Skill>> _discoverSkillsForAgent(String agentId) async {
    final List<String> homeCandidates = _homeCandidates();
    if (homeCandidates.isEmpty) {
      return <Skill>[];
    }

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

      // Priority: top-level subdirectories are treated as installed skills.
      final List<Directory> directDirs = await _listDirsSafe(
        dir,
        permissionDeniedPaths: permissionDeniedPaths,
      );
      for (final Directory child in directDirs) {
        final String basename = _baseName(child.path);
        if (basename.isEmpty || basename.startsWith('.')) {
          continue;
        }
        discovered.add(
          Skill(
            id: _genId('${agentId}_${child.path}_top'),
            agentId: agentId,
            name: basename,
            version: 'local',
            description: '自动发现（一级目录）',
            author: 'local',
            source: 'auto:$root',
            installedPath: child.path,
          ),
        );
      }

      final Set<String> candidateDirs = await _collectCandidateSkillDirs(
        root: dir,
        maxDepth: 4,
        permissionDeniedPaths: permissionDeniedPaths,
      );
      for (final String path in candidateDirs) {
        final String base = _baseName(path);
        if (base.isEmpty || base.startsWith('.')) {
          continue;
        }
        discovered.add(
          Skill(
            id: _genId('${agentId}_${path}_dir'),
            agentId: agentId,
            name: base,
            version: 'local',
            description: '自动发现（目录）',
            author: 'local',
            source: 'auto:$root',
            installedPath: path,
          ),
        );
      }

      final List<File> rootFiles = await _listFilesSafe(
        dir,
        permissionDeniedPaths: permissionDeniedPaths,
      );
      for (final File file in rootFiles) {
        if (!_isSkillFile(file.path)) {
          continue;
        }
        final String basename = _baseName(file.path);
        if (basename.isEmpty || basename.startsWith('.')) {
          continue;
        }
        discovered.add(
          Skill(
            id: _genId('${agentId}_${file.path}_file'),
            agentId: agentId,
            name: basename.split('.').first,
            version: 'local',
            description: '自动发现（文件）',
            author: 'local',
            source: 'auto:$root',
            installedPath: file.path,
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

    return discovered;
  }

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

  Map<String, List<String>> _discoveryRoots(String home) {
    return <String, List<String>>{
      'cursor': <String>[
        '$home/.cursor/skills',
        '$home/.cursor/agent/skills',
        '$home/Library/Application Support/Cursor/skills',
      ],
      'claude_code': <String>[
        '$home/.claude/skills',
        '$home/Library/Application Support/Claude/skills',
      ],
      'codex': <String>[
        '$home/.codex/skills',
        '$home/Library/Application Support/Codex/skills',
      ],
      'trae': <String>[
        '$home/.trae/skills',
        '$home/.trae/agent/skills',
        '$home/.config/trae/skills',
        '$home/Library/Application Support/Trae/skills',
      ],
      // Antigravity 的常见 skill 安装目录
      'antigravity': <String>[
        '$home/.antigravity/skills',
        '$home/.antigravity/agent/skills',
        '$home/.config/antigravity/skills',
        '$home/Library/Application Support/Antigravity/skills',
      ],
    };
  }

  Future<Set<String>> _collectCandidateSkillDirs({
    required Directory root,
    required int maxDepth,
    required Set<String> permissionDeniedPaths,
  }) async {
    final Set<String> candidates = <String>{};
    final Set<String> visited = <String>{};
    final List<({Directory dir, int depth})> queue = <({Directory dir, int depth})>[
      (dir: root, depth: 0),
    ];

    while (queue.isNotEmpty) {
      final ({Directory dir, int depth}) current = queue.removeAt(0);
      final String normalized = current.dir.absolute.path;
      if (visited.contains(normalized)) {
        continue;
      }
      visited.add(normalized);

      final List<Directory> childDirs = await _listDirsSafe(
        current.dir,
        permissionDeniedPaths: permissionDeniedPaths,
      );
      final List<File> files = await _listFilesSafe(
        current.dir,
        permissionDeniedPaths: permissionDeniedPaths,
      );
      final bool hasSkillLikeFile = files.any((File f) => _isSkillFile(f.path));
      final bool hasManifest = files.any((File f) {
        final String name = _baseName(f.path).toLowerCase();
        return name == 'skill.json' ||
            name == 'skill.md' ||
            name == 'manifest.json' ||
            name == 'agent.json' ||
            name == 'readme.md' ||
            name == 'prompt.md';
      });

      if (current.depth == 1) {
        candidates.add(current.dir.path);
      }
      if (current.depth > 0 && (hasManifest || (hasSkillLikeFile && childDirs.isEmpty))) {
        candidates.add(current.dir.path);
      }

      if (current.depth >= maxDepth) {
        continue;
      }

      for (final Directory child in childDirs) {
        final String basename = _baseName(child.path);
        if (basename.isEmpty || basename.startsWith('.')) {
          continue;
        }
        queue.add((dir: child, depth: current.depth + 1));
      }
    }
    return candidates;
  }

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
      // Ignore directory listing errors and continue scanning other paths.
    }
    return results;
  }

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
      // Ignore directory listing errors and continue scanning other paths.
    }
    return results;
  }

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

  String _baseName(String path) {
    final List<String> parts =
        path.replaceAll('\\', '/').split('/').where((String s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '';
    }
    return parts.last;
  }

  bool _isSkillFile(String path) {
    final String lower = path.toLowerCase();
    return lower.endsWith('.json') ||
        lower.endsWith('.yaml') ||
        lower.endsWith('.yml') ||
        lower.endsWith('.md');
  }

  String _sanitizeZipEntry(String name) {
    final String normalized = name.replaceAll('\\', '/').trim();
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('../')) {
      return '';
    }
    return normalized;
  }

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

  String _fingerprint(Skill skill) {
    return '${skill.agentId}:${skill.name}:${skill.installedPath ?? ''}';
  }

  String _genId(String raw) {
    final String lower = raw.toLowerCase();
    return lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll('_zip', '');
  }

  Future<Directory> _getSkillRootDir() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory appDir = Directory('${supportDir.path}/skill_lake/installed');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  Future<File> _getIndexFile() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory appDir = Directory('${supportDir.path}/skill_lake');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File('${appDir.path}/$_indexFileName');
  }
}
