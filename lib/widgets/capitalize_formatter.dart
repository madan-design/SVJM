import 'package:flutter/services.dart';

class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Only capitalize if user is adding text (not deleting)
    if (newValue.text.length > oldValue.text.length) {
      // Check if first character is lowercase
      if (newValue.text[0] == newValue.text[0].toLowerCase() &&
          newValue.text[0] != newValue.text[0].toUpperCase()) {
        
        final capitalizedText = newValue.text[0].toUpperCase() + 
                                newValue.text.substring(1);
        
        return TextEditingValue(
          text: capitalizedText,
          selection: newValue.selection,
        );
      }
    }

    return newValue;
  }
}
