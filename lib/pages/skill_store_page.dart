import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/agent_target.dart';
import '../services/settings_service.dart';
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
  final SettingsService _settingsService = SettingsService();
  final StoreService _storeService = const StoreService();

  /// 当前选中的仓库源索引
  int _selectedSourceIndex = 0;

  /// 是否正在加载
  bool _loading = true;

  /// 是否正在刷新（用于区分首次加载和刷新操作）
  bool _refreshing = false;

  /// 错误信息（仅在真正遇到异常时显示）
  String? _errorMessage;

  /// 对于需要手动触发的源，标识是否已经发起过搜索
  bool _hasSearched = false;

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
  SkillSource get _currentSource =>
      StoreService.builtInSources[_selectedSourceIndex];

  /// 从在线索引或缓存加载 Skill 列表
  Future<void> _loadStoreSkills({bool forceRefresh = false}) async {
    final SkillSource src = _currentSource;
    if (src is SkillsmpSkillSource) {
      if (!mounted) {
        return;
      }
      setState(() {
        _items = <StoreSkillItem>[];
        _loading = false;
        _refreshing = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _refreshing = forceRefresh;
      _errorMessage = null;
      _hasSearched = true;
    });
    try {
      final List<StoreSkillItem> items =
          await _storeService.fetchSkillsFromSource(
        src as GitHubSkillSource,
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
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _refreshing = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// 切换仓库源
  void _onSourceChanged(int index) {
    if (index == _selectedSourceIndex) {
      return;
    }
    setState(() {
      _selectedSourceIndex = index;
      _hasSearched = false;
      _errorMessage = null;
      _items = <StoreSkillItem>[];
    });
    _loadStoreSkills();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 仓库源切换器
        _SourceSwitcher(
          sources: StoreService.builtInSources,
          selectedIndex: _selectedSourceIndex,
          onChanged: _onSourceChanged,
          onRefresh: () => _loadStoreSkills(forceRefresh: true),
          isRefreshing: _refreshing,
          isLoading: _loading,
        ),
        const SizedBox(height: 12),

        // 如果是 Skillsmp 源，显示搜索框
        if (_currentSource is SkillsmpSkillSource) ...<Widget>[
          _SkillsmpSearchHeader(
            settingsService: _settingsService,
            onSearch: (String query, String apiKey) async {
              if (query.isEmpty) return;
              setState(() {
                _loading = true;
                _hasSearched = true;
                _errorMessage = null;
              });
              try {
                final List<StoreSkillItem> items =
                    await _storeService.searchSkillsmp(query, apiKey);
                if (!mounted) {
                  return;
                }
                setState(() {
                  _items = items;
                  _loading = false;
                });
              } catch (e) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _loading = false;
                  _errorMessage = e.toString();
                });
              }
            },
          ),
          const SizedBox(height: 12),
        ],

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
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: color.error.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              '网络请求失败：$_errorMessage',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: color.error),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_currentSource is! SkillsmpSkillSource)
                            FilledButton.tonalIcon(
                              onPressed: () => _loadStoreSkills(forceRefresh: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试'),
                            ),
                        ],
                      ),
                    )
                  : (!_hasSearched)
                      ? const SizedBox.shrink()
                      : _items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 48,
                                    color: color.onSurfaceVariant.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('没有找到符合条件的 Skill'),
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
      final bool isDefaultTarget = widget.defaultAgent != null;
      final String targetDesc = isDefaultTarget
          ? '默认 Agent: ${target.displayName}'
          : target.displayName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '安装成功：${item.skill.name} (已安装到 $targetDesc)',
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
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
  });

  final List<SkillSource> sources;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.surfaceContainerLow,
      ),
      child: Row(
        children: <Widget>[
          // 各源按钮
          ...List<Widget>.generate(sources.length, (int index) {
            final SkillSource src = sources[index];
            final bool selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                selected: selected,
                onSelected: (_) => onChanged(index),
                showCheckmark: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: BorderSide.none,
                backgroundColor: Colors.transparent,
                selectedColor: color.surfaceContainerHigh,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: selected ? color.onSurface : color.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(src.displayName),
                  ],
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? color.onSurface : color.onSurfaceVariant,
                ),
              ),
            );
          }),
          const Spacer(),
          // 刷新按钮
          IconButton(
            onPressed: isLoading ? null : onRefresh,
            tooltip: '刷新缓存',
            iconSize: 18,
            icon: isRefreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
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
        borderRadius: BorderRadius.circular(10),
        onTap: onViewDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 图标
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : color.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : color.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
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
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600, color: color.onSurface),
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
                            border: Border.all(color: color.outlineVariant.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.source.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: color.onSurfaceVariant, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color.onSurfaceVariant,
                            height: 1.4,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 安装按钮
              isInstalling
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: onInstall,
                      tooltip: '安装',
                      iconSize: 20,
                      icon: Icon(Icons.download_rounded, color: color.onSurfaceVariant),
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

/// Skillsmp 搜索及配置区域
class _SkillsmpSearchHeader extends StatefulWidget {
  const _SkillsmpSearchHeader({
    required this.settingsService,
    required this.onSearch,
  });

  final SettingsService settingsService;
  final void Function(String query, String apiKey) onSearch;

  @override
  State<_SkillsmpSearchHeader> createState() => _SkillsmpSearchHeaderState();
}

class _SkillsmpSearchHeaderState extends State<_SkillsmpSearchHeader> {
  final TextEditingController _queryController = TextEditingController();
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final String key = await widget.settingsService.getSkillsmpApiKey();
    if (mounted) {
      setState(() {
        _apiKey = key;
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _onSearch() {
    widget.onSearch(_queryController.text.trim(), _apiKey);
  }

  Future<void> _openSettingsDialog() async {
    final TextEditingController apiController =
        TextEditingController(text: _apiKey);
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.settings_outlined),
              SizedBox(width: 8),
              Text('Skillsmp 设置'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('设置您自己的 API Key 可以获得更多的搜索额度。'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('获取 API Key：'),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final Uri url = Uri.parse('https://skillsmp.com/docs/api');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        child: Text(
                          'https://skillsmp.com/docs/api',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: apiController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk_...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    isDense: true,
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      final String newKey = apiController.text.trim();
      await widget.settingsService.saveSkillsmpApiKey(newKey);
      if (mounted) {
        setState(() {
          _apiKey = newKey;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存 API Key 配置')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _queryController,
            decoration: const InputDecoration(
              labelText: '搜索 Skill',
              hintText: '支持语义搜索，例如：最适合前端开发的SKILL',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _onSearch(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 40,
          child: FilledButton.icon(
            onPressed: _onSearch,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('搜索'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _openSettingsDialog,
          tooltip: 'Skillsmp 配置',
          iconSize: 18,
          icon: const Icon(Icons.settings),
        ),
      ],
    );
  }
}
