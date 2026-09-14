import '../core/supabase/supabase_service.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    await SupabaseService.initializeFromEnvironment();
  }
}
