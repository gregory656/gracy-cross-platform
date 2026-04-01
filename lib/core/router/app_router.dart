import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/providers/auth_provider.dart';
import 'app_shell.dart';

class AppRoutePaths {
  const AppRoutePaths._();

  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String chat = '/chat';
  static const String profile = '/profile';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  AuthState readAuthState() => ref.read(authNotifierProvider);

  final GoRouter router = GoRouter(
    initialLocation: readAuthState().isOnboardingComplete
        ? AppRoutePaths.home
        : AppRoutePaths.onboarding,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState authState = readAuthState();
      final bool isOnboardingRoute =
          state.matchedLocation == AppRoutePaths.onboarding;
      final bool completed = authState.isOnboardingComplete;

      if (!completed && !isOnboardingRoute) {
        return AppRoutePaths.onboarding;
      }

      if (completed && isOnboardingRoute) {
        return AppRoutePaths.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutePaths.onboarding,
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingScreen();
        },
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return AppShellScaffold(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutePaths.home,
            builder: (BuildContext context, GoRouterState state) {
              return const HomeScreen();
            },
          ),
          GoRoute(
            path: AppRoutePaths.chat,
            builder: (BuildContext context, GoRouterState state) {
              return ChatScreen(
                chatId: state.uri.queryParameters['chatId'],
                userId: state.uri.queryParameters['userId'],
              );
            },
          ),
          GoRoute(
            path: AppRoutePaths.profile,
            builder: (BuildContext context, GoRouterState state) {
              return ProfileScreen(
                userId: state.uri.queryParameters['userId'],
              );
            },
          ),
        ],
      ),
    ],
  );

  ref.listen<AuthState>(authNotifierProvider, (AuthState? previous, AuthState next) {
    router.refresh();
  });

  return router;
});
