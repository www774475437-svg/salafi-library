import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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

/// Unpacks a gzip file from the books stores, with the browser's own unpacker.
Future<Uint8List> gunzip(Uint8List bytes) async {
  final ds = web.DecompressionStream('gzip');
  final packed = web.Blob([bytes.toJS].toJS).stream();
  final plain = packed.pipeThrough(web.ReadableWritablePair(readable: ds.readable, writable: ds.writable));
  final buf = await web.Response(plain).arrayBuffer().toDart;
  return buf.toDart.asUint8List();
}
