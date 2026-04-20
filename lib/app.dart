import 'dart:async';

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
            _GlobalTopActions(router: router),
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

class _GlobalTopActions extends StatefulWidget {
  const _GlobalTopActions({required this.router});

  final GoRouter router;

  @override
  State<_GlobalTopActions> createState() => _GlobalTopActionsState();
}

class _GlobalTopActionsState extends State<_GlobalTopActions> {
  Timer? _hideTimer;
  bool _isVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibilityForRoute();
  }

  @override
  void didUpdateWidget(covariant _GlobalTopActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router.routeInformationProvider.value.uri.path !=
        widget.router.routeInformationProvider.value.uri.path) {
      _syncVisibilityForRoute();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _syncVisibilityForRoute() {
    final bool shouldAutoHide = _currentPath() == AppRoutePaths.home;
    _hideTimer?.cancel();
    if (!shouldAutoHide) {
      if (!_isVisible) {
        setState(() {
          _isVisible = true;
        });
      }
      return;
    }
    _scheduleHide();
  }

  void _ensureRouteVisibility(String currentPath) {
    final bool shouldAutoHide = currentPath == AppRoutePaths.home;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!shouldAutoHide) {
        _hideTimer?.cancel();
        if (!_isVisible) {
          setState(() {
            _isVisible = true;
          });
        }
        return;
      }
      if (_hideTimer == null || !_hideTimer!.isActive) {
        _scheduleHide();
      }
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _currentPath() != AppRoutePaths.home) {
        return;
      }
      setState(() {
        _isVisible = false;
      });
    });
  }

  void _revealTemporarily() {
    final bool shouldAutoHide = _currentPath() == AppRoutePaths.home;
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });
    }
    if (shouldAutoHide) {
      _scheduleHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.of(context).padding;
    final String currentPath = _currentPath();
    final bool isHome = currentPath == AppRoutePaths.home;
    _ensureRouteVisibility(currentPath);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _revealTemporarily(),
          ),
        ),
        Positioned(
          top: padding.top + 10,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: _isVisible ? Offset.zero : const Offset(0, -1.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_isVisible,
                  child: Row(
                    children: <Widget>[
                      _TopActionButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: (widget.router.canPop() || !isHome)
                            ? () {
                                _revealTemporarily();
                                if (widget.router.canPop()) {
                                  widget.router.pop();
                                } else {
                                  widget.router.go(AppRoutePaths.home);
                                }
                              }
                            : null,
                      ),
                      const Spacer(),
                      _TopActionButton(
                        icon: Icons.close_rounded,
                        onTap: isHome
                            ? null
                            : () {
                                _revealTemporarily();
                                widget.router.go(AppRoutePaths.home);
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _currentPath() => widget.router.routeInformationProvider.value.uri.path;
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC0B0D10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: onTap == null ? 0.06 : 0.14),
            ),
          ),
          child: Icon(
            icon,
            color: onTap == null ? Colors.white38 : Colors.white,
          ),
        ),
      ),
    );
  }
}
