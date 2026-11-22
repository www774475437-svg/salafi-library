/// On the website books are read online only.
class BookFiles {
  static bool get supported => false;
  static Future<bool> has(int id) async => false;
  static Future<void> write(int id, List<int> bytes, String index) async {}
  static Future<String?> index(int id) async => null;
  static Future<List<List<Object>>?> pages(int id) async => null;
  static Future<void> delete(int id) async {}
  static Future<int> size(int id) async => 0;
  static Future<List<Map<String, Object>>> search(int id, String q, int limit) async => const [];
}
