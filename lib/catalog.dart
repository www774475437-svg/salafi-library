import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class BookInfo {
  final int id;
  final String name;
  final int pages;
  final int vols;
  final String catName;
  final String info;
  final Scholar scholar;
  BookInfo(this.id, this.name, this.pages, this.vols, this.catName, this.info, this.scholar);

  /// The name without the edition («- ط دار …»), for quotes and short titles.
  String get shortName {
    final i = name.indexOf(' - ط');
    return (i > 0 ? name.substring(0, i) : name).trim();
  }

  /// The edition, if the name carries one.
  String get edition {
    final i = name.indexOf(' - ط');
    return i > 0 ? name.substring(i + 3).trim() : '';
  }
}

class Scholar {
  final String key, name, short, honorific;
  final int? death;
  final int authorId;
  final List<BookInfo> books = [];

  /// A section of books by many authors (the six books, the tafsirs), not one scholar.
  final bool collection;
  Scholar(this.key, this.name, this.short, this.honorific, this.death, this.authorId, {this.collection = false});

  String get deathText => collection ? '' : death == null ? 'حفظه الله' : 'ت ${death!} هـ';
}

class Catalog {
  static final List<Scholar> scholars = [];
  static final Map<int, BookInfo> byId = {};
  static int made = 0;

  static Future<void> load() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/data/catalog.json')) as Map<String, dynamic>;
      made = (j['made'] as num?)?.toInt() ?? 0;
      for (final s in (j['scholars'] as List)) {
        final m = s as Map<String, dynamic>;
        final sc = Scholar(m['key'] as String, m['name'] as String, m['short'] as String, (m['honorific'] as String?) ?? 'رَحِمَهُ الله',
            (m['death'] as num?)?.toInt(), (m['authorId'] as num?)?.toInt() ?? 0,
            collection: m['kind'] == 'collection');
        for (final b in (m['books'] as List? ?? const [])) {
          final bm = b as Map<String, dynamic>;
          final info = BookInfo((bm['id'] as num).toInt(), (bm['name'] as String?) ?? '', (bm['pages'] as num?)?.toInt() ?? 0,
              (bm['vols'] as num?)?.toInt() ?? 1, (bm['catName'] as String?) ?? '', (bm['info'] as String?) ?? '', sc);
          sc.books.add(info);
          byId[info.id] = info;
        }
        scholars.add(sc);
      }
    } catch (_) {}
  }

  /// The scholars themselves, without the sections.
  static List<Scholar> get people => scholars.where((s) => !s.collection).toList();
  static List<Scholar> get sections => scholars.where((s) => s.collection).toList();

  static Scholar? scholarOfAuthor(int authorId) {
    for (final s in scholars) {
      if (authorId > 0 && s.authorId == authorId) return s;
    }
    return null;
  }

  static int get totalBooks => byId.length;
}
