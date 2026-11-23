import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show GZipDecoder;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'files/files.dart';
import 'store.dart';
import 'text.dart' show norm;
import 'ui.dart' show Ar;
import 'update.dart' show siteUrl;

class Heading {
  final String title;
  final int level;
  final int pg;
  const Heading(this.title, this.level, this.pg);
}

/// A book's table of contents and the printed page of every page.
class PdfFile {
  final String url;
  final String label; // the volume it holds
  const PdfFile(this.url, this.label);
}

class BookIndex {
  final List<Heading> headings;
  final List<String> pageMap; // "vol,page" for pg 1..n
  final int vols;
  final List<PdfFile> pdfs; // the printed book, scanned
  const BookIndex(this.headings, this.pageMap, this.vols, [this.pdfs = const []]);

  static List<PdfFile> _pdfs(Object? raw) {
    if (raw is! Map) return const [];
    final root = '${raw['root'] ?? ''}'.trim();
    final out = <PdfFile>[];
    final seen = <String>{};
    for (final f in (raw['files'] as List? ?? const [])) {
      final parts = '$f'.split('|');
      final name = parts.first.trim();
      if (name.isEmpty) continue;
      final path = [...root.split('/').where((x) => x.isNotEmpty), name].map(Uri.encodeComponent).join('/');
      final url = 'https://files.turath.io/pdf/$path';
      if (!seen.add(url)) continue;
      out.add(PdfFile(url, parts.length > 1 ? parts[1].trim() : ''));
    }
    return out;
  }

  /// The scanned file holding volume [vol] (or the only one).
  PdfFile? pdfFor(String vol) {
    if (pdfs.isEmpty) return null;
    for (final p in pdfs) {
      if (p.label == vol) return p;
    }
    return pdfs.first;
  }

  int get count => pageMap.length;

  static BookIndex parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final ix = (j['indexes'] ?? j) as Map<String, dynamic>;
    final heads = <Heading>[];
    for (final h in (ix['headings'] as List? ?? const [])) {
      final m = h as Map<String, dynamic>;
      heads.add(Heading(((m['title'] as String?) ?? '').trim(), (m['level'] as num?)?.toInt() ?? 1, (m['page'] as num?)?.toInt() ?? 1));
    }
    final pm = (ix['page_map'] as List? ?? const []).map((e) => '$e').toList();
    final vols = (ix['volumes'] as List? ?? const []).length;
    final meta = j['meta'];
    final pdf = j['pdf'] ?? (meta is Map ? meta['pdf_links'] : null);
    return BookIndex(heads, pm, vols == 0 ? 1 : vols, _pdfs(pdf));
  }

  (String, int) printed(int pg) {
    if (pg < 1 || pg > pageMap.length) return ('', pg);
    final parts = pageMap[pg - 1].split(',');
    return (parts.first, parts.length > 1 ? int.tryParse(parts[1]) ?? pg : pg);
  }

  /// «ج٢ ص٣٤» (or «ص٣٤» for a one-volume book).
  String label(int pg) {
    final (v, p) = printed(pg);
    return vols > 1 && v.isNotEmpty ? 'ج${Ar.num(v)} ص${Ar.num(p)}' : 'ص${Ar.num(p)}';
  }

  /// For quotes: «صـ ٢/٣٤».
  String source(int pg) {
    final (v, p) = printed(pg);
    return vols > 1 && v.isNotEmpty ? '${Ar.num(v)}/${Ar.num(p)}' : Ar.num(p);
  }

  /// The heading the page belongs to.
  Heading? headingAt(int pg) {
    Heading? h;
    for (final x in headings) {
      if (x.pg <= pg) {
        h = x;
      } else {
        break;
      }
    }
    return h;
  }
}

class RawPage {
  final String vol;
  final int page;
  final String text;
  const RawPage(this.vol, this.page, this.text);
}

class SearchHit {
  final int book;
  final int authorId;
  final int pg;
  final String vol;
  final int page;
  final String bookName;
  final String snip; // may hold <em> marks
  const SearchHit(this.book, this.authorId, this.pg, this.vol, this.page, this.bookName, this.snip);
}

class Turath {
  static const api = 'https://api.turath.io';
  static const files = 'https://files.turath.io/books-v3';
  static final _client = http.Client();
  static final Map<int, BookIndex> _indexes = {};
  static final Map<String, RawPage> _pages = {};

  static Future<String> _get(String url, {Duration timeout = const Duration(seconds: 25)}) async {
    final r = await _client.get(Uri.parse(url)).timeout(timeout);
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return utf8.decode(r.bodyBytes);
  }

  // ---- books kept inside the library itself (our own site) ----
  static const chunk = 40;
  static final Set<int> hosted = {};
  static final Map<String, List<dynamic>> _chunks = {};

  static String get booksBase => kIsWeb ? Uri.base.resolve('books/').toString() : '${siteUrl}books/';

  /// The two stores that hold the books compressed (gzip), each a site of its own.
  static const stores = [
    'https://www774475437-svg.github.io/makhzan1-ulama/',
    'https://www774475437-svg.github.io/makhzan2-ulama/',
  ];
  static final Map<int, String> _store = {}; // book → the store that holds it

  /// A file of a kept book, from its store (unpacked here) or from the old place.
  static Future<String> _file(int id, String name, {Duration timeout = const Duration(seconds: 40)}) async {
    final st = _store[id];
    if (st == null) return _get('$booksBase$id/$name', timeout: timeout);
    final r = await _client.get(Uri.parse('$st$id/$name.gz')).timeout(timeout);
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final b = r.bodyBytes;
    // some browsers unpack it themselves on the way
    final packed = b.length > 2 && b[0] == 0x1f && b[1] == 0x8b;
    return utf8.decode(packed ? GZipDecoder().decodeBytes(b) : b);
  }

  /// Which books the library keeps itself. Remembered for when there is no internet.
  static Future<void> loadHosted() async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
      hosted.addAll((jsonDecode(p.getString('hosted') ?? '[]') as List).map((e) => (e as num).toInt()));
      (jsonDecode(p.getString('stores') ?? '{}') as Map<String, dynamic>).forEach((k, v) => _store[int.parse(k)] = '$v');
      hosted.addAll(_store.keys);
    } catch (_) {}
    // the stores answer side by side; a store that is silent keeps what was known
    await Future.wait([
      for (final st in stores)
        () async {
          try {
            final ids = (jsonDecode(await _get('${st}hosted.json', timeout: const Duration(seconds: 12))) as List).map((e) => (e as num).toInt()).toList();
            _store.removeWhere((_, v) => v == st);
            for (final id in ids) {
              _store[id] = st;
            }
          } catch (_) {}
        }(),
    ]);
    try {
      final list = (jsonDecode(await _get('${booksBase}hosted.json', timeout: const Duration(seconds: 12))) as List)
          .map((e) => (e as num).toInt())
          .toSet();
      hosted
        ..clear()
        ..addAll(list);
      p?.setString('hosted', jsonEncode(list.toList()));
    } catch (_) {}
    hosted.addAll(_store.keys);
    p?.setString('stores', jsonEncode(_store.map((k, v) => MapEntry('$k', v))));
  }

  static Future<List<dynamic>> _chunk(int id, int k) async {
    final key = '$id:$k';
    final c = _chunks[key];
    if (c != null) return c;
    final rows = jsonDecode(await _file(id, 'p$k.json')) as List<dynamic>;
    if (_chunks.length > 30) _chunks.clear();
    return _chunks[key] = rows;
  }

  static Future<String> _indexRaw(int id) async {
    if (hosted.contains(id)) {
      try {
        return await _file(id, 'i.json');
      } catch (_) {}
    }
    return _get('$api/book?id=$id&include=indexes&ver=3');
  }

  static Future<BookIndex> index(int id) async {
    final c = _indexes[id];
    if (c != null) return c;
    final local = await BookFiles.index(id);
    if (local != null) {
      try {
        return _indexes[id] = BookIndex.parse(local);
      } catch (_) {}
    }
    return _indexes[id] = BookIndex.parse(await _indexRaw(id));
  }

  static Future<RawPage> page(int id, int pg) async {
    if (Store.i.downloaded.contains(id)) {
      final all = await BookFiles.pages(id);
      if (all != null && pg >= 1 && pg <= all.length) {
        final p = all[pg - 1];
        return RawPage(p[0] as String, p[1] as int, p[2] as String);
      }
    }
    if (hosted.contains(id)) {
      try {
        final rows = await _chunk(id, (pg - 1) ~/ chunk);
        final r = rows[(pg - 1) % chunk] as List<dynamic>;
        return RawPage('${r[0]}', (r[1] as num).toInt(), '${r[2]}');
      } catch (_) {}
    }
    final key = '$id:$pg';
    final c = _pages[key];
    if (c != null) return c;
    final j = jsonDecode(await _get('$api/page?book_id=$id&pg=$pg&ver=3')) as Map<String, dynamic>;
    var vol = '', page = pg;
    try {
      final metaRaw = j['meta'];
      final meta = (metaRaw is String ? jsonDecode(metaRaw) : metaRaw) as Map<String, dynamic>;
      vol = '${meta['vol'] ?? ''}';
      page = (meta['page'] as num?)?.toInt() ?? pg;
    } catch (_) {}
    final p = RawPage(vol, page, (j['text'] as String?) ?? '');
    if (_pages.length > 400) _pages.clear();
    return _pages[key] = p;
  }

  /// Downloads the whole book for reading without internet.
  static Future<void> download(int id, void Function(double) progress) async {
    if (hosted.contains(id)) {
      try {
        await _downloadHosted(id, progress);
        return;
      } catch (_) {}
    }
    final idx = await _get('$api/book?id=$id&include=indexes&ver=3');
    final req = http.Request('GET', Uri.parse('$files/$id.json'));
    final res = await _client.send(req).timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final total = res.contentLength ?? 0;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res.stream) {
      builder.add(chunk);
      if (total > 0) progress(builder.length / total);
    }
    final bytes = builder.takeBytes();
    // make sure it is a real book file before keeping it
    final head = utf8.decode(bytes.length > 2000 ? bytes.sublist(bytes.length - 2000) : bytes, allowMalformed: true);
    if (!head.contains('}')) throw Exception('bad file');
    await BookFiles.write(id, bytes, idx);
    _indexes.remove(id);
    Store.i.setDownloaded(id, true);
  }

  /// From our own site: the index, then the pages part by part.
  static Future<void> _downloadHosted(int id, void Function(double) progress) async {
    final idx = await _file(id, 'i.json');
    final count = ((jsonDecode(idx) as Map<String, dynamic>)['count'] as num?)?.toInt() ?? 0;
    if (count == 0) throw Exception('empty');
    final parts = (count + chunk - 1) ~/ chunk;
    final pages = <Map<String, Object>>[];
    for (var k = 0; k < parts; k++) {
      final rows = jsonDecode(await _file(id, 'p$k.json', timeout: const Duration(seconds: 60))) as List<dynamic>;
      for (final r in rows) {
        final x = r as List<dynamic>;
        pages.add({'vol': '${x[0]}', 'page': (x[1] as num).toInt(), 'text': '${x[2]}'});
      }
      progress((k + 1) / parts);
    }
    final bytes = utf8.encode(jsonEncode({'pages': pages}));
    await BookFiles.write(id, bytes, idx);
    _indexes.remove(id);
    Store.i.setDownloaded(id, true);
  }

  /// Searches a book kept in the library (light text, no harakat). Works on the website too.
  static Future<List<SearchHit>> searchHosted(int id, int authorId, String bookName, String q, {int limit = 60}) async {
    final lines = _texts[id] ?? (await _file(id, 's.txt', timeout: const Duration(seconds: 60))).split('\n');
    if (_texts.length > 6) _texts.clear();
    _texts[id] = lines;
    final nq = norm(q);
    final out = <SearchHit>[];
    if (nq.isEmpty) return out;
    BookIndex? ix;
    try {
      ix = await index(id);
    } catch (_) {}
    for (var i = 0; i < lines.length && out.length < limit; i++) {
      final t = lines[i];
      final at = t.indexOf(nq);
      if (at < 0) continue;
      final a = (at - 80).clamp(0, t.length);
      final b = (at + nq.length + 80).clamp(0, t.length);
      final snip = '${a > 0 ? '…' : ''}${t.substring(a, at)}<em>${t.substring(at, at + nq.length)}</em>${t.substring(at + nq.length, b)}${b < t.length ? '…' : ''}';
      final (vol, page) = ix?.printed(i + 1) ?? ('', i + 1);
      out.add(SearchHit(id, authorId, i + 1, vol, page, bookName, snip));
    }
    return out;
  }

  static final Map<int, List<String>> _texts = {};

  static Future<void> removeDownload(int id) async {
    await BookFiles.delete(id);
    Store.i.setDownloaded(id, false);
  }

  /// Search in «تراث» for one scholar's books. Returns (total, hits).
  static Future<(int, List<SearchHit>)> search(String q, int authorId, {int page = 1}) async {
    final url = '$api/search?q=${Uri.encodeQueryComponent(q)}&ver=3&author=$authorId${page > 1 ? '&page=$page' : ''}';
    final j = jsonDecode(await _get(url)) as Map<String, dynamic>;
    final hits = <SearchHit>[];
    for (final d in (j['data'] as List? ?? const [])) {
      final m = d as Map<String, dynamic>;
      var pg = 1, pageNo = 0;
      var vol = '', name = '';
      try {
        final metaRaw = m['meta'];
        final meta = (metaRaw is String ? jsonDecode(metaRaw) : metaRaw) as Map<String, dynamic>;
        pg = (meta['page_id'] as num?)?.toInt() ?? 1;
        pageNo = (meta['page'] as num?)?.toInt() ?? 0;
        vol = '${meta['vol'] ?? ''}';
        name = '${meta['book_name'] ?? ''}';
      } catch (_) {}
      hits.add(SearchHit((m['book_id'] as num?)?.toInt() ?? 0, (m['author_id'] as num?)?.toInt() ?? authorId, pg, vol, pageNo, name,
          (m['snip'] as String?) ?? (m['text'] as String?) ?? ''));
    }
    return ((j['count'] as num?)?.toInt() ?? hits.length, hits);
  }
}
