import 'package:flutter/material.dart';

import 'models/agent_target.dart';
import 'pages/agent_management_page.dart';
import 'pages/skill_management_page.dart';
import 'pages/skill_store_page.dart';
import 'services/agent_service.dart';
import 'widgets/app_scaffold_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SkillLakeApp());
}

class SkillLakeApp extends StatelessWidget {
  const SkillLakeApp({super.key});

  /// 构建通用主题的辅助方法，浅色/深色共享相同的结构定义。
  ///
  /// [brightness] 决定生成浅色还是深色主题。
  /// 所有颜色均由 Material 3 的 ColorScheme.fromSeed 推导，
  /// 不硬编码任何色值，确保跟随系统外观自适应。
  static ThemeData _buildTheme(Brightness brightness) {
    // macOS 原生系统蓝色 (Apple System Blue)
    const Color seedColor = Color(0xFF007AFF);
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          // 使用 ColorScheme 语义化边框色，自动适配深浅模式
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skill Lake',
      debugShowCheckedModeBanner: false,
      // 浅色主题
      theme: _buildTheme(Brightness.light),
      // 深色主题
      darkTheme: _buildTheme(Brightness.dark),
      // 跟随系统浅色/深色模式自动切换
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AgentService _agentService = AgentService();

  /// 当前选中的底部导航菜单索引
  int _selectedMenu = 0;

  /// 当前在 Skill 管理/商店页面中选中的 Agent 索引（基于已启用列表）
  int _selectedAgent = 0;

  /// 所有 Agent 列表（含禁用的）
  List<AgentTarget> _agents = const <AgentTarget>[];

  bool _loadingAgents = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  /// 从持久化存储加载 Agent 列表
  Future<void> _loadAgents() async {
    final List<AgentTarget> loaded = await _agentService.loadAgents();
    if (!mounted) {
      return;
    }
    setState(() {
      _agents = loaded;
      _loadingAgents = false;
      if (_selectedAgent >= loaded.length) {
        _selectedAgent = 0;
      }
    });
  }

  /// 从 _agents 提取当前默认 Agent（isDefault == true）
  AgentTarget? get _defaultAgent {
    try {
      return _agents.firstWhere((AgentTarget a) => a.isDefault);
    } catch (_) {
      return _agents.isEmpty ? null : _agents.first;
    }
  }

  /// 处理 Agent 管理页切换默认 Agent 的回调
  Future<void> _onDefaultAgentChanged(String agentId) async {
    final List<AgentTarget> updated =
        _agentService.setDefaultAgent(_agents, agentId);
    await _agentService.saveAgents(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _agents = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAgents) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 仅展示已启用的 Agent
    final List<AgentTarget> enabledAgents =
        _agents.where((AgentTarget item) => item.enabled).toList();
    final int safeSelectedAgent = enabledAgents.isEmpty
        ? 0
        : (_selectedAgent < enabledAgents.length ? _selectedAgent : 0);

    final Widget content;
    if (enabledAgents.isEmpty && _selectedMenu != 1) {
      content = const Center(
        child: Text('没有启用中的 Agent，请在「Agent 管理」中至少开启一个。'),
      );
    } else {
      content = switch (_selectedMenu) {
        // Skill 管理页：透传 defaultAgent 用于显示同步按钮
        0 => SkillManagementPage(
            selectedAgent: enabledAgents[safeSelectedAgent],
            agents: enabledAgents,
            selectedAgentIndex: safeSelectedAgent,
            onAgentChanged: (int index) =>
                setState(() => _selectedAgent = index),
            defaultAgent: _defaultAgent,
          ),
        // Agent 管理页：透传 onDefaultAgentChanged 回调
        1 => AgentManagementPage(
            agents: _agents,
            onAgentsChanged: (List<AgentTarget> updated) async {
              await _agentService.saveAgents(updated);
              if (!mounted) {
                return;
              }
              setState(() {
                _agents = updated;
                final List<AgentTarget> enabled = updated
                    .where((AgentTarget item) => item.enabled)
                    .toList();
                if (enabled.isEmpty) {
                  _selectedAgent = 0;
                  _selectedMenu = 1;
                } else if (_selectedAgent >= enabled.length) {
                  _selectedAgent = 0;
                }
              });
            },
            onDefaultAgentChanged: _onDefaultAgentChanged,
          ),
        // Skill 商店页：透传 defaultAgent，安装目标优先使用默认 Agent
        _ => SkillStorePage(
            selectedAgent: enabledAgents.isEmpty
                ? _agents.first
                : enabledAgents[safeSelectedAgent],
            defaultAgent: _defaultAgent,
          ),
      };
    }

    return AppScaffoldShell(
      selectedMenu: _selectedMenu,
      onMenuChanged: (int index) => setState(() => _selectedMenu = index),
      content: content,
    );
  }
}
