import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/agent_target.dart';

/// Agent 管理页面，支持启用/禁用 Agent 以及设置默认 Agent。
///
/// - 每个 Agent 卡片右侧有「设为默认」图标按钮
/// - 当前默认 Agent 卡片高亮显示，默认标记不可取消（只能通过设置其他 Agent 来切换）
class AgentManagementPage extends StatelessWidget {
  const AgentManagementPage({
    super.key,
    required this.agents,
    required this.onAgentsChanged,
    required this.onDefaultAgentChanged,
  });

  final List<AgentTarget> agents;

  /// Agent 列表发生变更时的回调（启用/禁用）
  final ValueChanged<List<AgentTarget>> onAgentsChanged;

  /// 默认 Agent 切换时的回调，传入新的默认 Agent id
  final ValueChanged<String> onDefaultAgentChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '添加自定义 Agent',
              onPressed: () => _showAddAgentDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: agents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final AgentTarget item = agents[index];
              return _AgentCard(
                agent: item,
                // 启用/禁用开关回调
                onToggleEnabled: (bool value) {
                  final List<AgentTarget> updated = <AgentTarget>[...agents];
                  updated[index] = item.copyWith(enabled: value);
                  onAgentsChanged(updated);
                },
                // 设为默认回调
                onSetDefault: item.isDefault
                    ? null // 已是默认则禁用按钮
                    : () => onDefaultAgentChanged(item.id),
                onEdit: () => _editCustomAgent(context, index, item),
                onDelete: () => _deleteCustomAgent(context, index, item),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddAgentDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController dirController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('添加自定义 Agent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Agent 名称',
                  hintText: '例如：My Custom Agent',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dirController,
                decoration: const InputDecoration(
                  labelText: 'Skill 目录',
                  hintText: '例如：~/.myagent/skills/',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final String name = nameController.text.trim();
                final String dir = dirController.text.trim();
                if (name.isNotEmpty && dir.isNotEmpty) {
                  final String newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                  final AgentTarget newAgent = AgentTarget(
                    id: newId,
                    displayName: name,
                    icon: 'robot_2',
                    skillsDirectory: dir,
                  );
                  onAgentsChanged(<AgentTarget>[...agents, newAgent]);
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  void _editCustomAgent(BuildContext context, int index, AgentTarget agent) {
    final TextEditingController nameController = TextEditingController(text: agent.displayName);
    final TextEditingController dirController = TextEditingController(text: agent.skillsDirectory);

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('编辑自定义 Agent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Agent 名称'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dirController,
                decoration: const InputDecoration(labelText: 'Skill 目录'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final String name = nameController.text.trim();
                final String dir = dirController.text.trim();
                if (name.isNotEmpty && dir.isNotEmpty) {
                  final List<AgentTarget> updated = <AgentTarget>[...agents];
                  updated[index] = agent.copyWith(
                    displayName: name,
                    skillsDirectory: dir,
                  );
                  onAgentsChanged(updated);
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCustomAgent(BuildContext context, int index, AgentTarget agent) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除自定义 Agent'),
          content: Text('确定要删除「${agent.displayName}」吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                final List<AgentTarget> updated = <AgentTarget>[...agents];
                updated.removeAt(index);
                // 如果删除的是默认 Agent，这里会导致没有默认 Agent。
                // 简单处理：如果是默认，且列表还有其他开启的数据，可以在后面处理，
                // 但 `onAgentsChanged` 处理更佳，这里直接交由上层。
                onAgentsChanged(updated);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}

/// 单个 Agent 卡片组件，展示启用开关和默认状态控制。
class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.onToggleEnabled,
    required this.onSetDefault,
    this.onEdit,
    this.onDelete,
  });

  final AgentTarget agent;

  /// 切换启用状态的回调
  final ValueChanged<bool> onToggleEnabled;

  /// 设为默认的回调；为 null 表示当前已是默认（不可操作）
  final VoidCallback? onSetDefault;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDefault = agent.isDefault;

    return GestureDetector(
      onTap: () => _showAgentDetails(context, agent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
            width: 0.5,
          ),
          color: color.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              // Agent 图标头像
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDefault ? color.primary : color.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 18,
                  color: isDefault ? color.onPrimary : color.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              // Agent 名称 + 副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          agent.displayName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: isDefault ? FontWeight.w600 : FontWeight.w500,
                                color: color.onSurface,
                              ),
                        ),
                        if (isDefault) ...<Widget>[
                          const SizedBox(width: 8),
                          // 默认标签角标
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '默认',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: color.onSurface, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 编辑/删除按钮（仅限自定义Agent）
              if (agent.id.startsWith('custom_')) ...[
                Tooltip(
                  message: '编辑 Agent',
                  child: IconButton(
                    onPressed: onEdit,
                    iconSize: 20,
                    icon: Icon(Icons.edit_outlined, color: color.onSurfaceVariant),
                  ),
                ),
                Tooltip(
                  message: '删除 Agent',
                  child: IconButton(
                    onPressed: onDelete,
                    iconSize: 20,
                    icon: Icon(Icons.delete_outline, color: color.error),
                  ),
                ),
              ],
              // 设为默认按钮
              Tooltip(
                message: isDefault ? '当前默认 Agent' : '设为默认 Agent',
                child: IconButton(
                  onPressed: onSetDefault,
                  iconSize: 20,
                  icon: Icon(
                    isDefault ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isDefault ? color.primary : color.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // 启用/禁用开关
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: agent.enabled,
                  onChanged: onToggleEnabled,
                  activeThumbColor: color.onPrimary,
                  activeTrackColor: color.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAgentDetails(BuildContext context, AgentTarget agent) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(agent.displayName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DetailRow(
                label: '主页',
                value: agent.homepageUrl ?? '无',
                isLink: agent.homepageUrl != null && agent.homepageUrl!.isNotEmpty,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Skill 目录',
                value: agent.skillsDirectory ?? '未配置或不支持',
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLink = false,
  });

  final String label;
  final String value;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        if (isLink && value != '无')
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => launchUrl(Uri.parse(value)),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: colorScheme.primary,
                    ),
              ),
            ),
          )
        else
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}
