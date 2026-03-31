import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'app_shell.dart';

class AppRoutePaths {
  const AppRoutePaths._();

  static const String home = '/';
  static const String chat = '/chat';
  static const String profile = '/profile';
}

// ⚠️ DO NOT MODIFY: Core architecture logic
// The router owns the tab shell so navigation stays persistent while each
// feature screen remains isolated and mock-data driven.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutePaths.home,
  routes: <RouteBase>[
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
