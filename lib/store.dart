import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Something the reader kept: a bookmark (فاصلة), a highlight (تظليل) or a quote (اقتباس).
class Kept {
  final String id;
  final int book;
  final int pg;
  final String text; // the highlighted / quoted words (empty for a bookmark)
  final int color; // 0 yellow, 1 red, 2 green
  final String label; // «ج١ ص٢٥»
  final int at;
  String note;
  Kept({required this.id, required this.book, required this.pg, this.text = '', this.color = 0, this.label = '', required this.at, this.note = ''});

  Map<String, dynamic> toJson() => {'id': id, 'b': book, 'p': pg, 't': text, 'c': color, 'l': label, 'a': at, 'n': note};
  static Kept fromJson(Map<String, dynamic> j) => Kept(
        id: j['id'] as String,
        book: (j['b'] as num).toInt(),
        pg: (j['p'] as num).toInt(),
        text: (j['t'] as String?) ?? '',
        color: (j['c'] as num?)?.toInt() ?? 0,
        label: (j['l'] as String?) ?? '',
        at: (j['a'] as num?)?.toInt() ?? 0,
        note: (j['n'] as String?) ?? '',
      );
}

/// A highlight colour the reader can name («طرائف», «فوائد»…).
class HlColor {
  int value; // 0xRRGGBB
  String name;
  HlColor(this.value, this.name);
}

/// Colours offered when the reader adds a new one.
const hlPalette = [0xFFD54F, 0xEF5350, 0x66BB6A, 0x64B5F6, 0xFFA726, 0xBA68C8, 0xF48FB1, 0x4DB6AC];

Color hlColor(int c) {
  final cs = Store.i.colors;
  return Color(0xFF000000 | cs[c < 0 || c >= cs.length ? 0 : c].value).withValues(alpha: 0.45);
}

Color hlSolid(int c) => hlColor(c).withValues(alpha: 1);

String hlName(int c) {
  final cs = Store.i.colors;
  return cs[c < 0 || c >= cs.length ? 0 : c].name;
}

class Store extends ChangeNotifier {
  Store._();
  static final i = Store._();
  SharedPreferences? _p;

  // settings
  int themeMode = 0; // 0 like the phone, 1 light, 2 dark
  double fontSize = 22;
  String readFont = 'Amiri';
  int paper = 0; // 0 white, 1 cream, 2 night
  bool tashkeel = true;
  int readMode = 0; // 0 pages like the printed book, 1 one continuous text
  final Map<String, int> pdfOffset = {}; // "book:vol" → scanned page minus printed page

  // reading
  final Map<int, int> lastPg = {};
  final List<int> recent = [];
  final Set<int> downloaded = {};
  final List<Kept> bookmarks = [];
  final List<Kept> highlights = [];
  final List<Kept> quotes = [];
  final List<Kept> notes = [];
  final List<HlColor> colors = [HlColor(0xFFD54F, 'أصفر'), HlColor(0xEF5350, 'أحمر'), HlColor(0x66BB6A, 'أخضر')];

  ThemeMode get mode => themeMode == 1 ? ThemeMode.light : themeMode == 2 ? ThemeMode.dark : ThemeMode.system;

  Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final p = _p!;
    themeMode = p.getInt('themeMode') ?? 0;
    fontSize = p.getDouble('fontSize') ?? 22;
    readFont = p.getString('readFont') ?? 'Amiri';
    paper = p.getInt('paper') ?? 0;
    tashkeel = p.getBool('tashkeel') ?? true;
    readMode = p.getInt('readMode') ?? 0;
    try {
      final lp = jsonDecode(p.getString('lastPg') ?? '{}') as Map<String, dynamic>;
      lp.forEach((k, v) => lastPg[int.parse(k)] = (v as num).toInt());
      recent.addAll((jsonDecode(p.getString('recent') ?? '[]') as List).map((e) => (e as num).toInt()));
      (jsonDecode(p.getString('pdfOffset') ?? '{}') as Map<String, dynamic>).forEach((k, v) => pdfOffset[k] = (v as num).toInt());
      downloaded.addAll((jsonDecode(p.getString('downloaded') ?? '[]') as List).map((e) => (e as num).toInt()));
      bookmarks.addAll(_list('bookmarks'));
      highlights.addAll(_list('highlights'));
      quotes.addAll(_list('quotes'));
      notes.addAll(_list('notes'));
      final cs = jsonDecode(p.getString('colors') ?? '[]') as List;
      if (cs.length >= 3) {
        colors
          ..clear()
          ..addAll(cs.map((e) => HlColor(((e as Map)['v'] as num).toInt(), '${e['n']}')));
      }
    } catch (_) {}
  }

  List<Kept> _list(String key) {
    try {
      return (jsonDecode(_p?.getString(key) ?? '[]') as List).map((e) => Kept.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    final p = _p;
    if (p == null) return;
    p.setInt('themeMode', themeMode);
    p.setDouble('fontSize', fontSize);
    p.setString('readFont', readFont);
    p.setInt('paper', paper);
    p.setBool('tashkeel', tashkeel);
    p.setInt('readMode', readMode);
    p.setString('pdfOffset', jsonEncode(pdfOffset));
    p.setString('lastPg', jsonEncode(lastPg.map((k, v) => MapEntry('$k', v))));
    p.setString('recent', jsonEncode(recent));
    p.setString('downloaded', jsonEncode(downloaded.toList()));
    p.setString('bookmarks', jsonEncode(bookmarks.map((e) => e.toJson()).toList()));
    p.setString('highlights', jsonEncode(highlights.map((e) => e.toJson()).toList()));
    p.setString('quotes', jsonEncode(quotes.map((e) => e.toJson()).toList()));
    p.setString('notes', jsonEncode(notes.map((e) => e.toJson()).toList()));
    p.setString('colors', jsonEncode([for (final c in colors) {'v': c.value, 'n': c.name}]));
  }

  void changed() {
    _save();
    notifyListeners();
  }

  void setSettings({int? themeMode, double? fontSize, String? readFont, int? paper, bool? tashkeel, int? readMode}) {
    if (readMode != null) this.readMode = readMode;
    if (themeMode != null) this.themeMode = themeMode;
    if (fontSize != null) this.fontSize = fontSize.clamp(15, 40).toDouble();
    if (readFont != null) this.readFont = readFont;
    if (paper != null) this.paper = paper;
    if (tashkeel != null) this.tashkeel = tashkeel;
    changed();
  }

  /// Remembers where the reader stopped (saved quietly, no rebuild of the whole app).
  void readAt(int book, int pg) {
    lastPg[book] = pg;
    recent.remove(book);
    recent.insert(0, book);
    if (recent.length > 30) recent.removeLast();
    _save();
  }

  int offsetFor(int book, String vol) => pdfOffset['$book:$vol'] ?? pdfOffset['$book:'] ?? 0;

  void setOffset(int book, String vol, int off) {
    pdfOffset['$book:$vol'] = off;
    pdfOffset['$book:'] = off;
    changed();
  }

  void forgetRecent(int book) {
    recent.remove(book);
    changed();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  static int now() => DateTime.now().millisecondsSinceEpoch;

  bool isBookmarked(int book, int pg) => bookmarks.any((b) => b.book == book && b.pg == pg);

  void toggleBookmark(int book, int pg, String label) {
    final i = bookmarks.indexWhere((b) => b.book == book && b.pg == pg);
    if (i >= 0) {
      bookmarks.removeAt(i);
    } else {
      bookmarks.insert(0, Kept(id: newId(), book: book, pg: pg, label: label, at: now()));
    }
    changed();
  }

  Kept addHighlight(int book, int pg, String text, int color, String label) {
    final k = Kept(id: newId(), book: book, pg: pg, text: text.trim(), color: color, label: label, at: now());
    highlights.insert(0, k);
    changed();
    return k;
  }

  Kept addQuote(int book, int pg, String text, String label) {
    final k = Kept(id: newId(), book: book, pg: pg, text: text.trim(), label: label, at: now());
    quotes.insert(0, k);
    changed();
    return k;
  }

  Kept addNote(int book, int pg, String text, String note, String label) {
    final k = Kept(id: newId(), book: book, pg: pg, text: text.trim(), label: label, at: now(), note: note.trim());
    notes.insert(0, k);
    changed();
    return k;
  }

  /// Adds a colour (at most six). Returns its number, or -1.
  int addColor(int value, String name) {
    if (colors.length >= 6) return -1;
    colors.add(HlColor(value, name.trim().isEmpty ? 'لون ${colors.length + 1}' : name.trim()));
    changed();
    return colors.length - 1;
  }

  void renameColor(int c, String name) {
    if (c < 0 || c >= colors.length || name.trim().isEmpty) return;
    colors[c].name = name.trim();
    changed();
  }

  void remove(Kept k) {
    notes.remove(k);
    bookmarks.remove(k);
    highlights.remove(k);
    quotes.remove(k);
    changed();
  }

  void setDownloaded(int book, bool on) {
    if (on) {
      downloaded.add(book);
    } else {
      downloaded.remove(book);
    }
    changed();
  }

  List<Kept> highlightsOn(int book, int pg) => highlights.where((h) => h.book == book && h.pg == pg).toList();

  /// Everything personal as one text (to keep a copy or move to a new phone).
  String backup() => jsonEncode({
        'v': 1,
        'lastPg': lastPg.map((k, v) => MapEntry('$k', v)),
        'recent': recent,
        'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
        'highlights': highlights.map((e) => e.toJson()).toList(),
        'quotes': quotes.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'colors': [for (final c in colors) {'v': c.value, 'n': c.name}],
      });

  /// Adds a copy made by [backup] (nothing already here is removed).
  int restore(String text) {
    final j = jsonDecode(text.trim()) as Map<String, dynamic>;
    var n = 0;
    void addAll(List<Kept> into, String key) {
      for (final e in (j[key] as List? ?? const [])) {
        final k = Kept.fromJson(e as Map<String, dynamic>);
        if (into.any((x) => x.id == k.id)) continue;
        into.add(k);
        n++;
      }
      into.sort((a, b) => b.at.compareTo(a.at));
    }

    addAll(bookmarks, 'bookmarks');
    addAll(highlights, 'highlights');
    addAll(quotes, 'quotes');
    addAll(notes, 'notes');
    final cs = j['colors'] as List? ?? const [];
    for (var i = colors.length; i < cs.length && i < 6; i++) {
      colors.add(HlColor(((cs[i] as Map)['v'] as num).toInt(), '${cs[i]['n']}'));
    }
    (j['lastPg'] as Map<String, dynamic>? ?? {}).forEach((k, v) => lastPg.putIfAbsent(int.parse(k), () => (v as num).toInt()));
    for (final r in (j['recent'] as List? ?? const [])) {
      final b = (r as num).toInt();
      if (!recent.contains(b)) recent.add(b);
    }
    changed();
    return n;
  }
}
