// Stub implementation for non-web platforms
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class WebDragDropHandler {
  static Future<List<PlatformFile>> handleDroppedFiles(
    List<dynamic> files,
    List<String> allowedExtensions,
  ) async {
    // Not supported on non-web platforms
    return [];
  }
  
  static void setupDragListeners(
    VoidCallback onDragEnter,
    VoidCallback onDragLeave,
    Function(List<dynamic>) onFilesDropped,
  ) {
    // Not supported on non-web platforms
  }
  
  static void removeDragListeners() {
    // Not supported on non-web platforms
  }
}