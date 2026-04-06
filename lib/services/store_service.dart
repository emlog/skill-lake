import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/skill.dart';

class StoreService {
  const StoreService();

  Future<List<StoreSkillItem>> fetchStoreSkills() async {
    final List<StoreSkillItem> merged = <StoreSkillItem>[];

    for (final StoreSource source in _sources) {
      try {
        final http.Response response = await http.get(Uri.parse(source.indexUrl));
        if (response.statusCode != 200) {
          continue;
        }
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        for (final dynamic item in data) {
          final Map<String, dynamic> map = item as Map<String, dynamic>;
          merged.add(
            StoreSkillItem(
              skill: Skill.fromMap(map),
              zipUrl: map['zipUrl'] as String? ?? '',
              repository: source.repoName,
            ),
          );
        }
      } catch (_) {
        // Skip unavailable store source.
      }
    }

    return merged;
  }

  List<StoreSource> get _sources => const <StoreSource>[
        StoreSource(
          repoName: 'awesome-ai-agents/skills',
          indexUrl:
              'https://raw.githubusercontent.com/awesome-ai-agents/skills/main/index.json',
        ),
        StoreSource(
          repoName: 'open-agent-hub/skill-market',
          indexUrl:
              'https://raw.githubusercontent.com/open-agent-hub/skill-market/main/index.json',
        ),
      ];
}

class StoreSource {
  const StoreSource({
    required this.repoName,
    required this.indexUrl,
  });

  final String repoName;
  final String indexUrl;
}

class StoreSkillItem {
  const StoreSkillItem({
    required this.skill,
    required this.zipUrl,
    required this.repository,
  });

  final Skill skill;
  final String zipUrl;
  final String repository;
}
