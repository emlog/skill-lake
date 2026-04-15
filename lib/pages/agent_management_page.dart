import 'package:flutter/material.dart';

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
        Expanded(
          child: ListView.separated(
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
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 单个 Agent 卡片组件，展示启用开关和默认状态控制。
class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.onToggleEnabled,
    required this.onSetDefault,
  });

  final AgentTarget agent;

  /// 切换启用状态的回调
  final ValueChanged<bool> onToggleEnabled;

  /// 设为默认的回调；为 null 表示当前已是默认（不可操作）
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;
    final bool isDefault = agent.isDefault;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          // 默认 Agent 使用主色高亮边框
          color: isDefault
              ? color.primary.withValues(alpha: 0.6)
              : color.outlineVariant.withValues(alpha: 0.45),
          width: isDefault ? 1.5 : 1.0,
        ),
        color: isDefault
            ? color.primaryContainer.withValues(alpha: 0.18)
            : color.surfaceContainerLowest,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: <Widget>[
            // Agent 图标头像
            CircleAvatar(
              radius: 18,
              backgroundColor: isDefault
                  ? color.primary.withValues(alpha: 0.18)
                  : color.primaryContainer,
              child: Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: isDefault ? color.primary : color.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            // Agent 名称 + 副标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        agent.displayName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isDefault ? FontWeight.w600 : null,
                            ),
                      ),
                      if (isDefault) ...<Widget>[
                        const SizedBox(width: 6),
                        // 默认标签角标
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '默认',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: color.onPrimary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 设为默认按钮
            Tooltip(
              message: isDefault ? '当前默认 Agent' : '设为默认 Agent',
              child: IconButton(
                onPressed: onSetDefault,
                icon: Icon(
                  isDefault ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isDefault ? color.primary : color.onSurfaceVariant,
                ),
              ),
            ),
            // 启用/禁用开关（默认 Agent 时仍可操作，但建议保持启用）
            Switch(
              value: agent.enabled,
              onChanged: onToggleEnabled,
            ),
          ],
        ),
      ),
    );
  }
}
