import 'package:flutter/services.dart';

// Formats number input as Indian numbering: 7,98,000
class IndianAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow only digits and commas during input
    final digitsOnly = newValue.text.replaceAll(',', '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    // Reject non-digit characters
    if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) return oldValue;

    final formatted = _formatIndian(digitsOnly);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatIndian(String digits) {
    if (digits.length <= 3) return digits;
    // Last 3 digits, then groups of 2
    final last3 = digits.substring(digits.length - 3);
    final rest = digits.substring(0, digits.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i != 0 && (rest.length - i) % 2 == 0) buffer.write(',');
      buffer.write(rest[i]);
    }
    return '${buffer.toString()},$last3';
  }
}

// Normalizes machine input to '150 ton' format
class MachineFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final normalized = _normalize(raw);
    if (normalized == raw) return newValue;
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  static String _normalize(String input) {
    // Extract leading number
    final match = RegExp(r'^(\d+)\s*(ton.*)?$', caseSensitive: false).firstMatch(input.trim());
    if (match == null) return input;

    final number = match.group(1)!;
    final hasTon = match.group(2) != null && match.group(2)!.isNotEmpty;

    // Only append ' ton' when user has typed something after the number
    if (hasTon) return '$number ton';
    return number; // still typing the number, don't append yet
  }
}
