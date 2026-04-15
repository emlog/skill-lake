/// Agent 目标实体，代表一个已配置的 AI Agent（如 Cursor、Claude Code 等）。
class AgentTarget {
  const AgentTarget({
    required this.id,
    required this.displayName,
    required this.icon,
    this.enabled = true,
    this.isDefault = false,
  });

  final String id;
  final String displayName;
  final String icon;

  /// Agent 是否启用
  final bool enabled;

  /// 是否为默认 Agent；同一时刻只能有一个 Agent 为默认
  final bool isDefault;

  AgentTarget copyWith({
    String? id,
    String? displayName,
    String? icon,
    bool? enabled,
    bool? isDefault,
  }) {
    return AgentTarget(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      icon: icon ?? this.icon,
      enabled: enabled ?? this.enabled,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
