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

  /// 获取指定 Agent 的全部已安装 Skill（索引 + 自动发现）。
  ///
  /// 合并规则：
  /// - 先获取自动发现的 Skill（以文件系统为唯一真相）。
  /// - 再从索引中读取属于该 Agent 的记录，**仅保留** installedPath
  ///   确实位于该 Agent 自己 discovery roots 下的记录，防止旧的错误同步
  ///   记录（installedPath 指向其他 Agent 目录）污染列表。
  /// - 以 fingerprint（agentId:name:path）去重后合并。
  Future<List<Skill>> getInstalledSkillsForAgent(String agentId) async {
    final List<Skill> discovered = await _discoverSkillsForAgent(agentId);
    final List<Skill> indexed = await _getIndexedSkillsForAgent(agentId);

    // 构建该 Agent 允许的合法路径前缀集合
    final List<String> homes = _homeCandidates();
    final Set<String> validRoots = <String>{};
    for (final String home in homes) {
      validRoots.addAll(_discoveryRoots(home)[agentId] ?? const <String>[]);
    }

    // 过滤索引记录：installedPath 必须以该 Agent 的某个 root 开头
    // 路径为空或指向其他 Agent 目录的旧记录直接丢弃
    final List<Skill> validIndexed = indexed.where((Skill s) {
      final String? path = s.installedPath;
      if (path == null || path.isEmpty) return false;
      return validRoots.any((String root) => path.startsWith(root));
    }).toList();

    final Map<String, Skill> merged = <String, Skill>{};
    for (final Skill skill in validIndexed) {
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

    // 安全保护：仅删除 upload 或 store 类型的技能文件夹。
    // auto 或 sync 类型的技能路径指向的是外部或共享目录，仅移除索引记录，不触发物理删除。
    final String source = target.source.toLowerCase();
    final bool isPrivateFolder =
        source.contains('upload') || source.contains('http');

    if (isPrivateFolder && target.installedPath != null) {
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

  /// 将默认 Agent（[defaultAgentId]）的所有 Skill 文件夹**物理复制**到目标 Agent（[targetAgentId]）的首选目录。
  ///
  /// 同步规则：
  /// 1. 读取默认 Agent 的所有发现根目录，扫描包含 SKILL.md 的一级子目录。
  /// 2. 确定目标 Agent 的首选存放目录（[_primaryDiscoveryRoot]），不存在则自动创建。
  /// 3. 将每个 Skill 子文件夹**递归复制**到目标目录；同名则先删除旧文件夹再覆盖。
  /// 4. 复制完成后更新索引记录（source 标记为 sync:<defaultAgentId>）。
  /// 5. 目标 Agent 不能是默认 Agent 本身。
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

    // 获取 HOME 路径候选列表
    final List<String> homes = _homeCandidates();
    if (homes.isEmpty) {
      return 0;
    }

    // 收集默认 Agent 所有发现根目录，并扫描包含 SKILL.md 的一级子目录
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

    // 读取当前索引，用于覆盖更新
    final List<Skill> all = await getIndexedSkills();
    // 构建目标 Agent 现有 skill 的 name → index 映射
    final Map<String, int> existingNameIndex = <String, int>{};
    for (int i = 0; i < all.length; i++) {
      if (all[i].agentId == targetAgentId) {
        existingNameIndex[all[i].name] = i;
      }
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

      // 构造新的索引 Skill 记录
      final Skill synced = Skill(
        id: _genId('${targetAgentId}_sync_$skillName'),
        agentId: targetAgentId,
        name: skillName,
        version: 'local',
        description: '从默认 Agent 同步',
        author: 'sync',
        source: 'sync:$defaultAgentId',
        installedPath: destDir.absolute.path,
      );

      if (existingNameIndex.containsKey(skillName)) {
        // 同名 → 覆盖索引中的旧记录
        all[existingNameIndex[skillName]!] = synced;
      } else {
        // 新增
        all.add(synced);
      }
      syncedCount++;
    }

    if (syncedCount > 0) {
      await saveSkills(all);
    }
    return syncedCount;
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
  /// 用于确定同步时文件的写入位置。
  String _primaryDiscoveryRoot(String agentId, String home) {
    final List<String>? roots = _discoveryRoots(home)[agentId];
    if (roots == null || roots.isEmpty) {
      // 兜底：使用 ~/.skill_lake/<agentId>/skills
      return '$home/.skill_lake/$agentId/skills';
    }
    return roots.first;
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

  /// 自动发现指定 Agent 的已安装 Skill 列表。
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

    // 收集该 agent 所有需要扫描的根目录
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

        // 仅当目录内含 SKILL.md 时才视为有效 Skill
        if (!await _hasSkillMd(child, permissionDeniedPaths: permissionDeniedPaths)) {
          continue;
        }

        // 使用真实绝对路径，确保展示路径与磁盘路径完全一致
        final String realPath = child.absolute.path;

        discovered.add(
          Skill(
            id: _genId('${agentId}_$realPath'),
            agentId: agentId,
            name: basename,
            version: 'local',
            description: '自动发现',
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
  /// - Antigravity  : ~/.gemini/antigravity/skills/
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
      // Antigravity 官方 skills 目录（位于 ~/.gemini/antigravity/skills/）
      'antigravity': <String>[
        '$home/.gemini/antigravity/skills',
        '$home/Library/Application Support/Antigravity/skills',
      ],
    };
  }

  // _collectCandidateSkillDirs 已移除。
  // 新规则：只有包含 SKILL.md 的直接子目录才被识别为有效 Skill，参见 _hasSkillMd。

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
