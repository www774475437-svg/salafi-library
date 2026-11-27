import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../files/files.dart';
import '../store.dart';
import '../ui.dart';
import 'book.dart';
import 'colors.dart';
import 'more.dart' show ReadLaterList;
import 'extras.dart';
import 'reader.dart';
import 'scholar.dart' show BookTile;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int tab = 0;
  int color = -1; // highlight filter
  String topic = ''; // quotes filter

  String quoteQuery = '';
  String noteQuery = '';

  /// The quotes in the order chosen in «الترتيب», with a heading where the book or author changes.
  List<Widget> _quoteRows(List<Kept> list) {
    final s = Store.i;
    final sorted = [...list];
    switch (s.quoteSort) {
      case 1:
        sorted.sort((a, b) => a.at.compareTo(b.at));
      case 2:
        sorted.sort((a, b) {
          final c = (Catalog.byId[a.book]?.shortName ?? '').compareTo(Catalog.byId[b.book]?.shortName ?? '');
          return c != 0 ? c : b.at.compareTo(a.at);
        });
      case 3:
        sorted.sort((a, b) {
          final c = (Catalog.byId[a.book]?.scholar.name ?? '').compareTo(Catalog.byId[b.book]?.scholar.name ?? '');
          return c != 0 ? c : b.at.compareTo(a.at);
        });
      default:
        sorted.sort((a, b) => b.at.compareTo(a.at));
    }
    final out = <Widget>[];
    String? last;
    for (final q in sorted) {
      final key = switch (s.quoteSort) {
        2 => Catalog.byId[q.book]?.shortName ?? 'كتاب',
        3 => Catalog.byId[q.book]?.scholar.name ?? '',
        _ => null,
      };
      if (key != null && key != last) {
        last = key;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Text(key, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: C.ink(context))),
        ));
      }
      out.add(_KeptCard(q, kind: 1));
    }
    return out;
  }
  static const _tabs = ['المظلّلات', 'الاقتباسات', 'الفواصل', 'المحمّلة', 'قرأتُ', 'الملاحظات', 'سأقرؤه لاحقًا'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text('مكتبتي', style: TextStyle(fontFamily: bookFont, fontSize: 26, fontWeight: FontWeight.w700, color: C.ink(context))),
          ),
          SizedBox(
            height: 50,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), children: [
              for (var i = 0; i < _tabs.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text('${_tabs[i]} (${Ar.num(_count(i))})'),
                    selected: tab == i,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => tab = i),
                  ),
                ),
            ]),
          ),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  int _count(int i) {
    final s = Store.i;
    switch (i) {
      case 0:
        return s.highlights.length;
      case 1:
        return s.quotes.length;
      case 2:
        return s.bookmarks.length;
      case 3:
        return s.downloaded.length;
      case 5:
        return s.notes.length;
      case 6:
        return s.readLater.length;
      default:
        return s.recent.where(Catalog.byId.containsKey).length;
    }
  }

  Widget _body() {
    final s = Store.i;
    switch (tab) {
      case 0:
        final list = s.highlights.where((h) => (color < 0 || h.color == color) && (noteQuery.isEmpty || h.text.contains(noteQuery) || h.note.contains(noteQuery))).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 110), children: [
          TextField(
            decoration: const InputDecoration(hintText: 'ابحث في مظلّلاتك وملاحظاتها…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            onChanged: (v) => setState(() => noteQuery = v.trim()),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('الكل'), selected: color < 0, showCheckmark: false, onSelected: (_) => setState(() => color = -1)),
            for (var c = 0; c < s.colors.length; c++)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: hlSolid(c), radius: 8),
                label: Text(hlName(c)),
                selected: color == c,
                showCheckmark: false,
                onSelected: (_) => setState(() => color = c),
              ),
            ActionChip(
              avatar: const Icon(Icons.palette_outlined, size: 18),
              label: const Text('الألوان وأسماؤها'),
              onPressed: () => showColorsSheet(context),
            ),
          ]),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const EmptyNote(Icons.border_color_rounded, 'حدّد نصًّا وأنت تقرأ ثم اختر لونًا من الشريط الذي يظهر في الأسفل، فيظهر هنا تحت اسم لونه.')
          else if (color >= 0)
            for (final h in list) _KeptCard(h, kind: 0)
          else
            // everything, gathered under each book's name
            for (final bid in {for (final h in list) h.book}) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text('${Catalog.byId[bid]?.shortName ?? 'كتاب'} (${Ar.num(list.where((h) => h.book == bid).length)})',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: C.ink(context))),
              ),
              for (final h in list.where((h) => h.book == bid)) _KeptCard(h, kind: 0),
            ],
        ]);
      case 1:
        if (s.quotes.isEmpty) {
          return const EmptyNote(Icons.format_quote_rounded, 'حدّد نصًّا وأنت تقرأ ثم اختر «اقتباس»، فيُحفظ هنا مع مصدره وموضوعه لتنسخه أو تشاركه.');
        }
        final used = quoteTopics.where((t) => s.quotes.any((q) => q.topic == t)).toList();
        final shown = s.quotes.where((q) => topic.isEmpty || q.topic == topic).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 110), children: [
          if (used.isNotEmpty)
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('الكل'), selected: topic.isEmpty, showCheckmark: false, onSelected: (_) => setState(() => topic = '')),
              for (final t in used)
                ChoiceChip(
                  label: Text('$t (${Ar.num(s.quotes.where((q) => q.topic == t).length)})'),
                  selected: topic == t,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => topic = t),
                ),
            ]),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActionChip(
              avatar: const Icon(Icons.sort_rounded, size: 18),
              label: const Text('ترتيب'),
              onPressed: () => showSortSheet(context),
            ),
          ),
          TextField(
            decoration: const InputDecoration(hintText: 'ابحث في اقتباساتك…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            onChanged: (v) => setState(() => quoteQuery = v.trim()),
          ),
          const SizedBox(height: 8),
          ..._quoteRows(shown.where((q) => quoteQuery.isEmpty || q.text.contains(quoteQuery) || q.note.contains(quoteQuery)).toList()),
        ]);
      case 2:
        return s.bookmarks.isEmpty
            ? const EmptyNote(Icons.bookmark_border_rounded, 'اضغط علامة الفاصلة أعلى صفحة القراءة لتحفظ مكانك، فتظهر هنا.')
            : ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 110), children: [for (final b in s.bookmarks) _KeptCard(b, kind: 2)]);
      case 3:
        if (!BookFiles.supported) {
          return const EmptyNote(Icons.android_rounded, 'تحميل الكتب للقراءة بلا إنترنت في تطبيق أندرويد.');
        }
        final books = s.downloaded.map((id) => Catalog.byId[id]).whereType<BookInfo>().toList();
        return books.isEmpty
            ? const EmptyNote(Icons.download_rounded, 'لم تحمّل كتابًا بعد. افتح أي كتاب واضغط «تحميل» ليُقرأ ويُبحث فيه بلا إنترنت.')
            : ListView(padding: const EdgeInsets.only(top: 6, bottom: 110), children: [for (final b in books) BookTile(b)]);
      case 6:
        return const ReadLaterList();
      case 5:
        return s.notes.isEmpty
            ? const EmptyNote(Icons.sticky_note_2_outlined, 'حدّد نصًّا وأنت تقرأ ثم اضغط «ملاحظة» واكتب ما تريد، فتُحفظ هنا مع موضعها في الكتاب.')
            : ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 110), children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'ابحث في ملاحظاتك…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                  onChanged: (v) => setState(() => noteQuery = v.trim()),
                ),
                const SizedBox(height: 8),
                for (final n in s.notes.where((n) => noteQuery.isEmpty || n.text.contains(noteQuery) || n.note.contains(noteQuery))) _KeptCard(n, kind: 3),
              ]);
      default:
        final books = s.recent.map((id) => Catalog.byId[id]).whereType<BookInfo>().toList();
        return books.isEmpty
            ? const EmptyNote(Icons.history_rounded, 'الكتب التي تفتحها تظهر هنا.')
            : ListView(padding: const EdgeInsets.only(top: 6, bottom: 110), children: [for (final b in books) BookTile(b)]);
    }
  }
}

class _KeptCard extends StatelessWidget {
  final Kept k;
  final int kind; // 0 highlight, 1 quote, 2 bookmark
  const _KeptCard(this.k, {required this.kind});

  @override
  Widget build(BuildContext context) {
    final book = Catalog.byId[k.book];
    final name = book?.shortName ?? 'كتاب';
    final src = k.label.replaceAll('ج', '').replaceAll(' ص', '/').replaceAll('ص', '');
    final share = book == null ? k.text : quoteText(book, k.text, src);
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: book == null ? null : () => openReader(context, book, k.pg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (kind == 2)
          Row(children: [
            Icon(Icons.bookmark_rounded, color: C.gold(context)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: TextStyle(fontFamily: bookFont, fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context)))),
          ])
        else
          Container(
            padding: kind == 0 ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : EdgeInsets.zero,
            decoration: kind == 0 ? BoxDecoration(color: hlColor(k.color), borderRadius: BorderRadius.circular(6)) : null,
            child: Text(kind == 1 || kind == 3 ? '«${k.text}»' : k.text, style: TextStyle(fontFamily: bookFont, fontSize: 18, height: 1.8, color: C.ink(context))),
          ),
        if (k.note.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C.accent(context).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.sticky_note_2_outlined, size: 18, color: C.accent(context)),
              const SizedBox(width: 8),
              Expanded(child: Text(k.note, style: TextStyle(fontSize: 15, height: 1.6, color: C.ink(context)))),
            ]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(kind == 2 ? '${k.label} · ${book?.scholar.short ?? ''}' : '$name · ${k.label}',
                style: TextStyle(fontSize: 13, color: C.muted(context))),
          ),
          if (kind != 2) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: Store.i.isReview(k.id) ? 'أخرجه من المراجعة' : 'احفظ للمراجعة',
              icon: Icon(Icons.autorenew_rounded, size: 20, color: Store.i.isReview(k.id) ? C.accent(context) : null),
              onPressed: () {
                Store.i.toggleReview(k);
                toast(context, Store.i.isReview(k.id) ? 'حُفظ للمراجعة، ستجده في «احفظ وراجِع»' : 'أُخرج من المراجعة');
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'انسخ مع المصدر',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: share));
                toast(context, 'نُسخ مع المصدر');
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'شارك',
              icon: const Icon(Icons.share_rounded, size: 20),
              onPressed: () => Share.share(share),
            ),
          ],
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'احذف',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  content: const Text('تحذفه من مكتبتك؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('احذف')),
                  ],
                ),
              );
              if (ok == true) Store.i.remove(k);
            },
          ),
        ]),
        if (book != null && kind != 2)
          Wrap(spacing: 4, children: [
            TextButton.icon(
              onPressed: () => openBook(context, book),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('صفحة الكتاب'),
            ),
            if (kind == 1)
              TextButton.icon(
                onPressed: () async {
                  final t = await pickTopic(context, current: k.topic);
                  if (t != null) Store.i.setTopic(k, t);
                },
                icon: const Icon(Icons.label_outline_rounded, size: 18),
                label: Text(k.topic.isEmpty ? 'اختر موضوعًا' : k.topic),
              ),
          ]),
      ]),
    );
  }
}
