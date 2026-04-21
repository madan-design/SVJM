// Web-specific implementation
import 'dart:typed_data';
import 'dart:html' as html;

void openBlobInNewTab(Uint8List bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrl(blob);
  html.window.open(url, '_blank');
  
  // Clean up after a delay
  Future.delayed(const Duration(minutes: 5), () {
    html.Url.revokeObjectUrl(url);
  });
}

void downloadBlob(Uint8List bytes, String mimeType, String fileName) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrl(blob);
  
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  
  html.Url.revokeObjectUrl(url);
}

String createBlobUrl(Uint8List bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrl(blob);
}

void revokeBlobUrl(String url) {
  html.Url.revokeObjectUrl(url);
}