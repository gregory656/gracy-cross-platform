import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'shared/providers/account_switcher_provider.dart';
import 'shared/providers/theme_provider.dart';

class GracyApp extends ConsumerWidget {
  const GracyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeName = ref.watch(themeProvider);
    final AccountSwitcherState switcherState = ref.watch(
      accountSwitcherControllerProvider,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Gracy',
      theme: AppTheme.resolveTheme(themeName),
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            child ?? const SizedBox.shrink(),
            if (switcherState.isSwitching)
              Container(
                color: AppColors.onyx.withValues(alpha: 0.96),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      switcherState.statusMessage ?? 'Switching account...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
