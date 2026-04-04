import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    
    return GestureDetector(
      onTap: () => ref.read(themeProvider.notifier).toggleDarkLightMode(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
            width: 1,
          ),
        ),
        child: Icon(
          isDarkMode ? Icons.dark_mode : Icons.light_mode,
          size: 20,
          color: Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }
}
