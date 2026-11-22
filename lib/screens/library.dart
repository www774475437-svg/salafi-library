import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../files/files.dart';
import '../store.dart';
import '../ui.dart';
import 'book.dart';
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

  static const _tabs = ['المظلّلات', 'الاقتباسات', 'الفواصل', 'المحمّلة', 'قرأتُ'];

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
      default:
        return s.recent.where(Catalog.byId.containsKey).length;
    }
  }

  Widget _body() {
    final s = Store.i;
    switch (tab) {
      case 0:
        final list = s.highlights.where((h) => color < 0 || h.color == color).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 110), children: [
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('الكل'), selected: color < 0, showCheckmark: false, onSelected: (_) => setState(() => color = -1)),
            for (var c = 0; c < 3; c++)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: hlColors[c].withValues(alpha: 1), radius: 8),
                label: Text(hlNames[c]),
                selected: color == c,
                showCheckmark: false,
                onSelected: (_) => setState(() => color = c),
              ),
          ]),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const EmptyNote(Icons.border_color_rounded, 'حدّد نصًّا وأنت تقرأ ثم اختر «ظلّل» بالأصفر أو الأحمر أو الأخضر، فيظهر هنا.')
          else
            for (final h in list) _KeptCard(h, kind: 0),
        ]);
      case 1:
        return s.quotes.isEmpty
            ? const EmptyNote(Icons.format_quote_rounded, 'حدّد نصًّا وأنت تقرأ ثم اختر «اقتبس»، فيُحفظ هنا مع مصدره لتنسخه أو تشاركه.')
            : ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 110), children: [for (final q in s.quotes) _KeptCard(q, kind: 1)]);
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
            decoration: kind == 0 ? BoxDecoration(color: hlColors[k.color], borderRadius: BorderRadius.circular(6)) : null,
            child: Text(kind == 1 ? '«${k.text}»' : k.text, style: TextStyle(fontFamily: bookFont, fontSize: 18, height: 1.8, color: C.ink(context))),
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
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => openBook(context, book),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('صفحة الكتاب'),
            ),
          ),
      ]),
    );
  }
}
