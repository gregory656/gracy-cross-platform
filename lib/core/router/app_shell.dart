import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'app_router.dart';
import 'shell_ui_provider.dart';

class AppShellScaffold extends ConsumerWidget {
  const AppShellScaffold({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final String path = GoRouterState.of(context).uri.path;
    if (path.startsWith(AppRoutePaths.chat)) {
      return 1;
    }
    if (path.startsWith(AppRoutePaths.profile)) {
      return 2;
    }
    if (path.startsWith(AppRoutePaths.settings)) {
      return 3;
    }
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutePaths.home);
        return;
      case 1:
        context.go(AppRoutePaths.chat);
        return;
      case 2:
        context.go(AppRoutePaths.profile);
        return;
      case 3:
        context.go(AppRoutePaths.settings);
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showNavigation = ref.watch(shellNavigationVisibleProvider);
    final shellNavigationController = ref.read(
      shellNavigationVisibleProvider.notifier,
    );

    return Scaffold(
      extendBody: true,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!showNavigation) {
            shellNavigationController.show();
          }
        },
        child: child,
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: showNavigation ? Offset.zero : const Offset(0, 1.15),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: showNavigation ? 1 : 0,
          child: IgnorePointer(
            ignoring: !showNavigation,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: AppColors.background.withValues(alpha: 0.88),
                indicatorColor: AppColors.accentCyan.withValues(alpha: 0.16),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (Set<WidgetState> states) => TextStyle(
                    color: states.contains(WidgetState.selected)
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex(context),
                onDestinationSelected: (int index) {
                  shellNavigationController.show();
                  _onDestinationSelected(context, index);
                },
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_rounded),
                    label: 'Chat',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
