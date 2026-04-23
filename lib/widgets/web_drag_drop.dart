// Web-specific drag and drop implementation
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class WebDragDropHandler {
  static Future<List<PlatformFile>> handleDroppedFiles(
    List<dynamic> files,
    List<String> allowedExtensions,
  ) async {
    final platformFiles = <PlatformFile>[];
    
    for (final file in files) {
      // Check file extension
      final ext = (file as dynamic).name.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        continue;
      }
      
      // Read file as bytes
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      
      reader.onLoad.listen((event) {
        final bytes = reader.result as List<int>;
        completer.complete(Uint8List.fromList(bytes));
      });
      
      reader.onError.listen((event) {
        completer.completeError('Failed to read file');
      });
      
      reader.readAsArrayBuffer(file);
      
      try {
        final uint8List = await completer.future;
        platformFiles.add(PlatformFile(
          name: (file as dynamic).name,
          size: (file as dynamic).size,
          bytes: uint8List,
        ));
      } catch (e) {
        // Skip failed files
        continue;
      }
    }
    
    return platformFiles;
  }
  
  static void setupDragListeners(
    VoidCallback onDragEnter,
    VoidCallback onDragLeave,
    Function(List<dynamic>) onFilesDropped,
  ) {
    html.document.addEventListener('dragover', (event) {
      event.preventDefault();
    });
    
    html.document.addEventListener('dragenter', (event) {
      event.preventDefault();
      onDragEnter();
    });
    
    html.document.addEventListener('dragleave', (event) {
      event.preventDefault();
      onDragLeave();
    });
    
    html.document.addEventListener('drop', (event) {
      event.preventDefault();
      onDragLeave();
      
      final dragEvent = event;
      final dataTransfer = (dragEvent as dynamic).dataTransfer;
      final files = dataTransfer?.files;
      
      if (files != null && files.isNotEmpty) {
        final fileList = <html.File>[];
        for (int i = 0; i < files.length; i++) {
          final file = files.item(i);
          if (file != null) {
            fileList.add(file);
          }
        }
        onFilesDropped(fileList.cast<dynamic>());
      }
    });
  }
  
  static void removeDragListeners() {
    // Note: In a real implementation, you'd store references to the listeners
    // and remove them properly. For simplicity, we'll rely on page navigation
    // to clean up listeners.
  }
}