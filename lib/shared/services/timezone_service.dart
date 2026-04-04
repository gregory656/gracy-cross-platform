import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class TimezoneService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
    _initialized = true;
  }

  static DateTime toNairobiTime(DateTime dateTime) {
    if (!_initialized) {
      initialize();
    }
    
    final nairobiTime = tz.TZDateTime.from(dateTime, tz.getLocation('Africa/Nairobi'));
    return nairobiTime;
  }

  static String formatNairobiTime(DateTime dateTime, {bool showDate = false}) {
    final nairobiTime = toNairobiTime(dateTime);
    final now = tz.TZDateTime.now(tz.getLocation('Africa/Nairobi'));
    
    if (showDate) {
      if (nairobiTime.day == now.day && 
          nairobiTime.month == now.month && 
          nairobiTime.year == now.year) {
        return 'Today ${DateFormat.jm().format(nairobiTime)}';
      } else if (nairobiTime.day == now.day - 1 && 
                 nairobiTime.month == now.month && 
                 nairobiTime.year == now.year) {
        return 'Yesterday ${DateFormat.jm().format(nairobiTime)}';
      } else {
        return DateFormat('MMM d, h:mm a').format(nairobiTime);
      }
    } else {
      return DateFormat('h:mm a').format(nairobiTime);
    }
  }

  static String formatDateHeader(DateTime dateTime) {
    final nairobiTime = toNairobiTime(dateTime);
    final now = tz.TZDateTime.now(tz.getLocation('Africa/Nairobi'));
    
    if (nairobiTime.day == now.day && 
        nairobiTime.month == now.month && 
        nairobiTime.year == now.year) {
      return 'Today';
    } else if (nairobiTime.day == now.day - 1 && 
               nairobiTime.month == now.month && 
               nairobiTime.year == now.year) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(nairobiTime);
    }
  }
}
