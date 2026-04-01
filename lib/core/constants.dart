import 'constants_local.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static String get supabaseUrl => SupabaseLocalConfig.supabaseUrl;

  static String get supabaseAnonKey => SupabaseLocalConfig.supabaseAnonKey;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
