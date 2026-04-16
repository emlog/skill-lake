import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 全局设置服务，负责持久化一些如 API Key 之类的配置。
class SettingsService {
  static const String _fileName = 'settings.json';

  Future<File> _getStorageFile() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory appDir = Directory('${supportDir.path}/skill_lake');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File('${appDir.path}/$_fileName');
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final File file = await _getStorageFile();
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveSettings(Map<String, dynamic> settings) async {
    final File file = await _getStorageFile();
    await file.writeAsString(json.encode(settings));
  }

  /// 获取保存的 skillsmp API Key
  Future<String> getSkillsmpApiKey() async {
    final Map<String, dynamic> settings = await _loadSettings();
    return settings['skillsmpApiKey'] as String? ?? '';
  }

  /// 保存 skillsmp API Key
  Future<void> saveSkillsmpApiKey(String apiKey) async {
    final Map<String, dynamic> settings = await _loadSettings();
    settings['skillsmpApiKey'] = apiKey;
    await _saveSettings(settings);
  }
}
