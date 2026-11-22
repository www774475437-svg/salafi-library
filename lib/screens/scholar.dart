import 'package:flutter/material.dart';

import '../catalog.dart';
import '../store.dart';
import '../text.dart';
import '../ui.dart';
import 'book.dart';

class ScholarScreen extends StatefulWidget {
  final Scholar scholar;
  const ScholarScreen(this.scholar, {super.key});
  @override
  State<ScholarScreen> createState() => _ScholarScreenState();
}

class _ScholarScreenState extends State<ScholarScreen> {
  String q = '';
  String cat = '';
  int sort = 0; // 0 by name, 1 biggest first, 2 smallest first

  @override
  Widget build(BuildContext context) {
    final s = widget.scholar;
    final cats = <String, int>{};
    for (final b in s.books) {
      if (b.catName.isNotEmpty) cats[b.catName] = (cats[b.catName] ?? 0) + 1;
    }
    final catList = cats.keys.toList()..sort((a, b) => cats[b]!.compareTo(cats[a]!));
    final nq = norm(q);
    var books = s.books.where((b) => (cat.isEmpty || b.catName == cat) && (nq.isEmpty || norm(b.name).contains(nq))).toList();
    if (sort == 1) books.sort((a, b) => b.pages.compareTo(a.pages));
    if (sort == 2) books.sort((a, b) => a.pages.compareTo(b.pages));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.short),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'الترتيب',
            icon: const Icon(Icons.sort_rounded),
            initialValue: sort,
            onSelected: (v) => setState(() => sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('حسب الاسم')),
              PopupMenuItem(value: 1, child: Text('الأكبر أولًا')),
              PopupMenuItem(value: 2, child: Text('الأصغر أولًا')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(children: [
              ScholarMark(s.short, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: TextStyle(fontFamily: bookFont, fontSize: 21, fontWeight: FontWeight.w700, height: 1.5, color: C.ink(context))),
                  Text('${s.deathText} · ${Ar.books(s.books.length)}', style: TextStyle(fontSize: 14, color: C.muted(context))),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن كتاب…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: C.card(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
              ),
            ),
          ),
          if (catList.length > 1)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                children: [
                  _chip('الكل', cat.isEmpty, () => setState(() => cat = '')),
                  for (final c in catList) _chip('$c (${Ar.num(cats[c]!)})', cat == c, () => setState(() => cat = c)),
                ],
              ),
            ),
          if (s.books.isEmpty)
            const EmptyNote(Icons.hourglass_empty_rounded, 'تُضاف كتب هذا العالم مع التحديث القادم بإذن الله.')
          else if (books.isEmpty)
            const EmptyNote(Icons.search_off_rounded, 'لا يوجد كتاب بهذا الاسم.')
          else
            for (final b in books) BookTile(b),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          onSelected: (_) => tap(),
          showCheckmark: false,
          shape: StadiumBorder(side: BorderSide(color: C.line(context))),
        ),
      );
}

class BookTile extends StatelessWidget {
  final BookInfo b;
  const BookTile(this.b, {super.key});
  @override
  Widget build(BuildContext context) {
    final read = Store.i.lastPg[b.id];
    return SoftCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => openBook(context, b),
      child: Row(children: [
        Container(
          width: 42,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [Color(0xFF1F5C4A), Color(0xFF2E7A62)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            border: Border.all(color: C.gold(context).withValues(alpha: 0.7)),
          ),
          child: Icon(Store.i.downloaded.contains(b.id) ? Icons.download_done_rounded : Icons.menu_book_rounded, color: const Color(0xFFF1DFA8), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.shortName, style: TextStyle(fontFamily: bookFont, fontSize: 17, fontWeight: FontWeight.w700, height: 1.5, color: C.ink(context))),
            const SizedBox(height: 2),
            Wrap(spacing: 6, runSpacing: 4, children: [
              Tag(b.vols > 1 ? '${Ar.num(b.vols)} مجلدات · ${Ar.pages(b.pages)}' : Ar.pages(b.pages)),
              if (b.edition.isNotEmpty) Tag(b.edition),
              if (read != null) Tag('وصلت ${Ar.num(read)}', color: C.gold(context)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
