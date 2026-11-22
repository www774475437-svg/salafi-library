import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'catalog.dart';

/// A chosen saying of a scholar, with the source as its collector wrote it.
class Faida {
  final Scholar scholar;
  final String text;
  final String source;
  final bool raw; // the scholar is quoting someone else: shared without «قال …»
  final String by; // who chose it
  const Faida(this.scholar, this.text, this.source, this.raw, this.by);

  String get shareText => raw
      ? '$text،.🪶\n\n[📓$source]'
      : '▪️ قال ${scholar.short} ${scholar.honorific}:\n\n«$text،.🪶»\n\n[📓$source]';
}

class Fawaid {
  static final List<Faida> all = [];
  static final Map<String, String> credit = {}; // scholar key → who chose them

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
          all.add(Faida(s, t, '${it['s'] ?? ''}'.trim(), it['raw'] == true, by));
        }
      }
    } catch (_) {}
  }

  /// The same one for everybody on a given day.
  static Faida? today() {
    if (all.isEmpty) return null;
    final d = DateTime.now();
    final day = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
    return all[day % all.length];
  }
}
