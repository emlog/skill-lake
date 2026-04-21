import 'dart:convert';

class Skill {
  const Skill({
    required this.id,
    required this.agentId,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.source,
    this.installedPath,
    this.tags = const [],
    this.metadata = const {},
  });

  final String id;
  final String agentId;
  final String name;
  final String version;
  final String description;
  final String author;
  final String source;
  final String? installedPath;
  final List<String> tags;
  final Map<String, String> metadata;

  Skill copyWith({
    String? id,
    String? agentId,
    String? name,
    String? version,
    String? description,
    String? author,
    String? source,
    String? installedPath,
    List<String>? tags,
    Map<String, String>? metadata,
  }) {
    return Skill(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      author: author ?? this.author,
      source: source ?? this.source,
      installedPath: installedPath ?? this.installedPath,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'agentId': agentId,
      'name': name,
      'version': version,
      'description': description,
      'author': author,
      'source': source,
      'installedPath': installedPath,
      'tags': tags,
      'metadata': metadata,
    };
  }

  factory Skill.fromMap(Map<String, dynamic> map) {
    return Skill(
      id: map['id'] as String? ?? '',
      agentId: map['agentId'] as String? ?? 'unknown',
      name: map['name'] as String? ?? '',
      version: map['version'] as String? ?? '0.0.1',
      description: map['description'] as String? ?? '',
      author: map['author'] as String? ?? 'unknown',
      source: map['source'] as String? ?? 'local',
      installedPath: map['installedPath'] as String?,
      tags: ((map['tags'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      metadata: Map<String, String>.from(map['metadata'] as Map? ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory Skill.fromJson(String source) =>
      Skill.fromMap(json.decode(source) as Map<String, dynamic>);
}
