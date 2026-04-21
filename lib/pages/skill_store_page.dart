import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';

import '../models/agent_target.dart';
import '../services/settings_service.dart';
import '../services/store_service.dart';
import '../utils/snackbar_util.dart';

/// Skill 商店页面，浏览并在线安装开源 Skill。
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
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
          showRefresh: _currentSource is! SkillsmpSkillSource,
          l10n: l10n,
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _currentSource is SkillsmpSkillSource
              ? _buildSkillsmpLayout(l10n)
              : _buildListOrStates(l10n),
        ),
      ],
    );
  }

  Widget _buildSkillsmpLayout(AppLocalizations l10n) {
    // 当没搜索过或结果为空，并且不在加载和报错状态时为“空列表状态”，居中显示搜索组件
    final bool isEmptyState = (!_hasSearched || _items.isEmpty) && !_loading && _errorMessage == null;

    final Widget searchHeader = _SkillsmpSearchHeader(
      settingsService: _settingsService,
      l10n: l10n,
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
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isEmptyState
          ? Container(
              key: const ValueKey('empty_state'),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.travel_explore, 
                    size: 64, 
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 24),
                  searchHeader,
                  if (_hasSearched) ...<Widget>[
                    const SizedBox(height: 24),
                    Text(
                      l10n.noMatchSkill,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 100), // 微调视觉重心
                ],
              ),
            )
          : Column(
              key: const ValueKey('list_state'),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: searchHeader,
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildListOrStates(l10n)),
              ],
            ),
    );
  }

  Widget _buildListOrStates(AppLocalizations l10n) {
    final ColorScheme color = Theme.of(context).colorScheme;

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              l10n.loading,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
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
                l10n.networkError(_errorMessage!),
                textAlign: TextAlign.center,
                style: TextStyle(color: color.error),
              ),
            ),
            const SizedBox(height: 16),
            if (_currentSource is! SkillsmpSkillSource)
              FilledButton.tonalIcon(
                onPressed: () => _loadStoreSkills(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
          ],
        ),
      );
    }

    if (_currentSource is! SkillsmpSkillSource && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: color.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(l10n.noMatchSkill),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final StoreSkillItem item = _items[index];
        final bool isInstalling = _installingIds.contains(item.skill.id);
        return _StoreSkillCard(
          item: item,
          isInstalling: isInstalling,
          onInstall: () => _onInstall(item),
          onViewDetail: () => _onViewDetail(item, l10n),
          l10n: l10n,
        );
      },
    );
  }

  /// 执行安装操作
  Future<void> _onInstall(StoreSkillItem item) async {
    final AgentTarget target = _installTarget;
    setState(() {
      _installingIds.add(item.skill.id);
    });
    try {
      await _installSkillFromGitHub(item, agent: target);
      if (!mounted) {
        return;
      }
      final bool isDefaultTarget = widget.defaultAgent != null;
      final String targetDesc = isDefaultTarget
          ? '默认 Agent: ${target.displayName}'
          : target.displayName;
      SnackbarUtil.show(
        context,
        '安装成功：${item.skill.name} (已安装到 $targetDesc)',
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      final String errMsg = err.toString().replaceFirst('Exception: ', '');
      SnackbarUtil.show(
        context,
        '安装失败：$errMsg',
        isSuccess: false,
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
    required AgentTarget agent,
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
    final String targetRoot = await _getInstallRoot(agent);
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
  Future<String> _getInstallRoot(AgentTarget agent) async {
    final String? home = Platform.isWindows
        ? (Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'])
        : Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw Exception('无法获取 HOME 目录');
    }

    // 优先使用 Agent 自定义的目录设置
    if (agent.skillsDirectory != null && agent.skillsDirectory!.isNotEmpty) {
      return agent.skillsDirectory!.replaceAll('~', home);
    }

    final bool isWin = Platform.isWindows;
    final String? appData = Platform.environment['APPDATA'];

    // 默认内置 Agent 的目录映射（与 SkillService 一致）
    final Map<String, String> primaryRoots = <String, String>{
      'cursor': isWin
          ? (appData != null ? '$appData\\Cursor\\skills' : '$home\\.cursor\\skills')
          : '$home/.cursor/skills',
      'claude_code': isWin
          ? (appData != null ? '$appData\\Claude\\skills' : '$home\\.claude\\skills')
          : '$home/.claude/skills',
      'codex': isWin
          ? (appData != null ? '$appData\\Codex\\skills' : '$home\\.codex\\skills')
          : '$home/.codex/skills',
      'trae': isWin
          ? (appData != null ? '$appData\\Trae\\skills' : '$home\\.trae\\skills')
          : '$home/.trae/skills',
      'gemini_cli': isWin 
          ? '$home\\.gemini\\skills' 
          : '$home/.gemini/skills',      
      'antigravity': isWin
          ? (appData != null ? '$appData\\Antigravity\\skills' : '$home\\.gemini\\antigravity\\skills')
          : '$home/.gemini/antigravity/skills',
      'github_copilot': isWin 
          ? '$home\\.copilot\\skills' 
          : '$home/.copilot/skills',
    };

    final String root = primaryRoots[agent.id] ?? '${home}${Platform.pathSeparator}.skill_lake${Platform.pathSeparator}${agent.id}${Platform.pathSeparator}skills';

    final Directory dir = Directory(root);
    if (!await dir.exists()) {
      throw Exception('目标 Skill 目录不存在：$root\n请先确认该 Agent 是否已正确安装。');
    }
    return root;
  }

  /// 查看 Skill 详情弹窗
  Future<void> _onViewDetail(StoreSkillItem item, AppLocalizations l10n) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _StoreSkillDetailDialog(item: item, l10n: l10n),
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
    required this.l10n,
    this.showRefresh = true,
  });

  final List<SkillSource> sources;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final bool showRefresh;
  final AppLocalizations l10n;

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
          Visibility(
            visible: showRefresh,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: IconButton(
              onPressed: isLoading ? null : onRefresh,
              tooltip: l10n.refreshCache,
              iconSize: 18,
              icon: isRefreshing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
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
    required this.l10n,
  });

  final StoreSkillItem item;
  final bool isInstalling;
  final VoidCallback onInstall;
  final VoidCallback onViewDetail;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;

    // 替换换行符，以便兼容换行
    final String desc = item.skill.description.replaceAll(r'\n', '\n');

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
                      tooltip: l10n.install,
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
  const _StoreSkillDetailDialog({required this.item, required this.l10n});

  final StoreSkillItem item;
  final AppLocalizations l10n;

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
              _DetailRow(label: l10n.author, value: item.skill.author),
              _DetailRow(
                label: l10n.description,
                value: item.skill.description,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
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
            value.trim().isEmpty ? '无' : value.trim().replaceAll(r'\n', '\n'),
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
    required this.l10n,
  });

  final SettingsService settingsService;
  final void Function(String query, String apiKey) onSearch;
  final AppLocalizations l10n;

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
          title: Row(
            children: <Widget>[
              const Icon(Icons.settings_outlined),
              const SizedBox(width: 8),
              Text(widget.l10n.skillsmpSettings),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.l10n.apiKeyHint),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.l10n.getApiKey),
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
              child: Text(widget.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.l10n.save),
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
        SnackbarUtil.show(
          context,
          '已保存 API Key 配置',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _queryController,
            decoration: InputDecoration(
              hintText: widget.l10n.searchHint,
              prefixIcon: Icon(Icons.search, color: color.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.outlineVariant.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.outlineVariant.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.primary),
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFF9F9F9),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _onSearch(),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: _onSearch,
            icon: const Icon(Icons.search, size: 18),
            label: Text(widget.l10n.search),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 44,
          width: 44,
          child: IconButton(
            onPressed: _openSettingsDialog,
            tooltip: widget.l10n.skillsmpSettings,
            iconSize: 20,
            icon: Icon(Icons.settings, color: color.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
