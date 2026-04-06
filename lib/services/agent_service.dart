import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/agent_target.dart';

class AgentService {
  static const String _fileName = 'agents.json';

  Future<List<AgentTarget>> loadAgents() async {
    final File file = await _getStorageFile();
    if (!await file.exists()) {
      return _defaultAgents;
    }

    final String raw = await file.readAsString();
    final List<dynamic> data = json.decode(raw) as List<dynamic>;
    return data.map((dynamic e) {
      final Map<String, dynamic> item = e as Map<String, dynamic>;
      return AgentTarget(
        id: item['id'] as String,
        displayName: item['displayName'] as String,
        icon: item['icon'] as String? ?? 'robot_2',
        enabled: item['enabled'] as bool? ?? true,
      );
    }).toList();
  }

  Future<void> saveAgents(List<AgentTarget> agents) async {
    final File file = await _getStorageFile();
    await file.writeAsString(
      json.encode(
        agents
            .map((e) => {
                  'id': e.id,
                  'displayName': e.displayName,
                  'icon': e.icon,
                  'enabled': e.enabled,
                })
            .toList(),
      ),
    );
  }

  Future<File> _getStorageFile() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory appDir = Directory('${supportDir.path}/skill_lake');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File('${appDir.path}/$_fileName');
  }

  List<AgentTarget> get _defaultAgents => const [
        AgentTarget(id: 'cursor', displayName: 'Cursor', icon: 'cursor'),
        AgentTarget(id: 'claude_code', displayName: 'Claude Code', icon: 'bolt'),
        AgentTarget(id: 'codex', displayName: 'Codex', icon: 'terminal'),
        AgentTarget(id: 'trae', displayName: 'Trae', icon: 'sparkles'),
      ];
}
