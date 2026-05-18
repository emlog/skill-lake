// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Skill Lake';

  @override
  String get menuSkill => 'Skill';

  @override
  String get menuAgent => 'Agent';

  @override
  String get menuStore => 'Store';

  @override
  String get about => 'About';

  @override
  String get author => 'Author';

  @override
  String get homepage => 'Homepage';

  @override
  String get noEnabledAgentHint =>
      'No enabled agent, please enable at least one in 「Agent Management」.';

  @override
  String get addCustomAgent => 'Add Custom Agent';

  @override
  String get editCustomAgent => 'Edit Custom Agent';

  @override
  String get deleteCustomAgent => 'Delete Custom Agent';

  @override
  String get agentName => 'Agent Name';

  @override
  String get skillsDirectory => 'Skills Directory';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get defaultLabel => 'Default';

  @override
  String get edit => 'Edit';

  @override
  String get setDefaultAgent => 'Set as Default Agent';

  @override
  String get currentDefaultAgent => 'Current Default Agent';

  @override
  String get syncFromDefault => 'Sync from Default';

  @override
  String get syncAllTo => 'Sync All to...';

  @override
  String get syncSelected => 'Sync Selected';

  @override
  String get syncTo => 'Sync to...';

  @override
  String get selectTargetAgent => 'Select target Agent to sync to';

  @override
  String get openFolder => 'Open Folder';

  @override
  String get selectSkill => 'Select Skill';

  @override
  String get uploadInstall => 'Upload Install (.zip)';

  @override
  String get refresh => 'Refresh';

  @override
  String get noInstalledSkill => 'No installed skills';

  @override
  String totalCount(int count) {
    return 'Total $count';
  }

  @override
  String get deleteAll => 'Delete All';

  @override
  String get confirmDeleteAll => 'Confirm Delete All';

  @override
  String get confirmDeleteAllContent =>
      'Are you sure you want to delete all Skills for this Agent?\nThis action cannot be undone.';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String confirmDeleteContent(String name) {
    return 'Are you sure you want to delete $name?\nThis action cannot be undone.';
  }

  @override
  String get view => 'View';

  @override
  String get description => 'Description';

  @override
  String get path => 'Path';

  @override
  String get language => 'Language';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String networkError(String error) {
    return 'Network request failed: $error';
  }

  @override
  String get noMatchSkill => 'No matching skills found';

  @override
  String get installing => 'Installing...';

  @override
  String get install => 'Install';

  @override
  String get refreshCache => 'Refresh Cache';

  @override
  String get search => 'Search';

  @override
  String updateAvailable(String version) {
    return 'Update ($version)';
  }

  @override
  String get updating => 'Updating...';

  @override
  String updateSuccess(String name) {
    return 'Updated $name to the latest version';
  }

  @override
  String get searchHint => 'Search skills, press ↵ to search';

  @override
  String get skillsmpSettings => 'Skillsmp Settings';

  @override
  String get apiKeyHint =>
      'Setting your own API Key can get more search quota.';

  @override
  String get getApiKey => 'Get API Key: ';

  @override
  String get loadMore => 'Load More';

  @override
  String get visitHomepage => 'Visit';

  @override
  String get sourceDescSkillsmp =>
      'skillsmp is an AI skill search engine for discovering Codex/Trae Agent skills from developers worldwide. Search and find the perfect skills for your workflow.';

  @override
  String get sourceDescAnthropicSkills =>
      'Anthropic\'s official Claude Code Skills collection, featuring PDF, Excel, PowerPoint, and many practical skills for everyday development tasks.';

  @override
  String get sourceDescObraSuperpowers =>
      'obra\'s Superpowers skill collection, offering a rich set of development helper skills to supercharge your coding experience.';

  @override
  String get skillsShDescription =>
      'skills.sh is a community platform for discovering and sharing AI agent skills. Browse hot skills, explore categories, and find the perfect skills for your workflow.';

  @override
  String get skillsShVisit => 'Visit skills.sh';
}
