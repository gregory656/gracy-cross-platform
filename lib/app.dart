import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/chat/providers/chat_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'shared/providers/account_switcher_provider.dart';
import 'shared/providers/offline_banner_provider.dart';
import 'shared/providers/theme_provider.dart';

class GracyApp extends ConsumerWidget {
  const GracyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeName = ref.watch(themeProvider);
    final String? offlineBanner = ref.watch(offlineBannerProvider);
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
            const _GlobalRealtimeListeners(),
            if (offlineBanner != null && !_isChatRoute(router))
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: _OfflineBanner(message: offlineBanner),
                ),
              ),
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

  bool _isChatRoute(GoRouter router) =>
      router.routeInformationProvider.value.uri.path.startsWith(
        AppRoutePaths.chat,
      );
}

class _GlobalRealtimeListeners extends ConsumerWidget {
  const _GlobalRealtimeListeners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(recentChatsProvider);
    return const SizedBox.shrink();
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1722),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2B8DFF).withValues(alpha: 0.45)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: <Widget>[
              const Icon(Icons.cloud_off_rounded, color: Color(0xFF33B5FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
