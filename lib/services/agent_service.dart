import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/agent_target.dart';

/// Agent 持久化服务，负责本地文件的读写以及默认 Agent 的管理。
class AgentService {
  static const String _fileName = 'agents.json';

  /// 从本地文件加载 Agent 列表；若文件不存在则返回内置默认列表。
  Future<List<AgentTarget>> loadAgents() async {
    final File file = await _getStorageFile();
    if (!await file.exists()) {
      return _defaultAgents;
    }

    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return _defaultAgents;
    }

    final List<dynamic> data = json.decode(raw) as List<dynamic>;
    final List<AgentTarget> agents = data.map((dynamic e) {
      final Map<String, dynamic> item = e as Map<String, dynamic>;
      return AgentTarget(
        id: item['id'] as String,
        displayName: item['displayName'] as String,
        icon: item['icon'] as String? ?? 'robot_2',
        enabled: item['enabled'] as bool? ?? true,
        isDefault: item['isDefault'] as bool? ?? false,
        homepageUrl: item['homepageUrl'] as String?,
        skillsDirectory: item['skillsDirectory'] as String?,
      );
    }).toList();

    // 若没有任何默认 Agent，则将第一个启用的 Agent 设为默认
    final bool hasDefault = agents.any((AgentTarget a) => a.isDefault);
    if (!hasDefault && agents.isNotEmpty) {
      final int firstEnabled = agents.indexWhere((AgentTarget a) => a.enabled);
      final int target = firstEnabled >= 0 ? firstEnabled : 0;
      agents[target] = agents[target].copyWith(isDefault: true);
    }

    // 将内置列表中新增的 Agent 追加到末尾（解决版本升级后新 Agent 不出现的问题）
    final Set<String> existingIds = agents.map((AgentTarget a) => a.id).toSet();
    for (final AgentTarget builtIn in _defaultAgents) {
      if (!existingIds.contains(builtIn.id)) {
        // 新增的 Agent 不设为默认，用户可手动切换
        agents.add(builtIn.copyWith(isDefault: false));
      } else {
        // 补充可能因旧版本缓存导致缺失的属性（如：主页和技能目录）
        final int index =
            agents.indexWhere((AgentTarget a) => a.id == builtIn.id);
        if (index != -1) {
          final AgentTarget existing = agents[index];
          agents[index] = existing.copyWith(
            displayName: builtIn.displayName,
            icon: builtIn.icon,
            homepageUrl: existing.homepageUrl ?? builtIn.homepageUrl,
            skillsDirectory:
                existing.skillsDirectory ?? builtIn.skillsDirectory,
          );
        }
      }
    }

    return agents;
  }

  /// 将 Agent 列表持久化到本地文件。
  Future<void> saveAgents(List<AgentTarget> agents) async {
    final File file = await _getStorageFile();
    await file.writeAsString(
      json.encode(
        agents
            .map((AgentTarget e) => <String, dynamic>{
                  'id': e.id,
                  'displayName': e.displayName,
                  'icon': e.icon,
                  'enabled': e.enabled,
                  'isDefault': e.isDefault,
                  'homepageUrl': e.homepageUrl,
                  'skillsDirectory': e.skillsDirectory,
                })
            .toList(),
      ),
    );
  }

  /// 将指定 [agentId] 设置为默认 Agent，同时清除其他 Agent 的默认标记。
  /// 返回更新后的列表。
  List<AgentTarget> setDefaultAgent(
    List<AgentTarget> agents,
    String agentId,
  ) {
    return agents.map((AgentTarget a) {
      return a.copyWith(isDefault: a.id == agentId);
    }).toList();
  }

  Future<File> _getStorageFile() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory appDir = Directory('${supportDir.path}/skill_lake');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File('${appDir.path}/$_fileName');
  }

  /// 内置默认 Agent 列表，首个 Agent（Cursor）默认设为默认 Agent。
  List<AgentTarget> get _defaultAgents => const <AgentTarget>[
        AgentTarget(
          id: 'cursor',
          displayName: 'Cursor',
          icon: 'cursor',
          isDefault: true,
          homepageUrl: 'https://cursor.com/',
          skillsDirectory: '~/.cursor/skills/',
        ),
        AgentTarget(
          id: 'claude_code',
          displayName: 'Claude Code',
          icon: 'bolt',
          homepageUrl: 'https://claude.com/product/claude-code',
          skillsDirectory: '~/.claude/skills/',
        ),
        AgentTarget(
          id: 'codex',
          displayName: 'Codex',
          icon: 'terminal',
          homepageUrl: 'https://openai.com/codex',
          skillsDirectory: '~/.codex/skills/',
        ),
        AgentTarget(
          id: 'trae',
          displayName: 'Trae',
          icon: 'sparkles',
          homepageUrl: 'https://www.trae.ai/',
          skillsDirectory: '~/.trae/skills/',
        ),
        AgentTarget(
          id: 'gemini_cli',
          displayName: 'Gemini CLI',
          icon: 'terminal',
          homepageUrl: 'https://geminicli.com/',
          skillsDirectory: '~/.gemini/skills/',
        ),
        AgentTarget(
          id: 'antigravity',
          displayName: 'Antigravity',
          icon: 'gravity',
          homepageUrl: 'https://antigravity.google/',
          skillsDirectory: '~/.gemini/antigravity/skills/',
        ),
        AgentTarget(
          id: 'github_copilot',
          displayName: 'GitHub Copilot',
          icon: 'github',
          homepageUrl: 'https://github.com/features/copilot',
          skillsDirectory: '~/.copilot/skills/',
        ),
        AgentTarget(
          id: 'general',
          displayName: 'General Agent',
          icon: 'robot_2',
          isDefault: false,
          skillsDirectory: '~/.agents/skills/',
        ),
      ];
}
