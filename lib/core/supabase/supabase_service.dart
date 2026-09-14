import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  const SupabaseService._();

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get _key =>
      _publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey;

  static bool get isConfigured => _url.isNotEmpty && _key.isNotEmpty;

  static SupabaseClient? get client {
    if (!isConfigured) {
      return null;
    }
    return Supabase.instance.client;
  }

  static Future<void> initializeFromEnvironment() async {
    if (!isConfigured) {
      return;
    }

    await Supabase.initialize(url: _url, publishableKey: _key);
  }
}
