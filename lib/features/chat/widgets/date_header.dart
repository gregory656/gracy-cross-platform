import 'package:flutter/material.dart';
import '../../../shared/services/timezone_service.dart';

class DateHeader extends StatelessWidget {
  const DateHeader({
    super.key,
    required this.date,
  });

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade700,
              width: 1,
            ),
          ),
          child: Text(
            TimezoneService.formatDateHeader(date),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade300,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
