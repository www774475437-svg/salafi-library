import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

import '../text.dart';

List<List<Object>> _decodePages(String raw) {
  final j = jsonDecode(raw) as Map<String, dynamic>;
  final out = <List<Object>>[];
  for (final p in (j['pages'] as List? ?? const [])) {
    final m = p as Map<String, dynamic>;
    out.add([
      '${m['vol'] ?? ''}',
      (m['page'] as num?)?.toInt() ?? 0,
      (m['text'] as String?) ?? '',
    ]);
  }
  return out;
}

/// Downloaded books, kept as files on the phone.
class BookFiles {
  static bool get supported => true;
  static Directory? _dir;
  static int? _cachedId;
  static List<List<Object>>? _cached;

  static Future<Directory> _root() async {
    if (_dir != null) return _dir!;
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/books');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  static Future<File> _book(int id) async => File('${(await _root()).path}/b$id.json');
  static Future<File> _index(int id) async => File('${(await _root()).path}/b$id.idx.json');

  static Future<bool> has(int id) async => (await _book(id)).exists();

  static Future<void> write(int id, List<int> bytes, String index) async {
    final f = await _book(id);
    final tmp = File('${f.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await (await _index(id)).writeAsString(index, flush: true);
    await tmp.rename(f.path);
    if (_cachedId == id) {
      _cachedId = null;
      _cached = null;
    }
  }

  static Future<String?> index(int id) async {
    final f = await _index(id);
    return await f.exists() ? f.readAsString() : null;
  }

  /// All pages of a downloaded book: [volume, printed page, text]. Read once, then kept.
  static Future<List<List<Object>>?> pages(int id) async {
    if (_cachedId == id && _cached != null) return _cached;
    final f = await _book(id);
    if (!await f.exists()) return null;
    final path = f.path;
    try {
      final pages = await Isolate.run(() => _decodePages(File(path).readAsStringSync()));
      _cachedId = id;
      _cached = pages;
      return pages;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(int id) async {
    for (final f in [await _book(id), await _index(id)]) {
      if (await f.exists()) await f.delete();
    }
    if (_cachedId == id) {
      _cachedId = null;
      _cached = null;
    }
  }

  static Future<int> size(int id) async {
    final f = await _book(id);
    return await f.exists() ? f.length() : 0;
  }

  /// Searches a downloaded book without internet. Each result: pg, vol, page, snip.
  static Future<List<Map<String, Object>>> search(int id, String q, int limit) async {
    final f = await _book(id);
    if (!await f.exists()) return const [];
    final path = f.path;
    return Isolate.run(() {
      final pages = _decodePages(File(path).readAsStringSync());
      final nq = norm(q);
      final out = <Map<String, Object>>[];
      for (var i = 0; i < pages.length && out.length < limit; i++) {
        final t = pages[i][2] as String;
        if (!norm(t).contains(nq)) continue;
        out.add({'pg': i + 1, 'vol': pages[i][0], 'page': pages[i][1], 'snip': snippet(t, q)});
      }
      return out;
    });
  }
}
