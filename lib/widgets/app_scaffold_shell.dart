import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';

class AppScaffoldShell extends StatelessWidget {
  const AppScaffoldShell({
    super.key,
    required this.selectedMenu,
    required this.onMenuChanged,
    required this.onLocaleChanged,
    required this.content,
  });

  final int selectedMenu;
  final ValueChanged<int> onMenuChanged;
  final ValueChanged<String> onLocaleChanged;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sidebarColor = isDark ? const Color(0xFF202123) : const Color(0xFFF9F9F9);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Row(
        children: <Widget>[
          // 侧边栏整体
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: sidebarColor,
              border: Border(
                right: BorderSide(
                  color: color.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : color.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: isDark ? Colors.black : color.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.appTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildMenuItem(context, index: 0, label: l10n.menuSkill, icon: Icons.extension_outlined, selectedIcon: Icons.extension),
                            _buildMenuItem(context, index: 1, label: l10n.menuAgent, icon: Icons.smart_toy_outlined, selectedIcon: Icons.smart_toy),
                            _buildMenuItem(context, index: 2, label: l10n.menuStore, icon: Icons.storefront_outlined, selectedIcon: Icons.storefront),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 底部 按钮区
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _showAboutDialog(context, color, l10n),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: color.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 语言切换按钮
                        IconButton(
                          onPressed: () => _showLanguageMenu(context),
                          icon: Icon(
                            Icons.language,
                            size: 18,
                            color: color.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          tooltip: l10n.language,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 右侧主内容区
          Expanded(
            child: SafeArea(
              left: false,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    final String currentLocale = Localizations.localeOf(context).languageCode;
    final ColorScheme color = Theme.of(context).colorScheme;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 200,
        offset.dy + button.size.height - 100,
        offset.dx + 260,
        offset.dy + button.size.height - 40,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('English')),
              if (currentLocale == 'en')
                Icon(Icons.check, size: 16, color: color.primary),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'zh',
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('简体中文')),
              if (currentLocale == 'zh')
                Icon(Icons.check, size: 16, color: color.primary),
            ],
          ),
        ),
      ],
    ).then((String? value) {
      if (value != null && value != currentLocale) {
        onLocaleChanged(value);
      }
    });
  }

  void _showAboutDialog(BuildContext context, ColorScheme color, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SizedBox(
            width: 320,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : color.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.black : color.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.appTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1.1.4',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      Text('${l10n.author}：snow'),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text('${l10n.homepage}：'),
                          InkWell(
                            onTap: () async {
                              final Uri url = Uri.parse('https://cacai.cc');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: Text(
                              'cacai.cc',
                              style: TextStyle(
                                color: color.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: color.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final bool isSelected = selectedMenu == index;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    final Color selectedBgColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.1)
        : colorScheme.onSurface.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onMenuChanged(index),
          // hoverColor: isDark ? Colors.white10 : Colors.black12,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? selectedBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 20,
                  color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
