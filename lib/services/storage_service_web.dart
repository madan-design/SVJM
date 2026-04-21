// Web stub — IoHelper is never called on web (kIsWeb guards in StorageService)
// but must exist for conditional import to compile.

class IoHelper {
  static Future<void> ensureDir(String path) async {}
  static Future<void> writeBytes(String path, List<int> bytes) async {}
  static Future<void> writeString(String path, String content) async {}
  static Future<String?> readString(String path) async => null;
  static Future<List<int>> readBytes(String path) async => [];
  static Future<bool> exists(String path) async => false;
  static Future<void> deleteIfExists(String path) async {}
  static Future<List<String>> listJson(String dirPath) async => [];
}
