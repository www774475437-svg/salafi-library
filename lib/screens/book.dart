import 'package:flutter/material.dart';

import '../catalog.dart';
import '../files/files.dart';
import '../store.dart';
import '../turath.dart';
import '../ui.dart';
import '../update.dart';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.shortName, style: TextStyle(fontFamily: bookFont, fontSize: 26, fontWeight: FontWeight.w700, height: 1.5, color: C.ink(context))),
                const SizedBox(height: 4),
                Text(b.scholar.name, style: TextStyle(fontSize: 15.5, color: C.accent(context), fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Tag(Ar.pages(b.pages)),
                  if (b.vols > 1) Tag('${Ar.num(b.vols)} مجلدات'),
                  if (b.edition.isNotEmpty) Tag(b.edition),
                  if (b.catName.isNotEmpty) Tag(b.catName),
                  if (isDown) Tag('محمّل بلا إنترنت', color: C.accent(context)),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: const StadiumBorder()),
                    onPressed: () => openReader(context, b, last ?? 1),
                    icon: const Icon(Icons.chrome_reader_mode_rounded),
                    label: Text(last == null ? 'ابدأ القراءة' : 'أكمل من ${Ar.num(last)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (BookFiles.supported) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: prog != null
                        ? Column(children: [
                            LinearProgressIndicator(value: prog > 0 ? prog : null, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 6),
                            Text(prog > 0 ? 'يُحمَّل ${Ar.num((prog * 100).round())}٪' : 'يبدأ التحميل…', style: TextStyle(fontSize: 13, color: C.muted(context))),
                          ])
                        : OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: const StadiumBorder()),
                            onPressed: isDown ? () => _askDelete(b) : () => startDownload(context, b),
                            icon: Icon(isDown ? Icons.download_done_rounded : Icons.download_rounded),
                            label: Text(isDown ? 'محمّل' : 'تحميل', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                  ),
                ],
              ]),
            ),
            if (!BookFiles.supported)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: InkWell(
                  onTap: () => openLink(apkUrl),
                  child: Text('للقراءة بلا إنترنت حمّل تطبيق أندرويد', style: TextStyle(fontSize: 13.5, color: C.accent(context), decoration: TextDecoration.underline)),
                ),
              ),
            if (b.info.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SoftCard(
                  onTap: () => setState(() => _infoOpen = !_infoOpen),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: C.accent(context)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('بطاقة الكتاب', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))),
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
                return TocList(ix, onOpen: (pg) => openReader(context, b, pg), shrink: true);
              },
            ),
          ]);
        },
      ),
    );
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
  const TocList(this.index, {super.key, required this.onOpen, this.shrink = false, this.current});

  @override
  Widget build(BuildContext context) {
    final hs = index.headings;
    Widget item(int i) {
      final h = hs[i];
      final on = current != null && index.headingAt(current!) == h;
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
