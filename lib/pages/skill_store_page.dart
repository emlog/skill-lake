import 'package:flutter/material.dart';

import '../models/agent_target.dart';
import '../services/skill_service.dart';
import '../services/store_service.dart';

class SkillStorePage extends StatefulWidget {
  const SkillStorePage({
    super.key,
    required this.selectedAgent,
  });

  final AgentTarget selectedAgent;

  @override
  State<SkillStorePage> createState() => _SkillStorePageState();
}

class _SkillStorePageState extends State<SkillStorePage> {
  final StoreService _storeService = const StoreService();
  final SkillService _skillService = SkillService();
  bool _loading = true;
  List<StoreSkillItem> _items = <StoreSkillItem>[];

  @override
  void initState() {
    super.initState();
    _loadStoreSkills();
  }

  @override
  void didUpdateWidget(covariant SkillStorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAgent.id != widget.selectedAgent.id) {
      _loadStoreSkills();
    }
  }

  Future<void> _loadStoreSkills() async {
    setState(() => _loading = true);
    final List<StoreSkillItem> items = await _storeService.fetchStoreSkills();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
                child: Text(
                  'Skill 商店 · ${widget.selectedAgent.displayName}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filledTonal(
                onPressed: _loadStoreSkills,
                tooltip: '刷新',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('读取开源 Skill 仓库索引，支持在线下载安装。'),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('暂无可用 Skill，检查网络或仓库索引地址'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final StoreSkillItem item = _items[index];
                        final ColorScheme color = Theme.of(context).colorScheme;
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: color.tertiaryContainer,
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 18,
                                color: color.onTertiaryContainer,
                              ),
                            ),
                            title: Text(
                              '${item.skill.name} (${item.skill.version})',
                            ),
                            subtitle: Text(
                              '${item.skill.description}\n来源: ${item.repository}',
                            ),
                            isThreeLine: true,
                            trailing: FilledButton.tonalIcon(
                              onPressed: item.zipUrl.isEmpty
                                  ? null
                                  : () => _onInstall(item),
                              icon: const Icon(Icons.download),
                              label: const Text('安装'),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _onInstall(StoreSkillItem item) async {
    try {
      await _skillService.installFromStore(
        zipUrl: item.zipUrl,
        metadata: item.skill,
        agentId: widget.selectedAgent.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('安装成功：${item.skill.name}')),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('安装失败：$err')),
      );
    }
  }
}
