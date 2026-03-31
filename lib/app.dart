import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class GracyApp extends StatelessWidget {
  const GracyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Gracy',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}

