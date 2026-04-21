import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';

class GeminiService {
  static const _url =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  static String _fallbackEmail(Map<String, dynamic> quote) {
    final subject = quote['subject'] ?? '';
    final fileName = quote['fileName'] ?? '';
    return '''Dear Sir/Madam,

Greetings from SVJM Mould & Solutions!

Please find attached our quotation ($fileName) for $subject.

We look forward to your positive response.

For any queries, feel free to contact us.

Warm regards,
SVJM Mould & Solutions''';
  }

  static Future<Map<String, String>> generateEmailContent(
      Map<String, dynamic> quote) async {
    final company = quote['company'] ?? '';
    final subject = quote['subject'] ?? '';
    final fileName = quote['fileName'] ?? '';

    final defaultSubject = 'Quotation for $subject – $fileName';

    final online = await _isOnline();
    developer.log('GeminiService: isOnline=$online', name: 'GeminiService');

    if (!online) {
      developer.log('GeminiService: offline, using fallback', name: 'GeminiService');
      return {'subject': defaultSubject, 'body': _fallbackEmail(quote)};
    }

    final prompt = '''
Write a short professional business email from SVJM Mould & Solutions to $company regarding a quotation.
Quotation file: $fileName
Subject of quotation: $subject
- Keep it under 100 words
- Formal and polite tone
- Mention the attached PDF quotation
- End with "Warm regards, SVJM Mould & Solutions"
- Return only the email body, no subject line
''';

    try {
      developer.log('GeminiService: calling API...', name: 'GeminiService');

      final response = await http.post(
        Uri.parse('$_url?key=${AppConfig.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      developer.log('GeminiService: status=${response.statusCode}', name: 'GeminiService');
      developer.log('GeminiService: body=${response.body}', name: 'GeminiService');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        developer.log('GeminiService: success, got response', name: 'GeminiService');
        return {'subject': defaultSubject, 'body': text.trim()};
      } else {
        developer.log(
          'GeminiService: API error ${response.statusCode}: ${response.body}',
          name: 'GeminiService',
        );
      }
    } catch (e, stack) {
      developer.log('GeminiService: exception: $e', name: 'GeminiService', error: e, stackTrace: stack);
    }

    return {'subject': defaultSubject, 'body': _fallbackEmail(quote)};
  }
}
