import 'package:flutter/material.dart';

import '../models/agent_target.dart';
import '../services/skill_service.dart';
import '../services/store_service.dart';

/// Skill 商店页面，浏览并在线安装开源 Skill。
///
/// 安装目标为默认 Agent（[defaultAgent]）；若没有默认 Agent 则回退到当前选中 Agent。
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

  /// 获取实际安装目标：优先使用默认 Agent，否则回退到当前选中 Agent
  AgentTarget get _installTarget => widget.defaultAgent ?? widget.selectedAgent;

  /// 从在线索引加载 Skill 列表
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
    final ColorScheme color = Theme.of(context).colorScheme;
    final AgentTarget target = _installTarget;
    final bool isDefaultTarget = widget.defaultAgent != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 标题区域
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.surfaceContainerLowest,
            border: Border.all(
              color: color.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Skill 商店',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    // 显示安装目标提示
                    Row(
                      children: <Widget>[
                        Icon(
                          isDefaultTarget
                              ? Icons.star_rounded
                              : Icons.smart_toy_outlined,
                          size: 14,
                          color: isDefaultTarget
                              ? color.primary
                              : color.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '将安装到：${target.displayName}${isDefaultTarget ? '（默认 Agent）' : ''}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: isDefaultTarget
                                    ? color.primary
                                    : color.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
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

  /// 执行安装操作，安装目标为默认 Agent（优先）或当前选中 Agent
  Future<void> _onInstall(StoreSkillItem item) async {
    final AgentTarget target = _installTarget;
    try {
      await _skillService.installFromStore(
        zipUrl: item.zipUrl,
        metadata: item.skill,
        agentId: target.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('安装成功：${item.skill.name}（已安装到 ${target.displayName}）'),
        ),
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
