import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../files/files.dart';
import '../store.dart';
import '../text.dart';
import '../turath.dart';
import '../ui.dart';
import 'book.dart';
import 'search.dart';

void openReader(BuildContext context, BookInfo b, int pg) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(b, pg)));

/// A book that is not in the list (rare: a search result from another edition).
BookInfo bookOrStub(int id, String name, int authorId) {
  final b = Catalog.byId[id];
  if (b != null) return b;
  final s = Catalog.scholarOfAuthor(authorId) ?? Catalog.scholars.first;
  return BookInfo(id, name.isEmpty ? 'كتاب' : name, 0, 1, '', '', s);
}

/// The text to share or copy for a quote, in the channel layout.
String quoteText(BookInfo b, String text, String source) {
  final t = text.trim().replaceAll(RegExp(r'\s*\n\s*'), '\n');
  return '▪️ قال ${b.scholar.short} ${b.scholar.honorific}:\n\n«$t،.🪶»\n\n[📓${b.shortName} (صـ $source)]';
}

/// Paper colours: like the app, white, cream, night.
(Color, Color) paperColors(BuildContext context) {
  switch (Store.i.paper) {
    case 1:
      return (const Color(0xFFFFFEFA), const Color(0xFF1C1F1D));
    case 2:
      return (const Color(0xFFF4ECD8), const Color(0xFF3A2E1C));
    case 3:
      return (const Color(0xFF111412), const Color(0xFFD9D4C7));
    default:
      return (C.bg(context), C.ink(context));
  }
}

class ReaderScreen extends StatefulWidget {
  final BookInfo book;
  final int startPg;
  const ReaderScreen(this.book, this.startPg, {super.key});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pc;
  late int pg;
  BookIndex? index;
  bool indexFailed = false;
  final Map<int, Future<RawPage>> _futures = {};

  int get total => index?.count ?? (widget.book.pages > 0 ? widget.book.pages : 1);
  BookInfo get b => widget.book;

  @override
  void initState() {
    super.initState();
    pg = widget.startPg < 1 ? 1 : widget.startPg;
    _pc = PageController(initialPage: pg - 1);
    Store.i.readAt(b.id, pg);
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    try {
      final ix = await Turath.index(b.id);
      if (mounted) setState(() => index = ix);
    } catch (_) {
      if (mounted) setState(() => indexFailed = true);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<RawPage> pageFuture(int p) => _futures.putIfAbsent(p, () => Turath.page(b.id, p));

  void retry(int p) => setState(() => _futures.remove(p));

  void goTo(int p) {
    final t = p.clamp(1, total);
    _pc.jumpToPage(t - 1);
  }

  String label(int p) => index?.label(p) ?? Ar.num(p);
  String source(int p) => index?.source(p) ?? Ar.num(p);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final (paper, ink) = paperColors(context);
        final heading = index?.headingAt(pg);
        final marked = Store.i.isBookmarked(b.id, pg);
        return Scaffold(
          backgroundColor: paper,
          appBar: AppBar(
            backgroundColor: paper,
            foregroundColor: ink,
            titleSpacing: 0,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ink)),
              if (heading != null)
                Text(heading.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: ink.withValues(alpha: 0.6))),
            ]),
            actions: [
              IconButton(
                tooltip: marked ? 'إزالة الفاصلة' : 'ضع فاصلة هنا',
                icon: Icon(marked ? Icons.bookmark_rounded : Icons.bookmark_add_outlined, color: marked ? C.gold(context) : null),
                onPressed: () {
                  Store.i.toggleBookmark(b.id, pg, label(pg));
                  toast(context, marked ? 'أُزيلت الفاصلة' : 'وُضعت فاصلة عند ${label(pg)}');
                },
              ),
              IconButton(tooltip: 'الفهرس', icon: const Icon(Icons.format_list_bulleted_rounded), onPressed: _showToc),
              PopupMenuButton<String>(
                onSelected: _menu,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'search', child: ListTile(leading: Icon(Icons.search_rounded), title: Text('ابحث في الكتاب'))),
                  const PopupMenuItem(value: 'goto', child: ListTile(leading: Icon(Icons.numbers_rounded), title: Text('انتقل إلى صفحة'))),
                  const PopupMenuItem(value: 'look', child: ListTile(leading: Icon(Icons.text_fields_rounded), title: Text('الخط والعرض'))),
                  if (BookFiles.supported && !Store.i.downloaded.contains(b.id))
                    const PopupMenuItem(value: 'download', child: ListTile(leading: Icon(Icons.download_rounded), title: Text('حمّل الكتاب'))),
                  const PopupMenuItem(value: 'book', child: ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('صفحة الكتاب'))),
                ],
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: total,
                onPageChanged: (i) {
                  setState(() => pg = i + 1);
                  Store.i.readAt(b.id, pg);
                },
                itemBuilder: (context, i) => _Page(state: this, pg: i + 1, ink: ink),
              ),
            ),
            _bottomBar(context, paper, ink),
          ]),
        );
      },
    );
  }

  Widget _bottomBar(BuildContext context, Color paper, Color ink) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
        decoration: BoxDecoration(color: paper, border: Border(top: BorderSide(color: ink.withValues(alpha: 0.10)))),
        child: Row(children: [
          IconButton(
            tooltip: 'السابقة',
            icon: Icon(Icons.chevron_right_rounded, color: ink),
            onPressed: pg > 1 ? () => _pc.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut) : null,
          ),
          Expanded(
            child: total > 1
                ? Slider(
                    value: pg.toDouble().clamp(1.0, total.toDouble()),
                    min: 1,
                    max: total.toDouble(),
                    onChanged: (v) => setState(() => pg = v.round()),
                    onChangeEnd: (v) => goTo(v.round()),
                  )
                : const SizedBox(),
          ),
          InkWell(
            onTap: _askPage,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text('${label(pg)}\n${Ar.num(pg)} / ${Ar.num(total)}',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.4, color: ink.withValues(alpha: 0.75))),
            ),
          ),
          IconButton(
            tooltip: 'التالية',
            icon: Icon(Icons.chevron_left_rounded, color: ink),
            onPressed: pg < total ? () => _pc.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut) : null,
          ),
        ]),
      ),
    );
  }

  void _menu(String v) {
    switch (v) {
      case 'search':
        Navigator.push(context, MaterialPageRoute(builder: (_) => BookSearchScreen(b, onOpen: goTo)));
      case 'goto':
        _askPage();
      case 'look':
        showReadingLook(context);
      case 'download':
        startDownload(context, b);
      case 'book':
        openBook(context, b);
    }
  }

  void _showToc() {
    final ix = index;
    if (ix == null || ix.headings.isEmpty) {
      toast(context, indexFailed ? 'تعذّر فتح الفهرس، تأكّد من الإنترنت' : 'لا فهرس لهذا الكتاب');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.8,
        child: Column(children: [
          Text('الفهرس', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(c))),
          const SizedBox(height: 6),
          Expanded(
            child: TocList(ix, current: pg, onOpen: (p) {
              Navigator.pop(c);
              goTo(p);
            }),
          ),
        ]),
      ),
    );
  }

  Future<void> _askPage() async {
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
          onSubmitted: (s) => Navigator.pop(c, int.tryParse(_latin(s))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, int.tryParse(_latin(ctl.text))), child: const Text('انتقل')),
        ],
      ),
    );
    if (v != null) goTo(v);
  }

  static String _latin(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    return s.split('').map((c) {
      final i = ar.indexOf(c);
      return i >= 0 ? '$i' : c;
    }).join().trim();
  }
}

class _Page extends StatelessWidget {
  final _ReaderScreenState state;
  final int pg;
  final Color ink;
  const _Page({required this.state, required this.pg, required this.ink});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RawPage>(
      future: state.pageFuture(pg),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              EmptyNote(
                  Icons.wifi_off_rounded,
                  kIsWeb && !Turath.hosted.contains(state.b.id)
                      ? 'هذا الكتاب لم يُضف إلى الموقع بعد، ويُضاف قريبًا بإذن الله. ويمكنك قراءته الآن في تطبيق أندرويد.'
                      : 'تعذّر فتح الصفحة. تأكّد من الإنترنت، أو حمّل الكتاب ليُقرأ بلا إنترنت.'),
              TextButton(onPressed: () => state.retry(pg), child: const Text('حاول مرة أخرى')),
            ]),
          );
        }
        final st = Store.i;
        final pt = cleanPage(snap.data!.text, harakat: st.tashkeel);
        final base = TextStyle(fontFamily: st.readFont, fontSize: st.fontSize, height: st.readFont == 'Amiri' ? 2.0 : 1.9, color: ink);
        return Scrollbar(
          child: ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 30), children: [
            SelectableText.rich(
              TextSpan(children: _spans(context, pt, base)),
              textAlign: TextAlign.justify,
              contextMenuBuilder: (context, es) => _menu(context, es, pt),
            ),
            if (pt.foot.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: ink.withValues(alpha: 0.2), endIndent: 160),
              SelectableText(pt.foot,
                  style: TextStyle(fontFamily: st.readFont, fontSize: st.fontSize * 0.72, height: 1.8, color: ink.withValues(alpha: 0.8))),
            ],
            const SizedBox(height: 18),
            Center(child: Text(state.label(pg), style: TextStyle(fontSize: 13, color: ink.withValues(alpha: 0.5)))),
          ]),
        );
      },
    );
  }

  List<(int, int, int)> _hlRanges(PageText pt) {
    final out = <(int, int, int)>[];
    for (final h in Store.i.highlightsOn(state.b.id, pg)) {
      final r = locate(pt.body, h.text);
      if (r != null) out.add((r.$1, r.$2, h.color));
    }
    return out;
  }

  List<InlineSpan> _spans(BuildContext context, PageText pt, TextStyle base) {
    final text = pt.body;
    final hls = _hlRanges(pt);
    final cuts = <int>{0, text.length};
    for (final (a, b) in pt.titles) {
      cuts..add(a)..add(b);
    }
    for (final (a, b, _) in hls) {
      cuts..add(a)..add(b);
    }
    final points = cuts.where((x) => x >= 0 && x <= text.length).toList()..sort();
    final spans = <InlineSpan>[];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      if (b <= a) continue;
      final inTitle = pt.titles.any((t) => a >= t.$1 && b <= t.$2);
      int? color;
      for (final h in hls) {
        if (a >= h.$1 && b <= h.$2) color = h.$3;
      }
      spans.add(TextSpan(
        text: text.substring(a, b),
        style: base.copyWith(
          fontWeight: inTitle ? FontWeight.w700 : null,
          color: inTitle ? C.accent(context) : null,
          backgroundColor: color == null ? null : hlColors[color],
        ),
      ));
    }
    return spans;
  }

  Widget _menu(BuildContext context, EditableTextState es, PageText pt) {
    final v = es.textEditingValue;
    final sel = v.selection;
    final picked = sel.isValid && !sel.isCollapsed ? sel.textInside(v.text).trim() : '';
    final b = state.b;
    void done() {
      es.hideToolbar();
      es.userUpdateTextEditingValue(v.copyWith(selection: TextSelection.collapsed(offset: sel.end)), SelectionChangedCause.toolbar);
    }

    // a highlight under the selection can be removed
    Kept? under;
    if (sel.isValid) {
      for (final h in Store.i.highlightsOn(b.id, pg)) {
        final r = locate(pt.body, h.text);
        if (r != null && sel.start < r.$2 && sel.end > r.$1) under = h;
      }
    }
    final items = <ContextMenuButtonItem>[
      if (picked.isNotEmpty) ...[
        for (var c = 0; c < 3; c++)
          ContextMenuButtonItem(
            label: 'ظلّل ${hlNames[c]}',
            onPressed: () {
              Store.i.addHighlight(b.id, pg, picked, c, state.label(pg));
              done();
            },
          ),
        ContextMenuButtonItem(
          label: 'اقتبس',
          onPressed: () {
            Store.i.addQuote(b.id, pg, picked, state.label(pg));
            done();
            final t = quoteText(b, picked, state.source(pg));
            Share.share(t);
          },
        ),
        ContextMenuButtonItem(
          label: 'انسخ مع المصدر',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: quoteText(b, picked, state.source(pg))));
            done();
            toast(context, 'نُسخ النص مع المصدر');
          },
        ),
      ],
      if (under != null)
        ContextMenuButtonItem(
          label: 'أزل التظليل',
          onPressed: () {
            Store.i.remove(under!);
            done();
          },
        ),
      ...es.contextMenuButtonItems,
    ];
    return AdaptiveTextSelectionToolbar.buttonItems(anchors: es.contextMenuAnchors, buttonItems: items);
  }
}

/// Font size, font, paper colour and harakat.
void showReadingLook(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => ListenableBuilder(
      listenable: Store.i,
      builder: (c, _) {
        final st = Store.i;
        Widget paperChip(int v, String name, Color col) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                avatar: CircleAvatar(backgroundColor: col, radius: 9),
                label: Text(name),
                selected: st.paper == v,
                showCheckmark: false,
                onSelected: (_) => st.setSettings(paper: v),
              ),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(c))),
              Row(children: [
                const Text('أ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(value: st.fontSize, min: 15, max: 40, divisions: 25, label: Ar.num(st.fontSize.round()), onChanged: (v) => st.setSettings(fontSize: v)),
                ),
                const Text('أ', style: TextStyle(fontSize: 26)),
              ]),
              const SizedBox(height: 6),
              Text('الخط', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(c))),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Amiri', label: Text('أميري', style: TextStyle(fontFamily: 'Amiri', fontSize: 17))),
                  ButtonSegment(value: 'Tajawal', label: Text('تجوّل', style: TextStyle(fontFamily: 'Tajawal', fontSize: 15))),
                ],
                selected: {st.readFont},
                showSelectedIcon: false,
                onSelectionChanged: (s) => st.setSettings(readFont: s.first),
              ),
              const SizedBox(height: 14),
              Text('لون الصفحة', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(c))),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  paperChip(0, 'تلقائي', C.bg(c)),
                  paperChip(1, 'أبيض', const Color(0xFFFFFEFA)),
                  paperChip(2, 'ورقي', const Color(0xFFF4ECD8)),
                  paperChip(3, 'ليلي', const Color(0xFF111412)),
                ]),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار التشكيل'),
                value: st.tashkeel,
                onChanged: (v) => st.setSettings(tashkeel: v),
              ),
            ]),
          ),
        );
      },
    ),
  );
}
