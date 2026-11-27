import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'update.dart' show siteUrl;

/// The work without its edition: «جامع العلوم والحكم - ت الفحل» and «… - ت الأرنؤوط» are one work.
String workOf(BookInfo b) => b.name.split(' - ').first.replaceFirst(RegExp(r'\s+(ت|ط)\s.*$'), '').trim();

/// «المسألة عند العلماء»: the chapters that carry the same title in different books.
/// Made by tool/build_masail.py from the tables of contents; a chapter is here only
/// when another work has a chapter of the very same name.
class Masail {
  static List<List<List<int>>>? _groups; // each entry: [book, page, heading number]
  static final Map<String, int> _at = {}; // "book:heading number" → its group

  static Future<void> _load() async {
    if (_groups != null) return;
    final j = jsonDecode(await rootBundle.loadString('assets/data/masail.json')) as Map<String, dynamic>;
    final g = [
      for (final v in j['groups'] as List) [for (final e in v as List) (e as List).map((x) => (x as num).toInt()).toList()],
    ];
    for (var i = 0; i < g.length; i++) {
      for (final e in g[i]) {
        _at['${e[0]}:${e[2]}'] = i;
      }
    }
    _groups = g;
  }

  /// Where the chapter number [heading] of [b] is found in other works: (book, page).
  static Future<List<(BookInfo, int)>> related(BookInfo b, int heading) async {
    try {
      await _load();
    } catch (_) {
      return const [];
    }
    final gi = _at['${b.id}:$heading'];
    if (gi == null) return const [];
    final mine = workOf(b);
    final seen = <String>{mine};
    final out = <(BookInfo, int)>[];
    for (final e in _groups![gi]) {
      final x = Catalog.byId[e[0]];
      if (x == null || !seen.add(workOf(x))) continue;
      out.add((x, e[1]));
    }
    return out;
  }
}

/// What the developer switches for all readers, from a small file on the site.
class RemoteConfig {
  /// Whether readers are offered to continue in «تراث» when something is not found here.
  static bool turathLink = true;

  static Future<void> load() async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
      turathLink = p.getBool('cfgTurathLink') ?? true;
    } catch (_) {}
    try {
      final url = kIsWeb ? Uri.base.resolve('config.json') : Uri.parse('${siteUrl}config.json');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      turathLink = j['turathLink'] != false;
      p?.setBool('cfgTurathLink', turathLink);
    } catch (_) {}
  }
}
