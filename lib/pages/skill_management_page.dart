import 'dart:io';

import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

import '../models/agent_target.dart';
import '../models/skill.dart';
import '../services/skill_service.dart';
import '../utils/snackbar_util.dart';

/// Skill 管理页面，展示指定 Agent 的已安装 Skill 列表。
class SkillManagementPage extends StatefulWidget {
  const SkillManagementPage({
    super.key,
    required this.selectedAgent,
    required this.agents,
    required this.selectedAgentIndex,
    required this.onAgentChanged,
    this.defaultAgent,
  });

  final AgentTarget selectedAgent;
  final List<AgentTarget> agents;
  final int selectedAgentIndex;
  final ValueChanged<int> onAgentChanged;

  /// 当前设定的默认 Agent；用于判断是否展示同步按钮，以及执行同步操作
  final AgentTarget? defaultAgent;

  @override
  State<SkillManagementPage> createState() => _SkillManagementPageState();
}

class _SkillManagementPageState extends State<SkillManagementPage> {
  final SkillService _skillService = SkillService();
  List<Skill> _skills = <Skill>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  @override
  void didUpdateWidget(covariant SkillManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAgent.id != widget.selectedAgent.id) {
      _loadSkills();
    }
  }

  Future<void> _loadSkills() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    try {
      final List<Skill> all =
          await _skillService.getInstalledSkillsForAgent(widget.selectedAgent);
      if (!mounted) {
        return;
      }
      setState(() {
        _skills = all;
        _loading = false;
      });
    } on SkillPermissionException catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        _skills = <Skill>[];
        _loading = false;
      });
      final String deniedHint =
          err.deniedPaths.isEmpty ? '' : '\n受限路径：${err.deniedPaths.first}';
      SnackbarUtil.show(
        context,
        '无法读取 ${widget.selectedAgent.displayName} 的 Skill 列表：权限不足。请在系统设置中为应用授权“文件与文件夹”或“完全磁盘访问”，然后点击刷新。$deniedHint',
        isSuccess: false,
        duration: const Duration(seconds: 6),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _skills = <Skill>[];
        _loading = false;
      });
      SnackbarUtil.show(
        context,
        '读取 ${widget.selectedAgent.displayName} Skill 列表失败，请稍后重试。',
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _InlineAgentFilterBar(
                  agents: widget.agents,
                  selectedIndex: widget.selectedAgentIndex,
                  onChanged: widget.onAgentChanged,
                  defaultAgent: widget.defaultAgent,
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: 8),
              // 仅在当前 Agent 不是默认 Agent 且存在默认 Agent 时，显示同步按钮
              if (widget.defaultAgent != null &&
                  widget.defaultAgent!.id != widget.selectedAgent.id) ...<Widget>[
                IconButton(
                  tooltip: '${l10n.syncFromDefault}（${widget.defaultAgent!.displayName}）',
                  iconSize: 18,
                  onPressed: () => _onSyncFromDefault(l10n),
                  icon: const Icon(Icons.sync_alt_outlined),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                tooltip: l10n.uploadInstall,
                iconSize: 18,
                onPressed: _onUploadInstall,
                icon: const Icon(Icons.upload),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.refresh,
                iconSize: 18,
                onPressed: _loadSkills,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.deleteAll,
                iconSize: 18,
                onPressed: _skills.isEmpty ? null : () => _onDeleteAllSkills(l10n),
                icon: Icon(Icons.delete_sweep, color: _skills.isEmpty ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.error),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _skills.isEmpty
                  ? Center(child: Text(l10n.noInstalledSkill))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _skills.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == _skills.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                l10n.totalCount(_skills.length),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline),
                              ),
                            ),
                          );
                        }
                        final Skill skill = _skills[index];
                        // 有 installedPath 即可删除（不区分 auto/sync/upload）
                        final bool canDelete =
                            skill.installedPath?.isNotEmpty == true;
                        final ColorScheme color = Theme.of(context).colorScheme;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: color.outlineVariant.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.4),
                              width: 0.5,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : color.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.extension_outlined,
                                size: 18,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : color.onSurfaceVariant,
                              ),
                            ),
                            title: GestureDetector(
                              onTap: () => _onView(skill, l10n),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Text(
                                  skill.version == 'local' || skill.version.isEmpty
                                      ? skill.name
                                      : '${skill.name} (${skill.version})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: color.onSurface,
                                    decoration: TextDecoration.underline,
                                    decorationColor: color.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                skill.description.trim().isEmpty
                                    ? '暂无描述'
                                    : skill.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: color.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 4,
                              children: <Widget>[
                                IconButton(
                                  tooltip: l10n.view,
                                  iconSize: 20,
                                  onPressed: () => _onView(skill, l10n),
                                  icon: const Icon(Icons.more_horiz),
                                  color: color.onSurfaceVariant,
                                ),
                                IconButton(
                                  tooltip: l10n.delete,
                                  iconSize: 20,
                                  onPressed:
                                      canDelete ? () => _onDelete(skill, l10n) : null,
                                  icon: const Icon(Icons.delete_outline),
                                  color: color.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// 从默认 Agent 同步 Skill 到当前 Agent（单向，不可反向同步）
  Future<void> _onSyncFromDefault(AppLocalizations l10n) async {
    final AgentTarget? defaultAgent = widget.defaultAgent;
    if (defaultAgent == null || defaultAgent.id == widget.selectedAgent.id) {
      return;
    }
    try {
      final int count = await _skillService.syncSkillsFromDefaultAgent(
        defaultAgent: defaultAgent,
        targetAgent: widget.selectedAgent,
      );
      await _loadSkills();
      if (!mounted) {
        return;
      }
      SnackbarUtil.show(
        context,
        count > 0
            ? '已从 ${defaultAgent.displayName} 同步 $count 个 Skill'
            : '无需同步，所有 Skill 已是最新',
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      final String errMsg = err.toString().replaceFirst('Exception: ', '');
      SnackbarUtil.show(
        context,
        '同步失败：$errMsg',
        isSuccess: false,
      );
    }
  }

  Future<void> _onUploadInstall() async {
    try {
      final Skill? skill = await _skillService.installFromUpload(
        agent: widget.selectedAgent,
      );
      if (!mounted) {
        return;
      }
      if (skill == null) {
        SnackbarUtil.show(context, '已取消选择文件', isSuccess: true);
        return;
      }
      await _loadSkills();
      if (!mounted) {
        return;
      }
      SnackbarUtil.show(context, '安装成功：${skill.name}');
    } catch (err) {
      if (!mounted) {
        return;
      }
      final String errMsg = err.toString().replaceFirst('Exception: ', '');
      SnackbarUtil.show(context, '上传安装失败：$errMsg', isSuccess: false);
    }
  }

  /// 全部删除当前 Agent 下的所有 Skill
  Future<void> _onDeleteAllSkills(AppLocalizations l10n) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.confirmDeleteAll),
          content: Text(l10n.confirmDeleteAllContent),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(l10n.deleteAll),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await _skillService.deleteAllSkillsForAgent(widget.selectedAgent);
      await _loadSkills();
      if (!mounted) {
        return;
      }
      SnackbarUtil.show(context, '已删除所有 Skill');
    } catch (err) {
      if (!mounted) {
        return;
      }
      final String errMsg = err.toString().replaceFirst('Exception: ', '');
      SnackbarUtil.show(context, '删除失败：$errMsg', isSuccess: false);
    }
  }

  /// 删除 Skill：物理删除对应文件夹，成功后刷新列表。
  Future<void> _onDelete(Skill skill, AppLocalizations l10n) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.confirmDelete),
          content: Text(l10n.confirmDeleteContent(skill.name)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await _skillService.deleteSkill(skill);
      await _loadSkills();
      if (!mounted) {
        return;
      }
      SnackbarUtil.show(context, '已删除：${skill.name}');
    } catch (err) {
      if (!mounted) {
        return;
      }
      SnackbarUtil.show(context, '删除失败：$err', isSuccess: false);
    }
  }

  Future<void> _onView(Skill skill, AppLocalizations l10n) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _SkillDetailDialog(skill: skill, l10n: l10n),
    );
  }
}

class _InlineAgentFilterBar extends StatelessWidget {
  const _InlineAgentFilterBar({
    required this.agents,
    required this.selectedIndex,
    required this.onChanged,
    required this.l10n,
    this.defaultAgent,
  });

  final List<AgentTarget> agents;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final AgentTarget? defaultAgent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (agents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Text(l10n.noEnabledAgentHint),
          ],
        ),
      );
    }

    final List<AgentTarget> displayAgents = List<AgentTarget>.from(agents);
    if (defaultAgent != null) {
      displayAgents.sort((a, b) {
        if (a.id == defaultAgent!.id) return -1;
        if (b.id == defaultAgent!.id) return 1;
        return 0;
      });
    }

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayAgents.length,
        itemBuilder: (BuildContext context, int displayIndex) {
          final AgentTarget agent = displayAgents[displayIndex];
          final int originalIndex = agents.indexOf(agent);
          final bool isDefault = defaultAgent != null && defaultAgent!.id == agent.id;
          final bool selected = originalIndex == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => onChanged(originalIndex),
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide.none,
              backgroundColor: Colors.transparent,
              selectedColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(agent.displayName),
                  if (isDefault) ...<Widget>[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.defaultLabel,
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              avatar: Icon(_agentIcon(agent.icon), size: 14, color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        },
      ),
    );
  }

  IconData _agentIcon(String value) {
    switch (value) {
      case 'cursor':
        return Icons.ads_click_outlined;
      case 'bolt':
        return Icons.bolt_outlined;
      case 'terminal':
        return Icons.terminal;
      case 'sparkles':
        return Icons.auto_awesome_outlined;
      case 'gravity':
      case 'antigravity':
        return Icons.rocket_launch_outlined;
      default:
        return Icons.smart_toy_outlined;
    }
  }
}

class _SkillDetailDialog extends StatelessWidget {
  const _SkillDetailDialog({required this.skill, required this.l10n});

  final Skill skill;
  final AppLocalizations l10n;

  Future<String> _loadSkillMd() async {
    final String? path = skill.installedPath;
    if (path == null || path.isEmpty) {
      return '未找到本地路径，无法读取文件内容。';
    }
    final Directory dir = Directory(path);
    if (!await dir.exists()) {
      return '本地路径不存在。';
    }

    try {
      final List<FileSystemEntity> files = await dir.list().toList();
      for (final FileSystemEntity f in files) {
        if (f is File && f.uri.pathSegments.last.toLowerCase() == 'skill.md') {
          return await f.readAsString();
        }
      }
    } catch (e) {
      return '读取文件失败: $e';
    }
    return '未找到 SKILL.md 文件。';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome_outlined, color: color.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(skill.name)),
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SkillDetailRow(label: l10n.description, value: skill.description),
            _SkillDetailRow(
              label: l10n.path,
              value: skill.installedPath?.isNotEmpty == true
                  ? skill.installedPath!
                  : skill.source,
            ),
            const Divider(),
            Text(
              'SKILL.md',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: FutureBuilder<String>(
                  future: _loadSkillMd(),
                  builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return SingleChildScrollView(
                      child: SelectableText(
                        snapshot.data ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
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

class _SkillDetailRow extends StatelessWidget {
  const _SkillDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
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
