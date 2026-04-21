import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String geminiApiKey = 'AIzaSyBk_EM0Di902738hgTl_Tuz9Fv5rTawiaI';

  static String get supabaseUrl => dotenv.env['SUPABASE_URL']?.trim() ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
}
