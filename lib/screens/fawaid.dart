import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../fawaid.dart';
import '../text.dart';
import '../turath.dart';
import '../ui.dart';
import 'quote_image.dart';
import 'reader.dart';

/// Finds the saying inside the scholar's books and opens it there.
Future<void> openFaidaPlace(BuildContext context, Faida f) async {
  // the longest run of words with no punctuation is the safest thing to look for
  final runs = stripHarakat(f.text).split(RegExp('[^ء-ي\\s]+')).map((r) => r.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList()).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (runs.isEmpty || runs.first.length < 3) {
    toast(context, 'النص أقصر من أن يُبحث عنه');
    return;
  }
  final q = runs.first.take(6).join(' ');
  final s = f.scholar;
  final nav = Navigator.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [CircularProgressIndicator(), SizedBox(width: 18), Expanded(child: Text('يبحث عن موضعها في الكتب…'))]),
    ),
  );
  SearchHit? hit;
  var reached = true;
  try {
    if (kIsWeb) {
      final books = s.books.where((b) => Turath.hosted.contains(b.id)).toList();
      if (books.isEmpty) reached = false;
      for (final b in books) {
        final r = await Turath.searchHosted(b.id, s.authorId, b.name, q, limit: 1);
        if (r.isNotEmpty) {
          hit = r.first;
          break;
        }
      }
    } else {
      final (_, hits) = await Turath.search(q, s.authorId);
      final nq = norm(q);
      // the result must really hold the words, not only resemble them
      for (final h in hits) {
        if (norm(emSnippet(h.snip).$1).contains(nq)) {
          hit = h;
          break;
        }
      }
      hit ??= hits.isEmpty ? null : hits.first;
    }
  } catch (_) {
    reached = false;
  }
  nav.pop();
  if (!context.mounted) return;
  if (hit != null) {
    openReader(context, bookOrStub(hit.book, hit.bookName, hit.authorId), hit.pg);
  } else if (!reached) {
    toast(context, kIsWeb ? 'كتب ${s.short} لم تُضف إلى الموقع بعد، وهذا يعمل في تطبيق أندرويد' : 'تعذّر البحث، تأكّد من الإنترنت');
  } else {
    toast(context, 'لم أجد موضعها في كتب ${s.short}، فتحقّق من المصدر المكتوب');
  }
}

class FawaidScreen extends StatefulWidget {
  const FawaidScreen({super.key});
  @override
  State<FawaidScreen> createState() => _FawaidScreenState();
}

class _FawaidScreenState extends State<FawaidScreen> {
  String q = '';
  String scholar = '';

  @override
  Widget build(BuildContext context) {
    final keys = <String>[];
    for (final f in Fawaid.all) {
      if (!keys.contains(f.scholar.key)) keys.add(f.scholar.key);
    }
    final nq = norm(q);
    final list = Fawaid.all
        .where((f) => (scholar.isEmpty || f.scholar.key == scholar) && (nq.isEmpty || norm(f.text).contains(nq) || norm(f.source).contains(nq)))
        .toList();
    Scholar byKey(String k) => Catalog.scholars.firstWhere((s) => s.key == k);
    return Scaffold(
      appBar: AppBar(title: const Text('الفوائد المنتقاة')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'ابحث في الفوائد…',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: C.card(context),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
            ),
          ),
        ),
        if (keys.length > 1)
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), children: [
              _chip('الكل', scholar.isEmpty, () => setState(() => scholar = '')),
              for (final k in keys) _chip(byKey(k).short, scholar == k, () => setState(() => scholar = k)),
            ]),
          ),
        Expanded(
          child: list.isEmpty
              ? EmptyNote(Icons.lightbulb_outline_rounded, Fawaid.all.isEmpty ? 'تُضاف الفوائد قريبًا بإذن الله.' : 'لا فائدة بهذه الكلمة.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) => i == 0
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('${Ar.num(list.length)} فائدة', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                        )
                      : FaidaCard(list[i - 1]),
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(label: Text(label), selected: on, showCheckmark: false, onSelected: (_) => tap()),
      );
}

class FaidaCard extends StatelessWidget {
  final Faida f;
  final String? title;
  const FaidaCard(this.f, {super.key, this.title});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String label, VoidCallback tap) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 21, color: C.accent(context)),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11, color: C.muted(context))),
            ]),
          ),
        );
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => openFaidaPlace(context, f),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (title != null) ...[
            Icon(Icons.lightbulb_rounded, size: 20, color: C.gold(context)),
            const SizedBox(width: 6),
            Text(title!, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: C.gold(context))),
            const Spacer(),
          ],
          ScholarMark(f.scholar.short, size: 26),
          const SizedBox(width: 8),
          Text(f.scholar.short, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.accent(context))),
        ]),
        const SizedBox(height: 8),
        Text(f.text, style: TextStyle(fontFamily: bookFont, fontSize: 18.5, height: 1.85, color: C.ink(context))),
        const SizedBox(height: 8),
        if (f.source.isNotEmpty) Text('📓 ${f.source}', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          btn(Icons.menu_book_rounded, 'موضعها', () => openFaidaPlace(context, f)),
          btn(Icons.copy_rounded, 'نسخ', () {
            Clipboard.setData(ClipboardData(text: f.shareText));
            toast(context, 'نُسخت مع المصدر');
          }),
          btn(Icons.share_rounded, 'مشاركة', () => Share.share(f.shareText)),
          btn(Icons.image_outlined, 'صورة', () => showQuoteImage(context, text: f.text, scholar: f.raw ? '' : '${f.scholar.name} ${f.scholar.honorific}', source: f.source)),
        ]),
      ]),
    );
  }
}
