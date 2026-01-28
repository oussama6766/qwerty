import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  // استخدام getter لضمان عدم استدعاء الكلاينت قبل التهيئة
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
      debugPrint("✅ ENV Loaded: ${dotenv.get('SUPABASE_URL')}");

      await Supabase.initialize(
        url: dotenv.get('SUPABASE_URL'),
        anonKey: dotenv.get('SUPABASE_ANON_KEY'),
      );
      debugPrint("🚀 Supabase Initialized Successfully!");
    } catch (e) {
      debugPrint("❌ Failed to initialize Supabase: $e");
      rethrow;
    }
  }
}
