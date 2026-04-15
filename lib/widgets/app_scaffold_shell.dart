import 'package:flutter/material.dart';

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
                child: Column(
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
                    const Divider(height: 1),
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: selectedMenu,
                        useIndicator: true,
                        minWidth: 90,
                        minExtendedWidth: 180,
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.transparent,
                        onDestinationSelected: onMenuChanged,
                        destinations: const <NavigationRailDestination>[
                          NavigationRailDestination(
                            icon: Icon(Icons.extension_outlined),
                            selectedIcon: Icon(Icons.extension),
                            label: Text('Skill'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.smart_toy_outlined),
                            selectedIcon: Icon(Icons.smart_toy),
                            label: Text('Agent'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.storefront_outlined),
                            selectedIcon: Icon(Icons.storefront),
                            label: Text('Store'),
                          ),
                        ],
                      ),
                    ),
                  ],
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
}
