import 'package:flutter/material.dart';

import '../catalog.dart';
import '../text.dart';
import '../turath.dart';
import '../ui.dart';
import 'search.dart' show HitCard;

/// The dictionaries, in the order they are asked: the shortest first.
List<BookInfo> get dictionaries {
  for (final s in Catalog.sections) {
    if (s.key == 'maajim') return s.books;
  }
  return const [];
}

/// Forms of a word to look for: as it stands, then without «ال», the joined
/// particles and the common endings.
List<String> wordForms(String word) {
  final w = norm(word).replaceAll(RegExp('[^ء-ي]'), '');
  final out = <String>[];
  void add(String x) {
    if (x.length >= 2 && !out.contains(x)) out.add(x);
  }

  add(w);
  var x = w;
  for (final p in ['وال', 'فال', 'بال', 'كال', 'لل', 'ال']) {
    if (x.startsWith(p) && x.length - p.length >= 3) {
      x = x.substring(p.length);
      break;
    }
  }
  add(x);
  for (final p in ['و', 'ف', 'ب', 'ل', 'ك']) {
    if (x.startsWith(p) && x.length >= 4) add(x.substring(1));
  }
  for (final e in ['هما', 'هم', 'هن', 'ها', 'كم', 'نا', 'ات', 'ون', 'ين', 'ان', 'وا', 'ه', 'ي', 'ك', 'ت']) {
    if (x.endsWith(e) && x.length - e.length >= 3) add(x.substring(0, x.length - e.length));
  }
  return out;
}

/// The meaning of [word]: asks each dictionary in turn and stops at the first that has it.
class DictScreen extends StatefulWidget {
  final String word;
  const DictScreen(this.word, {super.key});
  @override
  State<DictScreen> createState() => _DictScreenState();
}

class _DictScreenState extends State<DictScreen> {
  final List<(BookInfo, List<SearchHit>)> found = [];
  String now = '';
  bool done = false;
  bool unreachable = false;

  @override
  void initState() {
    super.initState();
    _look(stopAtFirst: true);
  }

  Future<void> _look({required bool stopAtFirst}) async {
    final forms = wordForms(widget.word);
    final tried = found.map((f) => f.$1.id).toSet();
    for (final d in dictionaries) {
      if (tried.contains(d.id)) continue;
      if (!Turath.hosted.contains(d.id)) continue;
      if (mounted) setState(() => now = d.shortName);
      try {
        final hits = <SearchHit>[];
        // the entry itself first: a heading that is the word
        final ix = await Turath.index(d.id);
        for (final f in forms) {
          for (final h in ix.headings) {
            final t = norm(h.title).replaceAll(RegExp('[^ء-ي]'), '');
            if (t == f && !hits.any((x) => x.pg == h.pg)) {
              final (vol, page) = ix.printed(h.pg);
              hits.add(SearchHit(d.id, 0, h.pg, vol, page, d.name, 'مادة <em>${h.title}</em>'));
            }
          }
          if (hits.isNotEmpty) break;
        }
        // then wherever the word is written
        for (final f in forms) {
          if (hits.length >= 12) break;
          final r = await Turath.searchHosted(d.id, 0, d.name, f, limit: 12);
          for (final h in r) {
            if (hits.length < 12 && !hits.any((x) => x.pg == h.pg)) hits.add(h);
          }
          if (r.isNotEmpty) break;
        }
        if (hits.isNotEmpty) {
          found.add((d, hits));
          if (stopAtFirst) break;
        }
      } catch (_) {
        unreachable = true;
      }
    }
    if (mounted) {
      setState(() {
        now = '';
        done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dicts = dictionaries;
    final left = dicts.where((d) => Turath.hosted.contains(d.id) && !found.any((f) => f.$1.id == d.id)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('معنى «${widget.word.trim()}»')),
      body: dicts.isEmpty || !dicts.any((d) => Turath.hosted.contains(d.id))
          ? const EmptyNote(Icons.translate_rounded, 'المعاجم لم تُضف بعد. تتوفّر قريبًا بإذن الله.')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
              if (now.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(children: [
                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 14),
                    Expanded(child: Text('يبحث في $now…', style: TextStyle(color: C.muted(context)))),
                  ]),
                ),
              for (final (d, hits) in found) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                  child: Text(d.shortName, style: TextStyle(fontFamily: bookFont, fontSize: 19, fontWeight: FontWeight.w700, color: C.accent(context))),
                ),
                for (final h in hits) HitCard(h, query: widget.word),
              ],
              if (done && found.isEmpty)
                EmptyNote(Icons.search_off_rounded, unreachable ? 'تعذّر الوصول إلى المعاجم، تأكّد من الإنترنت.' : 'لم أجد «${widget.word.trim()}» في المعاجم. جرّب تحديد الكلمة وحدها بلا ما قبلها وما بعدها.'),
              if (done && left.isNotEmpty && found.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.library_books_outlined),
                    label: Text('ابحث في بقية المعاجم (${left.map((d) => d.shortName).join('، ')})'),
                    onPressed: () {
                      setState(() => done = false);
                      _look(stopAtFirst: false);
                    },
                  ),
                ),
              if (done)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('عُد إلى موضعك في الكتاب'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
            ]),
    );
  }
}

/// Opened from the reader's selection bar.
void openDict(BuildContext context, String word) {
  final w = word.trim();
  if (w.isEmpty || w.split(RegExp(r'\s+')).length > 3) {
    toast(context, 'حدّد كلمة واحدة لتعرف معناها');
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => DictScreen(w)));
}
