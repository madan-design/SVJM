// Stub implementation for non-web platforms
import 'dart:typed_data';

void openBlobInNewTab(Uint8List bytes, String mimeType) {
  throw UnsupportedError('Web-only functionality');
}

void downloadBlob(Uint8List bytes, String mimeType, String fileName) {
  throw UnsupportedError('Web-only functionality');
}

String createBlobUrl(Uint8List bytes, String mimeType) {
  throw UnsupportedError('Web-only functionality');
}

void revokeBlobUrl(String url) {
  throw UnsupportedError('Web-only functionality');
}