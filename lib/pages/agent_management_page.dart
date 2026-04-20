import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';

import '../models/agent_target.dart';

/// Agent 管理页面，支持启用/禁用 Agent 以及设置默认 Agent。
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.addCustomAgent,
                onPressed: () => _showAddAgentDialog(context, l10n),
              ),
            ],
          ),
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
                l10n: l10n,
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
                onEdit: () => _editCustomAgent(context, index, item, l10n),
                onDelete: () => _deleteCustomAgent(context, index, item, l10n),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddAgentDialog(BuildContext context, AppLocalizations l10n) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController dirController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.addCustomAgent),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.agentName,
                  hintText: '例如：My Custom Agent',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dirController,
                decoration: InputDecoration(
                  labelText: l10n.skillsDirectory,
                  hintText: '例如：~/.myagent/skills/',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
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
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );
  }

  void _editCustomAgent(BuildContext context, int index, AgentTarget agent, AppLocalizations l10n) {
    final TextEditingController nameController = TextEditingController(text: agent.displayName);
    final TextEditingController dirController = TextEditingController(text: agent.skillsDirectory);

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.editCustomAgent),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.agentName),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dirController,
                decoration: InputDecoration(labelText: l10n.skillsDirectory),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
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
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  void _deleteCustomAgent(BuildContext context, int index, AgentTarget agent, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteCustomAgent),
          content: Text(l10n.confirmDeleteContent(agent.displayName)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                final List<AgentTarget> updated = <AgentTarget>[...agents];
                updated.removeAt(index);
                onAgentsChanged(updated);
                Navigator.of(dialogContext).pop();
              },
              child: Text(l10n.delete),
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
    required this.l10n,
    required this.onToggleEnabled,
    required this.onSetDefault,
    this.onEdit,
    this.onDelete,
  });

  final AgentTarget agent;
  final AppLocalizations l10n;

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
      onTap: () => _showAgentDetails(context, agent, l10n),
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
                              l10n.defaultLabel,
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
                  message: l10n.edit,
                  child: IconButton(
                    onPressed: onEdit,
                    iconSize: 20,
                    icon: Icon(Icons.edit_outlined, color: color.onSurfaceVariant),
                  ),
                ),
                Tooltip(
                  message: l10n.delete,
                  child: IconButton(
                    onPressed: onDelete,
                    iconSize: 20,
                    icon: Icon(Icons.delete_outline, color: color.error),
                  ),
                ),
              ],
              // 设为默认按钮
              Tooltip(
                message: isDefault ? l10n.currentDefaultAgent : l10n.setDefaultAgent,
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

  void _showAgentDetails(BuildContext context, AgentTarget agent, AppLocalizations l10n) {
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
                label: l10n.homepage,
                value: agent.homepageUrl ?? '无',
                isLink: agent.homepageUrl != null && agent.homepageUrl!.isNotEmpty,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: l10n.skillsDirectory,
                value: agent.skillsDirectory ?? '未配置或不支持',
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
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
