import 'package:flutter/material.dart';

import '../models/agent_target.dart';

class AgentManagementPage extends StatelessWidget {
  const AgentManagementPage({
    super.key,
    required this.agents,
    required this.onAgentsChanged,
  });

  final List<AgentTarget> agents;
  final ValueChanged<List<AgentTarget>> onAgentsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
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
          child: Text(
            'Agent 管理',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        const Text('支持配置 Cursor、Claude Code、Codex、Trae 的启用状态。'),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: agents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final AgentTarget item = agents[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: SwitchListTile(
                    secondary: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.smart_toy_outlined, size: 16),
                    ),
                    title: Text(item.displayName),
                    subtitle: Text(item.id),
                    value: item.enabled,
                    onChanged: (bool value) {
                      final List<AgentTarget> updated = <AgentTarget>[
                        ...agents
                      ];
                      updated[index] = item.copyWith(enabled: value);
                      onAgentsChanged(updated);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
