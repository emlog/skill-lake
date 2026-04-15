import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/agent_target.dart';
import '../services/store_service.dart';

/// Skill 商店页面，浏览并在线安装开源 Skill。
///
/// 支持从多个 GitHub 仓库源（如 anthropics/skills、obra/superpowers）
/// 读取 Skill 列表，支持源切换、本地缓存和一键安装。
class SkillStorePage extends StatefulWidget {
  const SkillStorePage({
    super.key,
    required this.selectedAgent,
    this.defaultAgent,
  });

  /// 当前在 Skill 管理页选中的 Agent（用于显示上下文）
  final AgentTarget selectedAgent;

  /// 全局默认 Agent；商店 Skill 将安装到此 Agent
  final AgentTarget? defaultAgent;

  @override
  State<SkillStorePage> createState() => _SkillStorePageState();
}

class _SkillStorePageState extends State<SkillStorePage> {
  final StoreService _storeService = const StoreService();

  /// 当前选中的仓库源索引
  int _selectedSourceIndex = 0;

  /// 是否正在加载
  bool _loading = true;

  /// 是否正在刷新（用于区分首次加载和刷新操作）
  bool _refreshing = false;

  /// 当前源的 Skill 列表
  List<StoreSkillItem> _items = <StoreSkillItem>[];

  /// 正在安装中的 skill id 集合（用于显示安装进度）
  final Set<String> _installingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadStoreSkills();
  }

  /// 获取实际安装目标：优先使用默认 Agent，否则回退到当前选中 Agent
  AgentTarget get _installTarget => widget.defaultAgent ?? widget.selectedAgent;

  /// 当前选中的仓库源
  GitHubSkillSource get _currentSource =>
      StoreService.builtInSources[_selectedSourceIndex];

  /// 从在线索引或缓存加载 Skill 列表
  Future<void> _loadStoreSkills({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _refreshing = forceRefresh;
    });
    final List<StoreSkillItem> items =
        await _storeService.fetchSkillsFromSource(
      _currentSource,
      forceRefresh: forceRefresh,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
      _refreshing = false;
    });
  }

  /// 切换仓库源
  void _onSourceChanged(int index) {
    if (index == _selectedSourceIndex) {
      return;
    }
    setState(() {
      _selectedSourceIndex = index;
    });
    _loadStoreSkills();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;
    final AgentTarget target = _installTarget;
    final bool isDefaultTarget = widget.defaultAgent != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 标题区域
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.surfaceContainerLowest,
            border: Border.all(
              color: color.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Skill Store',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    // 显示安装目标提示
                    Row(
                      children: <Widget>[
                        Icon(
                          isDefaultTarget
                              ? Icons.star_rounded
                              : Icons.smart_toy_outlined,
                          size: 14,
                          color: isDefaultTarget
                              ? color.primary
                              : color.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '将安装到：${target.displayName}${isDefaultTarget ? '（默认 Agent）' : ''}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: isDefaultTarget
                                    ? color.primary
                                    : color.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 刷新按钮（强制刷新缓存）
              IconButton.filledTonal(
                onPressed: _loading
                    ? null
                    : () => _loadStoreSkills(forceRefresh: true),
                tooltip: '刷新缓存',
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 仓库源切换器
        _SourceSwitcher(
          sources: StoreService.builtInSources,
          selectedIndex: _selectedSourceIndex,
          onChanged: _onSourceChanged,
          itemCount: _items.length,
          isLoading: _loading,
        ),
        const SizedBox(height: 12),

        // Skill 列表
        Expanded(
          child: _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        '正在从 ${_currentSource.displayName} 加载 Skill 列表…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: color.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text('暂无可用 Skill，请检查网络后点击刷新'),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _loadStoreSkills(forceRefresh: true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final StoreSkillItem item = _items[index];
                        final bool isInstalling =
                            _installingIds.contains(item.skill.id);
                        return _StoreSkillCard(
                          item: item,
                          isInstalling: isInstalling,
                          onInstall: () => _onInstall(item),
                          onViewDetail: () => _onViewDetail(item),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// 执行安装操作：下载仓库 zip，解压出目标 skill 目录并安装到默认 Agent
  Future<void> _onInstall(StoreSkillItem item) async {
    final AgentTarget target = _installTarget;
    setState(() {
      _installingIds.add(item.skill.id);
    });
    try {
      await _installSkillFromGitHub(item, agentId: target.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '安装成功：${item.skill.name}（已安装到 ${target.displayName}）',
          ),
        ),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('安装失败：$err')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _installingIds.remove(item.skill.id);
        });
      }
    }
  }

  /// 从 GitHub 下载指定 skill 目录并安装到 Agent 的 skills 根目录
  Future<void> _installSkillFromGitHub(
    StoreSkillItem item, {
    required String agentId,
  }) async {
    // 下载仓库 zip
    final http.Response response = await http.get(
      Uri.parse(item.repoZipUrl),
      headers: <String, String>{'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('下载失败：HTTP ${response.statusCode}');
    }

    // 解压 zip
    final Archive archive = ZipDecoder().decodeBytes(response.bodyBytes);

    // GitHub zipball 的目录结构：<owner>-<repo>-<hash>/skills/<skill-name>/...
    // 需要找到正确的 skill 子目录前缀
    final String skillSubPath =
        '${item.source.skillsPath}/${item.skillDirName}/';

    // 过滤出属于目标 Skill 的文件
    final List<ArchiveFile> skillFiles = archive
        .where((ArchiveFile f) => f.name.contains(skillSubPath))
        .toList();

    if (skillFiles.isEmpty) {
      throw Exception('在仓库 zip 中未找到 ${item.skillDirName} 目录');
    }

    // 确定安装目标路径
    final String targetRoot = await _getInstallRoot(agentId);
    final Directory outputDir =
        Directory('$targetRoot/${item.skillDirName}');

    // 同名先删除再安装
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
    await outputDir.create(recursive: true);

    // 解压目标 skill 的文件
    for (final ArchiveFile file in skillFiles) {
      // 提取相对路径：去掉 zip 的顶层目录和 skills/<name>/ 前缀
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
  }

  /// 获取 Agent 的首选 skills 安装目录
  Future<String> _getInstallRoot(String agentId) async {
    final String? home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw Exception('无法获取 HOME 目录');
    }

    // 使用与 SkillService 一致的目录映射
    final Map<String, String> primaryRoots = <String, String>{
      'cursor': '$home/.cursor/skills',
      'claude_code': '$home/.claude/skills',
      'codex': '$home/.codex/skills',
      'trae': '$home/.trae/skills',
      'antigravity': '$home/.gemini/antigravity/skills',
    };

    final String root =
        primaryRoots[agentId] ?? '$home/.skill_lake/$agentId/skills';

    final Directory dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return root;
  }

  /// 查看 Skill 详情弹窗
  Future<void> _onViewDetail(StoreSkillItem item) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _StoreSkillDetailDialog(item: item),
    );
  }
}

/// 仓库源切换器组件
class _SourceSwitcher extends StatelessWidget {
  const _SourceSwitcher({
    required this.sources,
    required this.selectedIndex,
    required this.onChanged,
    required this.itemCount,
    required this.isLoading,
  });

  final List<GitHubSkillSource> sources;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int itemCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.surfaceContainerLow,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.source_outlined, size: 16, color: color.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '源：',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 4),
          // 各源按钮
          ...List<Widget>.generate(sources.length, (int index) {
            final GitHubSkillSource src = sources[index];
            final bool selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                selected: selected,
                onSelected: (_) => onChanged(index),
                avatar: Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: selected ? color.onPrimary : color.onSurfaceVariant,
                ),
                label: Text(src.displayName),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected ? null : color.onSurfaceVariant,
                ),
              ),
            );
          }),
          const Spacer(),
          // Skill 数量标签
          if (!isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$itemCount 个 Skill',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color.onPrimaryContainer,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 商店 Skill 卡片组件
class _StoreSkillCard extends StatelessWidget {
  const _StoreSkillCard({
    required this.item,
    required this.isInstalling,
    required this.onInstall,
    required this.onViewDetail,
  });

  final StoreSkillItem item;
  final bool isInstalling;
  final VoidCallback onInstall;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;

    // 截断过长的描述
    final String desc = item.skill.description.length > 120
        ? '${item.skill.description.substring(0, 120)}…'
        : item.skill.description;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onViewDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 图标
              CircleAvatar(
                radius: 20,
                backgroundColor: color.tertiaryContainer,
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: color.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            item.skill.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 来源标签
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.source.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: color.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color.onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 安装按钮
              isInstalling
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton.filledTonal(
                      onPressed: onInstall,
                      tooltip: '安装',
                      icon: const Icon(Icons.download_rounded, size: 20),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 商店 Skill 详情弹窗
class _StoreSkillDetailDialog extends StatelessWidget {
  const _StoreSkillDetailDialog({required this.item});

  final StoreSkillItem item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome_outlined, color: color.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(item.skill.name)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DetailRow(label: '名称', value: item.skill.name),
              _DetailRow(label: '来源', value: item.source.displayName),
              _DetailRow(label: '目录', value: item.skillDirName),
              _DetailRow(label: '作者', value: item.skill.author),
              _DetailRow(
                label: '描述',
                value: item.skill.description,
              ),
              _DetailRow(
                label: 'SKILL.md',
                value: item.skillMdUrl,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 详情信息行组件
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(
            value.trim().isEmpty ? '无' : value.trim(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
