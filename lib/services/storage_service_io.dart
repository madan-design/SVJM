import 'dart:io';

class IoHelper {
  static Future<void> ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  static Future<void> writeBytes(String path, List<int> bytes) async {
    await File(path).writeAsBytes(bytes);
  }

  static Future<void> writeString(String path, String content) async {
    await File(path).writeAsString(content);
  }

  static Future<String?> readString(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  static Future<List<int>> readBytes(String path) async {
    return File(path).readAsBytes();
  }

  static Future<bool> exists(String path) async {
    return File(path).exists();
  }

  static Future<void> deleteIfExists(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<List<String>> listJson(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    return dir
        .listSync()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.path)
        .toList();
  }
}
