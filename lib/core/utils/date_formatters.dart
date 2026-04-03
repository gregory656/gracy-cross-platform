import 'package:intl/intl.dart';

class DateFormatters {
  DateFormatters._();

  static final DateFormat timeOnly = DateFormat('HH:mm');
  static final DateFormat shortDate = DateFormat('MMM d, yyyy');
  static final DateFormat chatPreviewTime = DateFormat('h:mm a');
}
