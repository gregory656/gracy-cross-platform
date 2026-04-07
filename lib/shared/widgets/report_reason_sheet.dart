import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

const List<String> kReportReasons = <String>[
  'Spam / Scams',
  'Harassment',
  'Inappropriate Content',
  'Hate Speech',
];

Future<String?> showReportReasonSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      final EdgeInsets viewPadding = MediaQuery.of(context).viewPadding;

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, viewPadding.bottom + 12),
          child: Material(
            color: const Color(0xFF121212),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF333333)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (int index = 0; index < kReportReasons.length; index++) ...<Widget>[
                  if (index > 0)
                    const Divider(height: 1, color: Color(0xFF333333)),
                  ListTile(
                    leading: const Icon(
                      Icons.outlined_flag_rounded,
                      color: AppColors.warning,
                    ),
                    title: Text(
                      kReportReasons[index],
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Hide this content from your view and send it for review.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    onTap: () =>
                        Navigator.of(context).pop(kReportReasons[index]),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );
}
