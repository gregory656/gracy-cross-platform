import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'GRACY',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'A private academic network for students and alumni.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

