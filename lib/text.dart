/// Text helpers for the books of «تراث»: cleaning a page, Arabic normalisation
/// for search, and finding saved words again inside a page.
library;

final _harakat = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

String stripHarakat(String s) => s.replaceAll(_harakat, '');

bool _isHaraka(int c) =>
    (c >= 0x0610 && c <= 0x061A) || (c >= 0x064B && c <= 0x065F) || c == 0x0670 || (c >= 0x06D6 && c <= 0x06ED) || c == 0x0640;

int _fold(int c) {
  switch (c) {
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0622: // آ
    case 0x0671: // ٱ
      return 0x0627; // ا
    case 0x0649: // ى
      return 0x064A; // ي
    case 0x0629: // ة
      return 0x0647; // ه
    case 0x0624: // ؤ
      return 0x0648;
    case 0x0626: // ئ
      return 0x064A;
    default:
      return c;
  }
}

/// Search form of a text: no harakat, one form of alif / ya / ta marbuta, one space.
String norm(String s) {
  final b = StringBuffer();
  var space = false;
  for (final c in s.runes) {
    if (_isHaraka(c)) continue;
    if (c == 0x20 || c == 0x0A || c == 0x09 || c == 0xA0) {
      if (!space && b.isNotEmpty) b.write(' ');
      space = true;
      continue;
    }
    space = false;
    b.writeCharCode(_fold(c));
  }
  return b.toString().trim();
}

/// Same as [norm] but also returns, for each kept character, its place in [s].
(String, List<int>) normWithMap(String s) {
  final b = StringBuffer();
  final map = <int>[];
  var space = false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (_isHaraka(c)) continue;
    if (c == 0x20 || c == 0x0A || c == 0x09 || c == 0xA0) {
      if (!space && map.isNotEmpty) {
        b.write(' ');
        map.add(i);
      }
      space = true;
      continue;
    }
    space = false;
    b.writeCharCode(_fold(c));
    map.add(i);
  }
  return (b.toString(), map);
}

/// Where [needle] is in [text] (start, end), ignoring harakat and alif forms.
/// [hint] picks the nearest one when the words appear more than once.
(int, int)? locate(String text, String needle, {int hint = 0}) {
  final n = norm(needle);
  if (n.isEmpty) return null;
  final (t, map) = normWithMap(text);
  var best = -1;
  var from = 0;
  while (true) {
    final i = t.indexOf(n, from);
    if (i < 0) break;
    if (best < 0 || (map[i] - hint).abs() < (map[best] - hint).abs()) best = i;
    from = i + 1;
  }
  if (best < 0) return null;
  final end = best + n.length - 1;
  return (map[best], (end < map.length ? map[end] : text.length - 1) + 1);
}

/// One page, cleaned: the main text with its titles, and the footnotes.
class PageText {
  final String body;
  final List<(int, int)> titles;
  final String foot;
  const PageText(this.body, this.titles, this.foot);
}

final _tag = RegExp(r'<(/?)([a-zA-Z0-9]+)([^>]*)>');
final _footLine = RegExp(r'\n?\s*_{5,}\s*\n?');

String _unescape(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

(String, List<(int, int)>) _clean(String s) {
  final sb = StringBuffer();
  final titles = <(int, int)>[];
  int? titleStart;
  var depth = 0;
  var last = 0;
  for (final m in _tag.allMatches(s)) {
    sb.write(_unescape(s.substring(last, m.start)));
    last = m.end;
    final closing = m.group(1) == '/';
    final name = m.group(2)!.toLowerCase();
    final attrs = m.group(3) ?? '';
    if (name == 'br') {
      sb.write('\n');
    } else if (name == 'span') {
      if (!closing) {
        if (titleStart == null && attrs.contains('title')) {
          titleStart = sb.length;
          depth = 0;
        } else if (titleStart != null) {
          depth++;
        }
      } else if (titleStart != null) {
        if (depth == 0) {
          if (sb.length > titleStart) titles.add((titleStart, sb.length));
          titleStart = null;
        } else {
          depth--;
        }
      }
    } else if ((name == 'p' || name == 'div') && closing) {
      sb.write('\n');
    }
  }
  sb.write(_unescape(s.substring(last)));
  if (titleStart != null && sb.length > titleStart) titles.add((titleStart, sb.length));
  var text = sb.toString().replaceAll('\r', '');
  final lead = text.length - text.trimLeft().length;
  text = text.trim();
  final shifted = <(int, int)>[];
  for (final (a, b) in titles) {
    final s2 = (a - lead).clamp(0, text.length);
    final e2 = (b - lead).clamp(0, text.length);
    if (e2 > s2) shifted.add((s2, e2));
  }
  return (text, shifted);
}

PageText cleanPage(String raw, {bool harakat = true}) {
  var s = raw;
  if (!harakat) s = stripHarakat(s);
  String body = s, foot = '';
  final m = _footLine.firstMatch(s);
  if (m != null) {
    body = s.substring(0, m.start);
    foot = s.substring(m.end);
  }
  final (b, titles) = _clean(body);
  final (f, _) = _clean(foot);
  return PageText(b, titles, f);
}

/// A short piece of [text] around the first place of [q] (for search results).
String snippet(String text, String q, {int around = 70}) {
  final plain = _clean(text).$1.replaceAll('\n', ' ');
  final r = locate(plain, q);
  if (r == null) return plain.length > around * 2 ? '${plain.substring(0, around * 2)}…' : plain;
  final a = (r.$1 - around).clamp(0, plain.length);
  final b = (r.$2 + around).clamp(0, plain.length);
  return '${a > 0 ? '…' : ''}${plain.substring(a, b)}${b < plain.length ? '…' : ''}';
}

/// Removes the <em> marks of «تراث» search snippets, keeping where they were.
(String, List<(int, int)>) emSnippet(String s) {
  final sb = StringBuffer();
  final marks = <(int, int)>[];
  int? open;
  var last = 0;
  for (final m in _tag.allMatches(s)) {
    sb.write(_unescape(s.substring(last, m.start)));
    last = m.end;
    if (m.group(2)!.toLowerCase() == 'em') {
      if (m.group(1) != '/') {
        open = sb.length;
      } else if (open != null) {
        marks.add((open, sb.length));
        open = null;
      }
    }
  }
  sb.write(_unescape(s.substring(last)));
  return (sb.toString().replaceAll('\n', ' '), marks);
}
