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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skill Lake',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7BC67B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4FBF4),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE1EEE1)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7FCF7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4E5D4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4E5D4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7BC67B), width: 1.4),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
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
  int _selectedMenu = 0;
  int _selectedAgent = 0;
  List<AgentTarget> _agents = const <AgentTarget>[];
  bool _loadingAgents = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

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

  @override
  Widget build(BuildContext context) {
    if (_loadingAgents) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
        0 => SkillManagementPage(
            selectedAgent: enabledAgents[safeSelectedAgent],
            agents: enabledAgents,
            selectedAgentIndex: safeSelectedAgent,
            onAgentChanged: (int index) =>
                setState(() => _selectedAgent = index),
          ),
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
          ),
        _ => SkillStorePage(
            selectedAgent: enabledAgents[safeSelectedAgent],
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
