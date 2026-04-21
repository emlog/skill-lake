// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Skill Lake';

  @override
  String get menuSkill => 'Skill';

  @override
  String get menuAgent => 'Agent';

  @override
  String get menuStore => 'Store';

  @override
  String get about => '关于';

  @override
  String get author => '作者';

  @override
  String get homepage => '主页';

  @override
  String get noEnabledAgentHint => '没有启用中的 Agent，请在「Agent 管理」中至少开启一个。';

  @override
  String get addCustomAgent => '添加自定义 Agent';

  @override
  String get editCustomAgent => '编辑自定义 Agent';

  @override
  String get deleteCustomAgent => '删除自定义 Agent';

  @override
  String get agentName => 'Agent 名称';

  @override
  String get skillsDirectory => 'Skill 目录';

  @override
  String get cancel => '取消';

  @override
  String get add => '添加';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get close => '关闭';

  @override
  String get defaultLabel => '默认';

  @override
  String get edit => '编辑';

  @override
  String get setDefaultAgent => '设为默认 Agent';

  @override
  String get currentDefaultAgent => '当前默认 Agent';

  @override
  String get syncFromDefault => '从默认 Agent 同步';

  @override
  String get syncAllTo => '全部同步到...';

  @override
  String get syncTo => '同步到...';

  @override
  String get selectTargetAgent => '选择同步到的目标 Agent';

  @override
  String get uploadInstall => '上传安装';

  @override
  String get refresh => '刷新';

  @override
  String get noInstalledSkill => '暂无已安装 Skill';

  @override
  String totalCount(int count) {
    return '总数 $count';
  }

  @override
  String get deleteAll => '全部删除';

  @override
  String get confirmDeleteAll => '确认全部删除';

  @override
  String get confirmDeleteAllContent => '确定要删除该 Agent 下的所有 Skill 吗？\n此操作将不可恢复。';

  @override
  String get confirmDelete => '确认删除';

  @override
  String confirmDeleteContent(String name) {
    return '确定要删除 $name 吗？\n此操作将不可恢复。';
  }

  @override
  String get view => '查看';

  @override
  String get description => '描述';

  @override
  String get path => '路径';

  @override
  String get language => '语言';

  @override
  String get loading => '正在加载...';

  @override
  String get retry => '重试';

  @override
  String networkError(String error) {
    return '网络请求失败：$error';
  }

  @override
  String get noMatchSkill => '没有找到符合条件的 Skill';

  @override
  String get installing => '安装中...';

  @override
  String get install => '安装';

  @override
  String get refreshCache => '刷新缓存';

  @override
  String get search => '搜索';

  @override
  String get searchHint => '支持语义搜索，例如：最适合前端开发的SKILL';

  @override
  String get skillsmpSettings => 'Skillsmp 设置';

  @override
  String get apiKeyHint => '设置您自己的 API Key 可以获得更多的搜索额度。';

  @override
  String get getApiKey => '获取 API Key：';
}
