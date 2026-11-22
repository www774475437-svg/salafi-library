import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'files/files.dart';
import 'store.dart';
import 'ui.dart' show Ar;

class Heading {
  final String title;
  final int level;
  final int pg;
  const Heading(this.title, this.level, this.pg);
}

/// A book's table of contents and the printed page of every page.
class BookIndex {
  final List<Heading> headings;
  final List<String> pageMap; // "vol,page" for pg 1..n
  final int vols;
  const BookIndex(this.headings, this.pageMap, this.vols);

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
    return BookIndex(heads, pm, vols == 0 ? 1 : vols);
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

  static Future<BookIndex> index(int id) async {
    final c = _indexes[id];
    if (c != null) return c;
    final local = await BookFiles.index(id);
    if (local != null) {
      try {
        return _indexes[id] = BookIndex.parse(local);
      } catch (_) {}
    }
    final raw = await _get('$api/book?id=$id&include=indexes&ver=3');
    return _indexes[id] = BookIndex.parse(raw);
  }

  static Future<RawPage> page(int id, int pg) async {
    if (Store.i.downloaded.contains(id)) {
      final all = await BookFiles.pages(id);
      if (all != null && pg >= 1 && pg <= all.length) {
        final p = all[pg - 1];
        return RawPage(p[0] as String, p[1] as int, p[2] as String);
      }
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
