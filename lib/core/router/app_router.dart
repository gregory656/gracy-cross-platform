import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/auth_splash_screen.dart';
import '../../features/home/presentation/post_detail_screen.dart';
import '../../features/onboarding/presentation/landing_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../shared/providers/auth_provider.dart';
import 'app_shell.dart';

class AppRoutePaths {
  const AppRoutePaths._();

  static const String welcome = '/welcome';
  static const String splash = '/launch';
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String postDetailPattern = '/post/:id';

  static String postDetail(String postId) => '/post/$postId';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  AuthState readAuthState() => ref.read(authNotifierProvider);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutePaths.splash,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState authState = readAuthState();
      final bool isSplashRoute = state.matchedLocation == AppRoutePaths.splash;
      final bool isWelcomeRoute =
          state.matchedLocation == AppRoutePaths.welcome;
      final bool isOnboardingRoute =
          state.matchedLocation == AppRoutePaths.onboarding;
      final bool isSharedPostRoute =
          state.uri.pathSegments.isNotEmpty &&
          state.uri.pathSegments.first == 'post';

      final bool authenticated = authState.isAuthenticated;
      final bool completed = authState.isOnboardingComplete;

      if (isSharedPostRoute) {
        return null;
      }

      if (authState.isBootstrapping) {
        return isSplashRoute ? null : AppRoutePaths.splash;
      }

      if (isSplashRoute) {
        if (!authenticated) {
          return AppRoutePaths.welcome;
        }
        return completed ? AppRoutePaths.home : AppRoutePaths.onboarding;
      }

      // 1. Not Auth at all -> Must go to Welcome
      if (!authenticated && !isWelcomeRoute) {
        return AppRoutePaths.welcome;
      }

      // 2. Auth but profile missing -> Must go to Onboarding
      if (authenticated && !completed && !isOnboardingRoute) {
        return AppRoutePaths.onboarding;
      }

      // 3. Auth && Profile Complete -> Should skip onboarding/welcome
      if (authenticated && completed && (isWelcomeRoute || isOnboardingRoute)) {
        return AppRoutePaths.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutePaths.splash,
        builder: (BuildContext context, GoRouterState state) {
          return const AuthSplashScreen();
        },
      ),
      GoRoute(
        path: AppRoutePaths.welcome,
        builder: (BuildContext context, GoRouterState state) {
          return const LandingScreen();
        },
      ),
      GoRoute(
        path: AppRoutePaths.onboarding,
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingScreen();
        },
      ),
      GoRoute(
        path: AppRoutePaths.postDetailPattern,
        builder: (BuildContext context, GoRouterState state) {
          final String postId = state.pathParameters['id'] ?? '';
          return PostDetailScreen(postId: postId);
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
              return ProfileScreen(userId: state.uri.queryParameters['userId']);
            },
          ),
          GoRoute(
            path: AppRoutePaths.settings,
            builder: (BuildContext context, GoRouterState state) {
              return const SettingsScreen();
            },
          ),
        ],
      ),
    ],
  );

  ref.listen<AuthState>(authNotifierProvider, (
    AuthState? previous,
    AuthState next,
  ) {
    router.refresh();
  });

  return router;
});
