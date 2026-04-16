import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants.dart';
import 'shared/services/database_service.dart';
import 'shared/services/local_notification_service.dart';
import 'shared/services/nairobi_timezone_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Nairobi timezone service first
  await NairobiTimezoneService.instance.initialize();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  await DatabaseService.instance.initialize();
  await LocalNotificationService.instance.initialize();

  runApp(const ProviderScope(child: GracyApp()));
}
