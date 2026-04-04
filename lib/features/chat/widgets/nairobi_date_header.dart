import 'package:flutter/material.dart';

import '../../../shared/services/nairobi_timezone_service.dart';
import '../../../core/theme/app_colors.dart';

class NairobiDateHeader extends StatelessWidget {
  const NairobiDateHeader({
    super.key,
    required this.date,
  });

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final timezoneService = NairobiTimezoneService.instance;
    final formattedDate = timezoneService.formatDate(date);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.industrialGray,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.borderGray,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: AppColors.electricBlue,
          ),
          const SizedBox(width: 8),
          Text(
            formattedDate,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timezoneService.timezoneOffset,
            style: const TextStyle(
              color: AppColors.lightGray,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
