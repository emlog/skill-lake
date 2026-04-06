class AgentTarget {
  const AgentTarget({
    required this.id,
    required this.displayName,
    required this.icon,
    this.enabled = true,
  });

  final String id;
  final String displayName;
  final String icon;
  final bool enabled;

  AgentTarget copyWith({
    String? id,
    String? displayName,
    String? icon,
    bool? enabled,
  }) {
    return AgentTarget(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      icon: icon ?? this.icon,
      enabled: enabled ?? this.enabled,
    );
  }
}
