import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppScaffoldShell extends StatelessWidget {
  const AppScaffoldShell({
    super.key,
    required this.selectedMenu,
    required this.onMenuChanged,
    required this.content,
  });

  final int selectedMenu;
  final ValueChanged<int> onMenuChanged;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.primaryContainer,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: color.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Skill Lake',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 12),
                            _buildMenuItem(context, index: 0, label: 'Skill', icon: Icons.extension_outlined, selectedIcon: Icons.extension),
                            _buildMenuItem(context, index: 1, label: 'Agent', icon: Icons.smart_toy_outlined, selectedIcon: Icons.smart_toy),
                            _buildMenuItem(context, index: 2, label: 'Store', icon: Icons.storefront_outlined, selectedIcon: Icons.storefront),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 12),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: IconButton(
                          iconSize: 20,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.info_outline,
                            color: color.onSurface.withValues(alpha: 0.4),
                          ),
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  contentPadding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: color.primaryContainer,
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  Icons.auto_awesome,
                                                  color: color.onPrimaryContainer,
                                                  size: 32,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              Text(
                                                'Skill Lake',
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '1.0.0',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
                                              ),
                                              const SizedBox(height: 24),
                                              const Text('作者：snow'),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: <Widget>[
                                                  const Text('主页：'),
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
                                            icon: const Icon(Icons.close),
                                            onPressed: () => Navigator.of(context).pop(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        color.surface,
                        color.surfaceContainerLowest.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => onMenuChanged(index),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 24,
                  color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
