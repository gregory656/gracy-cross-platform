import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NairobiTimezoneService {
  static NairobiTimezoneService? _instance;
  static NairobiTimezoneService get instance => _instance ??= NairobiTimezoneService._();
  
  NairobiTimezoneService._();

  late tz.Location _nairobiLocation;
  
  // Getter for nairobi location
  tz.Location get nairobiLocation => _nairobiLocation;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    _nairobiLocation = tz.getLocation('Africa/Nairobi');
  }

  // Convert any DateTime to Nairobi time
  DateTime convertToNairobi(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, _nairobiLocation);
  }

  // Get current Nairobi time
  DateTime get now => tz.TZDateTime.now(_nairobiLocation);

  // Format time for display in Nairobi timezone
  String formatTime(DateTime dateTime) {
    final nairobiTime = convertToNairobi(dateTime);
    final hour = nairobiTime.hour.toString().padLeft(2, '0');
    final minute = nairobiTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Format date for display in Nairobi timezone
  String formatDate(DateTime dateTime) {
    final nairobiTime = convertToNairobi(dateTime);
    final now = this.now;
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(nairobiTime.year, nairobiTime.month, nairobiTime.day);
    
    final difference = today.difference(messageDate).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return _getWeekdayName(nairobiTime.weekday);
    } else {
      return '${nairobiTime.day}/${nairobiTime.month}/${nairobiTime.year}';
    }
  }

  // Format full date and time
  String formatFullDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} at ${formatTime(dateTime)} EAT';
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  // Check if date is same day in Nairobi time
  bool isSameDay(DateTime date1, DateTime date2) {
    final nairobi1 = convertToNairobi(date1);
    final nairobi2 = convertToNairobi(date2);
    return nairobi1.year == nairobi2.year &&
           nairobi1.month == nairobi2.month &&
           nairobi1.day == nairobi2.day;
  }

  // Get Nairobi timezone offset string
  String get timezoneOffset => 'EAT (UTC+3)';
}
