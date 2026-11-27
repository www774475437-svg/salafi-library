import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'catalog.dart';
import 'screen.dart';

/// A chosen saying of a scholar, with the source as its collector wrote it.
class Faida {
  final Scholar scholar;
  final String text;
  final String source;
  final bool raw; // the scholar is quoting someone else: shared without «قال …»
  final String by; // who chose it
  final int book; // the library's book that holds it, 0 when not tied yet
  final int pg; // its page there
  final String was; // the source as first written, when it had to be corrected
  final int post; // number of the post it was chosen in
  const Faida(this.scholar, this.text, this.source, this.raw, this.by, {this.book = 0, this.pg = 0, this.was = '', this.post = 0});

  /// What a saved saying is remembered by.
  String get key => book > 0 ? '$book:$pg:$post' : 't:${text.hashCode}';

  String get shareText => raw
      ? '$text،.🪶\n\n[📓$source]'
      : '▪️ قال ${scholar.short} ${scholar.honorific}:\n\n«$text،.🪶»\n\n[📓$source]';
}

class Fawaid {
  static final List<Faida> all = [];
  static final Map<String, String> credit = {}; // scholar key → who chose them
  static final List<Map<String, dynamic>> pending = []; // not found in the books yet (developer only)
  static String channel = '';

  static Future<void> load() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/data/fawaid.json')) as Map<String, dynamic>;
      for (final a in (j['accounts'] as List? ?? const [])) {
        final m = a as Map<String, dynamic>;
        Scholar? s;
        for (final x in Catalog.scholars) {
          if (x.key == m['scholar']) s = x;
        }
        if (s == null) continue;
        final by = '${m['by'] ?? ''}';
        credit[s.key] = by;
        final seen = <String>{};
        for (final it in (m['items'] as List? ?? const [])) {
          final t = '${(it as Map)['t'] ?? ''}'.trim();
          if (t.isEmpty || !seen.add(t)) continue; // no repeats
          all.add(Faida(s, t, '${it['s'] ?? ''}'.trim(), it['raw'] == true, by,
              book: (it['b'] as num?)?.toInt() ?? 0,
              pg: (it['p'] as num?)?.toInt() ?? 0,
              was: '${it['was'] ?? ''}',
              post: (it['n'] as num?)?.toInt() ?? 0));
        }
        if ('${m['url'] ?? ''}'.contains('t.me/')) channel = '${m['url']}';
      }
      for (final x in (j['pending'] as List? ?? const [])) {
        pending.add(Map<String, dynamic>.from(x as Map));
      }
    } catch (_) {}
  }

  /// Leaves the sayings of the coming two months for the widget of the phone's home screen.
  static void feedWidget() {
    if (all.isEmpty) return;
    final d = DateTime.now();
    final day = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
    final items = [
      for (var i = 0; i < 60 && i < all.length; i++)
        () {
          final f = all[(day + i) % all.length];
          final t = f.text.length > 320 ? '${f.text.substring(0, 320)}…' : f.text;
          return ['«$t»', '${f.scholar.short} · ${f.source}'];
        }(),
    ];
    Screen.widget(jsonEncode(items), day);
  }

  /// The same one for everybody on a given day.
  static Faida? today() {
    if (all.isEmpty) return null;
    final d = DateTime.now();
    final day = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
    return all[day % all.length];
  }
}
