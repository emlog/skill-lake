import 'package:flutter/material.dart';

import '../models/agent_target.dart';
import '../models/skill.dart';
import '../services/skill_service.dart';

/// Skill 管理页面，展示指定 Agent 的已安装 Skill 列表。
///
/// 若当前 Agent 不是默认 Agent，则提供「从默认 Agent 同步」功能按钮。
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
          await _skillService.getInstalledSkillsForAgent(widget.selectedAgent.id);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '无法读取 ${widget.selectedAgent.displayName} 的 Skill 列表：权限不足。'
            '请在系统设置中为应用授权“文件与文件夹”或“完全磁盘访问”，然后点击刷新。$deniedHint',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _skills = <Skill>[];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('读取 ${widget.selectedAgent.displayName} Skill 列表失败，请稍后重试。'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _InlineAgentFilterBar(
                agents: widget.agents,
                selectedIndex: widget.selectedAgentIndex,
                onChanged: widget.onAgentChanged,
              ),
            ),
            const SizedBox(width: 8),
            // 仅在当前 Agent 不是默认 Agent 且存在默认 Agent 时，显示同步按钮
            if (widget.defaultAgent != null &&
                widget.defaultAgent!.id != widget.selectedAgent.id) ...<Widget>[
              IconButton.filledTonal(
                tooltip: '从默认 Agent（${widget.defaultAgent!.displayName}）同步 Skill',
                onPressed: _onSyncFromDefault,
                icon: const Icon(Icons.sync_alt_outlined),
              ),
              const SizedBox(width: 8),
            ],
            IconButton.filled(
              tooltip: '上传安装',
              onPressed: _onUploadInstall,
              icon: const Icon(Icons.upload_file),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '刷新',
              onPressed: _loadSkills,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            _TagPill(label: '总数 ${_skills.length}'),
            const SizedBox(width: 8),
            _TagPill(label: 'Agent: ${widget.selectedAgent.displayName}'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _skills.isEmpty
                  ? const Center(child: Text('暂无已安装 Skill'))
                  : ListView.separated(
                      itemCount: _skills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final Skill skill = _skills[index];
                        final bool readOnly = skill.source.startsWith('auto:');
                        final ColorScheme color = Theme.of(context).colorScheme;
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: color.primaryContainer,
                              child: Icon(
                                readOnly
                                    ? Icons.folder_open_outlined
                                    : Icons.extension_outlined,
                                size: 18,
                                color: color.onPrimaryContainer,
                              ),
                            ),
                            title: Text('${skill.name} (${skill.version})'),
                            subtitle: Text(
                              '${skill.description}\n来源: ${skill.source}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 8,
                              children: <Widget>[
                                IconButton(
                                  tooltip: '查看',
                                  onPressed: () => _onView(skill),
                                  icon: const Icon(Icons.visibility_outlined),
                                ),
                                IconButton(
                                  tooltip: '删除',
                                  onPressed:
                                      readOnly ? null : () => _onDelete(skill),
                                  icon: const Icon(Icons.delete_outline),
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
  Future<void> _onSyncFromDefault() async {
    final AgentTarget? defaultAgent = widget.defaultAgent;
    if (defaultAgent == null || defaultAgent.id == widget.selectedAgent.id) {
      return;
    }
    try {
      final int count = await _skillService.syncSkillsFromDefaultAgent(
        defaultAgentId: defaultAgent.id,
        targetAgentId: widget.selectedAgent.id,
      );
      await _loadSkills();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '已从 ${defaultAgent.displayName} 同步 $count 个 Skill'
                : '无需同步，所有 Skill 已是最新',
          ),
        ),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败：$err')),
      );
    }
  }

  Future<void> _onUploadInstall() async {
    try {
      final Skill? skill = await _skillService.installFromUpload(
        agentId: widget.selectedAgent.id,
      );
      if (!mounted) {
        return;
      }
      if (skill == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消选择文件')),
        );
        return;
      }
      await _loadSkills();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('安装成功：${skill.name}')),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传安装失败：$err')),
      );
    }
  }

  Future<void> _onDelete(Skill skill) async {
    await _skillService.deleteSkill(skill.id);
    await _loadSkills();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除：${skill.name}')),
    );
  }

  Future<void> _onView(Skill skill) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _SkillDetailDialog(skill: skill),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _InlineAgentFilterBar extends StatelessWidget {
  const _InlineAgentFilterBar({
    required this.agents,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<AgentTarget> agents;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (agents.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 8),
            Text('当前没有启用中的 Agent'),
          ],
        ),
      );
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: agents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final AgentTarget agent = agents[index];
          return ChoiceChip(
            selected: index == selectedIndex,
            onSelected: (_) => onChanged(index),
            label: Text(agent.displayName),
            avatar: Icon(_agentIcon(agent.icon), size: 16),
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
      // Antigravity 专属图标
      case 'gravity':
      case 'antigravity':
        return Icons.rocket_launch_outlined;
      default:
        return Icons.smart_toy_outlined;
    }
  }
}

class _SkillDetailDialog extends StatelessWidget {
  const _SkillDetailDialog({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final String tags = skill.tags.isEmpty ? '无' : skill.tags.join(', ');
    return AlertDialog(
      title: const Text('Skill 详情'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SkillDetailRow(label: '名称', value: skill.name),
              _SkillDetailRow(label: '版本', value: skill.version),
              _SkillDetailRow(label: '描述', value: skill.description),
              _SkillDetailRow(label: '作者', value: skill.author),
              _SkillDetailRow(label: '来源', value: skill.source),
              _SkillDetailRow(label: 'Agent', value: skill.agentId),
              _SkillDetailRow(label: '安装路径', value: skill.installedPath ?? '无'),
              _SkillDetailRow(label: '标签', value: tags),
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
