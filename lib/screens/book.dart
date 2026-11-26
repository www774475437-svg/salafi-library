import 'package:flutter/material.dart';

import '../catalog.dart';
import '../files/files.dart';
import '../store.dart';
import '../turath.dart';
import '../ui.dart';
import '../update.dart';
import 'pdf.dart';
import 'reader.dart';
import 'search.dart';

void openBook(BuildContext context, BookInfo b) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => BookScreen(b)));

/// Downloads in progress, so the progress shows wherever the book appears.
final downloads = ValueNotifier<Map<int, double>>({});

Future<void> startDownload(BuildContext context, BookInfo b) async {
  if (downloads.value.containsKey(b.id)) return;
  downloads.value = {...downloads.value, b.id: 0};
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Turath.download(b.id, (p) => downloads.value = {...downloads.value, b.id: p});
    messenger.showSnackBar(SnackBar(content: Text('حُمِّل «${b.shortName}» للقراءة بلا إنترنت')));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('تعذّر التحميل، تأكّد من الإنترنت وحاول مرة أخرى')));
  } finally {
    downloads.value = Map.of(downloads.value)..remove(b.id);
  }
}

class BookScreen extends StatefulWidget {
  final BookInfo book;
  const BookScreen(this.book, {super.key});
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  late Future<BookIndex> _index;
  bool _infoOpen = false;

  @override
  void initState() {
    super.initState();
    _index = Turath.index(widget.book.id);
  }

  void _retry() => setState(() => _index = Turath.index(widget.book.id));

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    return Scaffold(
      appBar: AppBar(title: Text(b.scholar.short), actions: [
        IconButton(
          tooltip: 'ابحث في الكتاب',
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookSearchScreen(b))),
        ),
      ]),
      body: ListenableBuilder(
        listenable: Listenable.merge([Store.i, downloads]),
        builder: (context, _) {
          final last = Store.i.lastPg[b.id];
          final isDown = Store.i.downloaded.contains(b.id);
          final prog = downloads.value[b.id];
          return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            _Hero(b, isDown: isDown),
            // the main buttons, all in one clear place
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()),
                onPressed: () => openReader(context, b, last ?? 1),
                icon: const Icon(Icons.auto_stories_rounded),
                label: Text(last == null ? 'ابدأ القراءة' : 'أكمل القراءة من صفحة ${Ar.num(last)}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            if (last != null && b.pages > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: (last / b.pages).clamp(0.0, 1.0), minHeight: 6, backgroundColor: C.soft(context), color: C.gold(context)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('قرأتَ ${Ar.num(((Store.i.pagesRead.containsKey(b.id) ? Store.i.readShare(b.id, b.pages) : (last / b.pages).clamp(0.0, 1.0)) * 100).round())}٪', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.muted(context))),
                ]),
              ),
            FutureBuilder<BookIndex>(
              future: _index,
              builder: (context, snap) {
                final ix = snap.data;
                final tiles = <Widget>[
                  _Action(Icons.manage_search_rounded, 'ابحث في الكتاب', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookSearchScreen(b)))),
                  _Action(Icons.numbers_rounded, 'انتقل إلى صفحة', () => _askPage(b, ix)),
                  if (ix != null && ix.pdfs.isNotEmpty)
                    _Action(Icons.picture_as_pdf_rounded, 'النسخة المصوّرة PDF', () => openPdf(context, b, ix, last ?? 1)),
                  if (BookFiles.supported)
                    prog != null
                        ? _Action(Icons.downloading_rounded, prog > 0 ? 'يُحمَّل ${Ar.num((prog * 100).round())}٪' : 'يبدأ التحميل…', null, progress: prog)
                        : _Action(isDown ? Icons.download_done_rounded : Icons.download_rounded, isDown ? 'محمّل بلا إنترنت' : 'حمّل للقراءة بلا إنترنت',
                            isDown ? () => _askDelete(b) : () => startDownload(context, b))
                  else
                    _Action(Icons.android_rounded, 'بلا إنترنت في تطبيق أندرويد', () => openLink(apkUrl)),
                  Store.i.readLater.contains(b.id)
                      ? _Action(Icons.watch_later_rounded, 'في قائمة «سأقرؤه لاحقًا»', () => Store.i.toggleLater(b.id))
                      : _Action(Icons.watch_later_outlined, 'سأقرؤه لاحقًا', () => Store.i.toggleLater(b.id)),
                ];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: LayoutBuilder(builder: (context, c) {
                    final w = (c.maxWidth - 10) / 2;
                    return Wrap(spacing: 10, runSpacing: 10, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
                  }),
                );
              },
            ),
            if (b.info.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SoftCard(
                  onTap: () => setState(() => _infoOpen = !_infoOpen),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: C.accent(context)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('بطاقة الكتاب (المحقق والطبعة)', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))),
                      Icon(_infoOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.muted(context)),
                    ]),
                    if (_infoOpen) ...[
                      const SizedBox(height: 8),
                      Text(b.info, style: TextStyle(fontSize: 14.5, height: 1.7, color: C.ink(context))),
                    ],
                  ]),
                ),
              ),
            const SectionTitle('الفهرس'),
            FutureBuilder<BookIndex>(
              future: _index,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError || snap.data == null) {
                  return Column(children: [
                    const EmptyNote(Icons.wifi_off_rounded, 'تعذّر فتح الفهرس. تأكّد من الإنترنت، أو حمّل الكتاب ليُقرأ بلا إنترنت.'),
                    TextButton(onPressed: _retry, child: const Text('حاول مرة أخرى')),
                  ]);
                }
                final ix = snap.data!;
                if (ix.headings.isEmpty) return const EmptyNote(Icons.list_alt_rounded, 'لا فهرس لهذا الكتاب.');
                return TocTree(ix, onOpen: (pg) => openReader(context, b, pg));
              },
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _askPage(BookInfo b, BookIndex? ix) async {
    final total = ix?.count ?? b.pages;
    final ctl = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('انتقل إلى صفحة'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'من ١ إلى ${Ar.num(total)}'),
          onSubmitted: (s) => Navigator.pop(c, int.tryParse(latinDigits(s))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, int.tryParse(latinDigits(ctl.text))), child: const Text('انتقل')),
        ],
      ),
    );
    if (v != null && mounted) openReader(context, b, v.clamp(1, total < 1 ? 1 : total));
  }

  Future<void> _askDelete(BookInfo b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف التحميل؟'),
        content: Text('سيُحذف «${b.shortName}» من الجهاز، ويبقى يُقرأ مع الإنترنت. فواصلك ومظلّلاتك تبقى كما هي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('احذف')),
        ],
      ),
    );
    if (ok == true) await Turath.removeDownload(b.id);
  }
}

/// The table of contents, indented by level.
class TocList extends StatelessWidget {
  final BookIndex index;
  final void Function(int pg) onOpen;
  final bool shrink;
  final int? current;
  /// With [bookId] and [pages], each chapter shows the share of it marked as read.
  final int? bookId;
  final int pages;
  const TocList(this.index, {super.key, required this.onOpen, this.shrink = false, this.current, this.bookId, this.pages = 0});

  @override
  Widget build(BuildContext context) {
    final hs = index.headings;
    Widget item(int i) {
      final h = hs[i];
      final on = current != null && index.headingAt(current!) == h;
      double? share;
      if (bookId != null && pages > 0) {
        final end = i + 1 < hs.length ? hs[i + 1].pg : pages + 1;
        final span = end - h.pg;
        final marked = (Store.i.pagesRead[bookId] ?? const <int>{}).where((p) => p >= h.pg && p < end).length;
        if (span > 0 && marked > 0) share = (marked / span).clamp(0.0, 1.0);
      }
      return InkWell(
        onTap: () => onOpen(h.pg),
        child: Container(
          color: on ? C.accent(context).withValues(alpha: 0.10) : null,
          padding: EdgeInsetsDirectional.fromSTEB(20.0 + (h.level - 1).clamp(0, 4) * 18, 11, 20, 11),
          child: Row(children: [
            Expanded(
              child: Text(h.title,
                  style: TextStyle(
                      fontFamily: bookFont,
                      fontSize: h.level <= 1 ? 17 : 15.5,
                      height: 1.5,
                      fontWeight: h.level <= 1 ? FontWeight.w700 : FontWeight.w400,
                      color: on ? C.accent(context) : C.ink(context))),
            ),
            const SizedBox(width: 10),
            if (share != null)
              Text('${Ar.num((share * 100).round())}٪  ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.accent(context))),
            Text(index.label(h.pg), style: TextStyle(fontSize: 12.5, color: C.muted(context))),
          ]),
        ),
      );
    }

    if (shrink) {
      // long tables of contents are cut into chunks so the page stays quick
      final n = hs.length > 600 ? 600 : hs.length;
      return Column(children: [
        for (var i = 0; i < n; i++) item(i),
        if (hs.length > n)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('… وبقية الفهرس داخل القارئ (زر الفهرس)', style: TextStyle(color: C.muted(context))),
          ),
      ]);
    }
    final start = current == null ? 0 : hs.indexWhere((h) => index.headingAt(current!) == h);
    return ListView.builder(
      controller: ScrollController(initialScrollOffset: start > 3 ? (start - 3) * 52.0 : 0),
      itemCount: hs.length,
      itemBuilder: (_, i) => item(i),
    );
  }
}


String latinDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  return s.split('').map((c) {
    final i = ar.indexOf(c);
    return i >= 0 ? '$i' : c;
  }).join().trim();
}

/// The top of the book page: a small «cover» with the title, author and details.
class _Hero extends StatelessWidget {
  final BookInfo b;
  final bool isDown;
  const _Hero(this.b, {required this.isDown});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 92,
          height: 128,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(4), bottomStart: Radius.circular(4), topEnd: Radius.circular(12), bottomEnd: Radius.circular(12)),
            gradient: const LinearGradient(colors: [Color(0xFF23466E), Color(0xFF2F5F94)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            border: Border.all(color: C.gold(context), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF1DFA8).withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.all(4),
            child: Text(b.shortName, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: bookFont, fontSize: 12.5, height: 1.5, color: Color(0xFFF1DFA8), fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.shortName, style: TextStyle(fontFamily: bookFont, fontSize: 23, fontWeight: FontWeight.w700, height: 1.45, color: C.ink(context))),
            const SizedBox(height: 2),
            Text(b.scholar.name, style: TextStyle(fontSize: 15, color: C.accent(context), fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Tag(Ar.pages(b.pages)),
              if (b.vols > 1) Tag('${Ar.num(b.vols)} مجلدات'),
              if (b.edition.isNotEmpty) Tag(b.edition),
              if (b.catName.isNotEmpty) Tag(b.catName),
              if (isDown) Tag('محمّل', color: C.accent(context)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double? progress;
  const _Action(this.icon, this.label, this.onTap, {this.progress});
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: C.accent(context).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: progress != null
              ? Padding(padding: const EdgeInsets.all(9), child: CircularProgressIndicator(value: progress! > 0 ? progress : null, strokeWidth: 2.6))
              : Icon(icon, size: 21, color: C.accent(context)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, maxLines: 2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.35, color: C.ink(context)))),
      ]),
    );
  }
}

/// The table of contents as chapters that open and close.
class TocTree extends StatefulWidget {
  final BookIndex index;
  final void Function(int pg) onOpen;
  const TocTree(this.index, {super.key, required this.onOpen});
  @override
  State<TocTree> createState() => _TocTreeState();
}

class _TocTreeState extends State<TocTree> {
  final Set<int> _open = {};

  @override
  Widget build(BuildContext context) {
    final hs = widget.index.headings;
    final top = hs.map((h) => h.level).reduce((a, b) => a < b ? a : b);
    // chapters: each top-level heading with the headings under it
    final groups = <(int, List<int>)>[];
    for (var i = 0; i < hs.length; i++) {
      if (hs[i].level == top || groups.isEmpty) {
        groups.add((i, <int>[]));
      } else {
        groups.last.$2.add(i);
      }
    }
    final allOpen = hs.length <= 30;
    Widget row(int i, {bool chapter = false, int? kids, bool open = false, VoidCallback? toggle}) {
      final h = hs[i];
      return InkWell(
        onTap: () => widget.onOpen(h.pg),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(chapter ? 16 : 24.0 + (h.level - top - 1).clamp(0, 3) * 16, chapter ? 12 : 9, 8, chapter ? 12 : 9),
          child: Row(children: [
            if (!chapter) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Icon(Icons.circle, size: 5, color: C.gold(context))),
            Expanded(
              child: Text(h.title,
                  style: TextStyle(
                      fontFamily: bookFont,
                      fontSize: chapter ? 17.5 : 15.5,
                      height: 1.5,
                      fontWeight: chapter ? FontWeight.w700 : FontWeight.w400,
                      color: C.ink(context))),
            ),
            const SizedBox(width: 8),
            Text(widget.index.label(h.pg), style: TextStyle(fontSize: 12.5, color: C.muted(context))),
            if (kids != null && kids > 0)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: open ? 'إغلاق' : 'فتح (${Ar.num(kids)})',
                icon: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.accent(context)),
                onPressed: toggle,
              )
            else if (chapter)
              const SizedBox(width: 40),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        for (final (head, kids) in groups.take(400))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                row(head,
                    chapter: true,
                    kids: kids.length,
                    open: allOpen || _open.contains(head),
                    toggle: () => setState(() => _open.contains(head) ? _open.remove(head) : _open.add(head))),
                if ((allOpen || _open.contains(head)) && kids.isNotEmpty) ...[
                  Divider(height: 1, color: C.line(context)),
                  for (final k in kids.take(300)) row(k),
                  const SizedBox(height: 6),
                ],
              ]),
            ),
          ),
      ]),
    );
  }
}
