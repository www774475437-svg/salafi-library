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

  // reading
  final Map<int, int> lastPg = {};
  final List<int> recent = [];
  final Set<int> downloaded = {};
  final List<Kept> bookmarks = [];
  final List<Kept> highlights = [];
  final List<Kept> quotes = [];

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
    try {
      final lp = jsonDecode(p.getString('lastPg') ?? '{}') as Map<String, dynamic>;
      lp.forEach((k, v) => lastPg[int.parse(k)] = (v as num).toInt());
      recent.addAll((jsonDecode(p.getString('recent') ?? '[]') as List).map((e) => (e as num).toInt()));
      downloaded.addAll((jsonDecode(p.getString('downloaded') ?? '[]') as List).map((e) => (e as num).toInt()));
      bookmarks.addAll(_list('bookmarks'));
      highlights.addAll(_list('highlights'));
      quotes.addAll(_list('quotes'));
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
    p.setString('lastPg', jsonEncode(lastPg.map((k, v) => MapEntry('$k', v))));
    p.setString('recent', jsonEncode(recent));
    p.setString('downloaded', jsonEncode(downloaded.toList()));
    p.setString('bookmarks', jsonEncode(bookmarks.map((e) => e.toJson()).toList()));
    p.setString('highlights', jsonEncode(highlights.map((e) => e.toJson()).toList()));
    p.setString('quotes', jsonEncode(quotes.map((e) => e.toJson()).toList()));
  }

  void changed() {
    _save();
    notifyListeners();
  }

  void setSettings({int? themeMode, double? fontSize, String? readFont, int? paper, bool? tashkeel}) {
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

  void remove(Kept k) {
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
    (j['lastPg'] as Map<String, dynamic>? ?? {}).forEach((k, v) => lastPg.putIfAbsent(int.parse(k), () => (v as num).toInt()));
    for (final r in (j['recent'] as List? ?? const [])) {
      final b = (r as num).toInt();
      if (!recent.contains(b)) recent.add(b);
    }
    changed();
    return n;
  }
}
