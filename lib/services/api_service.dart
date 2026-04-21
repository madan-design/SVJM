import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/quote_model.dart';

class ApiService {

  // CHANGE THIS TO YOUR COMPUTER IP
  static const String baseUrl = "http://192.168.1.5:5000";

  static Future<Uint8List?> generateQuote(QuoteModel quote) async {

    try {

      final url = Uri.parse("$baseUrl/generate-quote");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(quote.toJson()),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      print("Server error: ${response.statusCode}");
      return null;

    } catch (e) {

      print("API ERROR: $e");
      return null;

    }
  }
}