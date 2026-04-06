import 'package:flutter/material.dart';

import '../models/agent_target.dart';
import '../models/skill.dart';
import '../services/skill_service.dart';

class SkillManagementPage extends StatefulWidget {
  const SkillManagementPage({
    super.key,
    required this.selectedAgent,
    required this.agents,
    required this.selectedAgentIndex,
    required this.onAgentChanged,
  });

  final AgentTarget selectedAgent;
  final List<AgentTarget> agents;
  final int selectedAgentIndex;
  final ValueChanged<int> onAgentChanged;

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
    final List<Skill> all =
        await _skillService.getInstalledSkillsForAgent(widget.selectedAgent.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _skills = all;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _InlineAgentFilterBar(
          agents: widget.agents,
          selectedIndex: widget.selectedAgentIndex,
          onChanged: widget.onAgentChanged,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Skill 管理 · ${widget.selectedAgent.displayName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '自动读取本地目录并合并展示已安装清单',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _onUploadInstall,
                icon: const Icon(Icons.upload_file),
                label: const Text('上传安装'),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '刷新',
                onPressed: _loadSkills,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
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
                                  tooltip: '编辑',
                                  onPressed: readOnly ? null : () => _onEdit(skill),
                                  icon: const Icon(Icons.edit_outlined),
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

  Future<void> _onEdit(Skill skill) async {
    final Skill? updated = await showDialog<Skill>(
      context: context,
      builder: (BuildContext context) => _SkillEditDialog(skill: skill),
    );
    if (updated == null) {
      return;
    }
    await _skillService.updateSkill(updated);
    await _loadSkills();
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
      default:
        return Icons.smart_toy_outlined;
    }
  }
}

class _SkillEditDialog extends StatefulWidget {
  const _SkillEditDialog({required this.skill});

  final Skill skill;

  @override
  State<_SkillEditDialog> createState() => _SkillEditDialogState();
}

class _SkillEditDialogState extends State<_SkillEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _versionController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.skill.name);
    _versionController = TextEditingController(text: widget.skill.version);
    _descriptionController =
        TextEditingController(text: widget.skill.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _versionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑 Skill'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            TextField(
              controller: _versionController,
              decoration: const InputDecoration(labelText: '版本'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '描述'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.skill.copyWith(
                name: _nameController.text.trim(),
                version: _versionController.text.trim(),
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
