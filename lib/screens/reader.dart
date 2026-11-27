import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../screen.dart';
import '../files/files.dart';
import 'dart:async';

import '../store.dart';
import '../text.dart';
import '../turath.dart';
import '../ui.dart';
import 'book.dart';
import 'colors.dart';
import 'dict.dart';
import 'pdf.dart';
import 'quote_image.dart';
import 'report.dart';
import 'search.dart';

/// With [find] and [hits] (the pages holding it), the reader colours the words and steps between their places.
void openReader(BuildContext context, BookInfo b, int pg, {String find = '', List<int> hits = const []}) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(b, pg, find: find, hits: hits)));

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
  if (b.scholar.collection) return '«$t،.🪶»\n\n[📓${b.shortName} (صـ $source)]';
  return '▪️ قال ${b.scholar.short} ${b.scholar.honorific}:\n\n«$t،.🪶»\n\n[📓${b.shortName} (صـ $source)]';
}

/// Asks which subject a quote goes under. '' = none, null = cancelled.
Future<String?> pickTopic(BuildContext context, {String current = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('موضوع الاقتباس', style: TextStyle(fontFamily: bookFont, fontSize: 21, fontWeight: FontWeight.w700, color: C.ink(c))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final t in quoteTopics)
              ChoiceChip(label: Text(t), selected: t == current, showCheckmark: false, onSelected: (_) => Navigator.pop(c, t)),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: () => Navigator.pop(c, ''), child: const Text('بلا موضوع')),
          ),
        ]),
      ),
    ),
  );
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
  final String find;
  final List<int> hits;
  const ReaderScreen(this.book, this.startPg, {super.key, this.find = '', this.hits = const []});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static bool _warnedSmall = false;
  final DateTime _opened = DateTime.now();
  Timer? _tick;
  Timer? _sleep;
  String find = ''; // the searched words, coloured in the pages
  List<int> findPages = const []; // the pages that hold them
  PageController _pc = PageController();
  final _flowCtl = ItemScrollController();
  final _flowPos = ItemPositionsListener.create();
  int _modeShown = -1;

  // the text the reader has selected (the bar at the bottom acts on it)
  String selText = '';
  String selBody = '';
  int selPg = 0, selStart = 0, selEnd = 0;
  int selEpoch = 0;

  void onSelect(int p, String body, int a, int e) {
    final t = a < e ? body.substring(a, e).trim() : '';
    if (t.isEmpty && (selText.isEmpty || selPg != p)) return;
    if (t == selText && p == selPg) return;
    setState(() {
      selText = t;
      selBody = body;
      selPg = p;
      selStart = a;
      selEnd = e;
    });
  }

  /// Ends the selection (the page text is rebuilt, which removes the handles).
  void clearSel() => setState(() {
        selText = '';
        selEpoch++;
      });

  /// A highlight lying under the selected words, if any.
  Kept? get _under {
    for (final h in Store.i.highlightsOn(b.id, selPg)) {
      final r = locate(selBody, h.text);
      if (r != null && selStart < r.$2 && selEnd > r.$1) return h;
    }
    return null;
  }
  late int pg;
  BookIndex? index;
  bool indexFailed = false;
  final Map<int, Future<RawPage>> _futures = {};

  int get total => index?.count ?? (widget.book.pages > 0 ? widget.book.pages : 1);
  BookInfo get b => widget.book;

  @override
  void initState() {
    super.initState();
    // refreshes the minutes shown for this session
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // once per opening: small text on a small screen is easy to miss
      if (!mounted || _warnedSmall) return;
      if (MediaQuery.sizeOf(context).width < 380 && Store.i.fontSize < 19) {
        _warnedSmall = true;
        toast(context, 'النص صغير على هذه الشاشة. يمكنك تكبيره من الإعدادات أو من شريط الخط');
      }
    });
    pg = widget.startPg < 1 ? 1 : widget.startPg;
    find = widget.find;
    findPages = widget.hits.toSet().toList()..sort();
    _pc = PageController(initialPage: pg - 1);
    _modeShown = Store.i.readMode;
    _flowPos.itemPositions.addListener(_flowMoved);
    Store.i.readAt(b.id, pg);
    _loadIndex();
    Screen.keepOn(Store.i.keepOn);
    final sleepIn = Store.i.sleepMinutes;
    if (sleepIn > 0) {
      // the screen is allowed to sleep after the chosen time; the phone's own settings decide how
      _sleep = Timer(Duration(minutes: sleepIn), () {
        if (!mounted) return;
        Screen.keepOn(false);
        toast(context, 'انتهى مؤقت القراءة، ويمكن أن تنطفئ الشاشة الآن');
      });
    }
    if (Store.i.volKeys) Screen.volumeKeys(_step);
  }

  /// In the continuous text, the page at the top of the screen is the page being read.
  void _flowMoved() {
    if (Store.i.readMode != 1) return;
    final ps = _flowPos.itemPositions.value.where((p) => p.itemTrailingEdge > 0.15);
    if (ps.isEmpty) return;
    final first = ps.map((p) => p.index).reduce((a, b) => a < b ? a : b) + 1;
    if (first != pg && mounted) {
      setState(() => pg = first);
      Store.i.readAt(b.id, pg);
    }
  }

  void setMode(int m) {
    if (m == Store.i.readMode) return;
    if (m == 0) {
      _pc.dispose();
      _pc = PageController(initialPage: pg - 1);
    }
    _modeShown = m;
    Store.i.setSettings(readMode: m);
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
    _tick?.cancel();
    _sleep?.cancel();
    Screen.keepOn(false);
    Screen.volumeKeys(null);
    _flowPos.itemPositions.removeListener(_flowMoved);
    _pc.dispose();
    super.dispose();
  }

  Future<RawPage> pageFuture(int p) => _futures.putIfAbsent(p, () => Turath.page(b.id, p));

  void retry(int p) => setState(() => _futures.remove(p));

  void goTo(int p) {
    final t = p.clamp(1, total);
    if (Store.i.readMode == 1) {
      if (_flowCtl.isAttached) _flowCtl.jumpTo(index: t - 1);
      setState(() => pg = t);
      Store.i.readAt(b.id, t);
    } else {
      _pc.jumpToPage(t - 1);
    }
  }

  void _step(int d) {
    if (Store.i.readMode == 1) {
      goTo(pg + d);
    } else if (d > 0) {
      _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _pc.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  /// The bar that steps between the places of the searched words.
  Widget _findBar(Color ink) {
    final at = findPages.indexOf(pg);
    final next = findPages.where((p) => p > pg);
    final prev = findPages.where((p) => p < pg);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 4, 0),
      decoration: BoxDecoration(color: const Color(0x33FFC107), border: Border(bottom: BorderSide(color: ink.withValues(alpha: 0.12)))),
      child: Row(children: [
        Expanded(
          child: Text(
            findPages.isEmpty
                ? '«$find»'
                : at >= 0
                    ? '«$find» · الموضع ${Ar.num(at + 1)} من ${Ar.num(findPages.length)}'
                    : '«$find» · ${Ar.num(findPages.length)} موضعًا',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
          ),
        ),
        IconButton(tooltip: 'الموضع السابق', icon: const Icon(Icons.keyboard_arrow_up_rounded), color: ink, onPressed: prev.isEmpty ? null : () => goTo(prev.last)),
        IconButton(tooltip: 'الموضع التالي', icon: const Icon(Icons.keyboard_arrow_down_rounded), color: ink, onPressed: next.isEmpty ? null : () => goTo(next.first)),
        IconButton(tooltip: 'أخفِ', icon: const Icon(Icons.close_rounded, size: 20), color: ink, onPressed: () => setState(() => find = '')),
      ]),
    );
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
                tooltip: 'انسخ عنوان الباب',
                icon: const Icon(Icons.content_copy_outlined),
                onPressed: heading == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: '${b.shortName}: ${heading.title}'));
                        toast(context, 'نُسخ عنوان الباب مع اسم الكتاب');
                      },
              ),
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
                  const PopupMenuItem(value: 'pagenote', child: ListTile(leading: Icon(Icons.sticky_note_2_outlined), title: Text('ملاحظة على الصفحة'))),
                  if (index != null && index!.pdfs.isNotEmpty)
                    const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_rounded), title: Text('النسخة المصوّرة PDF'))),
                  const PopupMenuItem(value: 'look', child: ListTile(leading: Icon(Icons.text_fields_rounded), title: Text('الخط والعرض'))),
                  if (BookFiles.supported && !Store.i.downloaded.contains(b.id))
                    const PopupMenuItem(value: 'download', child: ListTile(leading: Icon(Icons.download_rounded), title: Text('حمّل الكتاب'))),
                  const PopupMenuItem(value: 'book', child: ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('صفحة الكتاب'))),
                  const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('أبلغ عن خطأ'))),
                ],
              ),
            ],
          ),
          body: Column(children: [
            if (find.isNotEmpty) _findBar(ink),
            Expanded(
              child: Store.i.readMode == 1
                  ? ScrollablePositionedList.builder(
                      key: ValueKey('flow$_modeShown'),
                      itemScrollController: _flowCtl,
                      itemPositionsListener: _flowPos,
                      initialScrollIndex: pg - 1,
                      itemCount: total,
                      itemBuilder: (context, i) => _Page(state: this, pg: i + 1, ink: ink, flow: true),
                    )
                  : PageView.builder(
                      key: ValueKey('pages$_modeShown'),
                      controller: _pc,
                      itemCount: total,
                      onPageChanged: (i) {
                        setState(() {
                          pg = i + 1;
                          selText = '';
                        });
                        Store.i.readAt(b.id, pg);
                      },
                      itemBuilder: (context, i) => _Page(state: this, pg: i + 1, ink: ink),
                    ),
            ),
            selText.isNotEmpty ? _selBar(context, paper, ink) : _bottomBar(context, paper, ink),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _modeChip(context, ink, Icons.auto_stories_rounded, 'كالكتاب', Store.i.readMode == 0, () => setMode(0)),
              _modeChip(context, ink, Icons.view_day_rounded, 'نص متصل', Store.i.readMode == 1, () => setMode(1)),
              if (index != null && index!.pdfs.isNotEmpty)
                _modeChip(context, ink, Icons.picture_as_pdf_rounded, 'المصوّر PDF', false, () => openPdf(context, b, index!, pg)),
            ]),
          ),
          Row(children: [
          IconButton(
            tooltip: 'السابقة',
            icon: Icon(Icons.chevron_right_rounded, color: ink),
            onPressed: pg > 1 ? () => _step(-1) : null,
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
              child: Text('${label(pg)}\n${Ar.num(pg)} / ${Ar.num(total)}\n${Ar.num(DateTime.now().difference(_opened).inMinutes)} د في هذه الجلسة',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.4, color: ink.withValues(alpha: 0.75))),
            ),
          ),
          IconButton(
            tooltip: Store.i.isPageRead(b.id, pg) ? 'أزل علامة القراءة' : 'علّمتُ هذه الصفحة مقروءة',
            icon: Icon(Store.i.isPageRead(b.id, pg) ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                color: Store.i.isPageRead(b.id, pg) ? C.accent(context) : ink.withValues(alpha: 0.6)),
            onPressed: () {
              Store.i.togglePageRead(b.id, pg);
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'التالية',
            icon: Icon(Icons.chevron_left_rounded, color: ink),
            onPressed: pg < total ? () => _step(1) : null,
          ),
        ]),
        ]),
      ),
    );
  }

  /// The bar that appears when words are selected: colours, copy, quote, share, note.
  Widget _selBar(BuildContext context, Color paper, Color ink) {
    final st = Store.i;
    final src = source(selPg);
    final lab = label(selPg);
    final text = selText;
    final under = _under;
    Widget item(Widget top, String name, VoidCallback tap) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: tap,
          child: SizedBox(
            width: 62,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: 34, child: Center(child: top)),
              const SizedBox(height: 3),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: ink.withValues(alpha: 0.75))),
            ]),
          ),
        );
    Widget ico(IconData i) => Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ink.withValues(alpha: 0.25))),
          child: Icon(i, size: 18, color: C.accent(context)),
        );
    Widget sep() => Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 4), color: ink.withValues(alpha: 0.12));
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: paper, border: Border(top: BorderSide(color: C.gold(context).withValues(alpha: 0.5)))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var c = 0; c < st.colors.length; c++)
              item(
                Container(width: 30, height: 30, decoration: BoxDecoration(color: hlSolid(c), shape: BoxShape.circle, border: Border.all(color: Colors.black12))),
                hlName(c),
                () {
                  st.addHighlight(b.id, selPg, text, c, lab);
                  clearSel();
                },
              ),
            item(ico(Icons.palette_outlined), 'الألوان', () => showColorsSheet(context)),
            if (under != null)
              item(ico(Icons.format_color_reset_rounded), 'أزل التظليل', () {
                st.remove(under);
                clearSel();
              }),
            sep(),
            if (text.contains('﴿'))
              item(ico(Icons.auto_stories_outlined), 'انسخ الآية', () {
                // the ayah with its marks and number: text between ﴿ and ﴾
                final ayat = RegExp('﴿[^﴾]*﴾').allMatches(text).map((m) => m.group(0)!).join(' ');
                Clipboard.setData(ClipboardData(text: quoteText(b, ayat, src)));
                clearSel();
                toast(context, 'نُسخت الآية مع تشكيلها ورقمها ومصدرها');
              }),
            item(ico(Icons.copy_rounded), 'نسخ', () {
              Clipboard.setData(ClipboardData(text: text));
              clearSel();
              toast(context, 'نُسخ النص');
            }),
            item(ico(Icons.library_books_outlined), 'نسخ بالمصدر', () {
              Clipboard.setData(ClipboardData(text: quoteText(b, text, src)));
              clearSel();
              toast(context, 'نُسخ النص مع اسم الكتاب والصفحة');
            }),
            item(ico(Icons.format_quote_rounded), 'اقتباس', () async {
              final pgNow = selPg;
              final topic = await pickTopic(context);
              if (topic == null || !mounted) return;
              st.addQuote(b.id, pgNow, text, lab, topic: topic);
              clearSel();
              if (mounted) toast(this.context, topic.isEmpty ? 'حُفظ في اقتباساتك في «مكتبتي»' : 'حُفظ في اقتباساتك تحت «$topic»');
            }),
            if (under != null)
              item(ico(Icons.format_quote_rounded), 'اقتبس المظلّل', () async {
                final h = under;
                final topic = await pickTopic(context);
                if (topic == null || !mounted) return;
                st.addQuote(b.id, h.pg, h.text, h.label, topic: topic);
                clearSel();
                if (mounted) toast(this.context, 'حُفظ النص المظلّل في اقتباساتك');
              }),
            item(ico(Icons.share_rounded), 'مشاركة', () => Share.share(quoteText(b, text, src))),
            item(ico(Icons.image_outlined), 'مشاركة صورة',
                () => showQuoteImage(context, text: text, scholar: b.scholar.collection ? '' : '${b.scholar.name} ${b.scholar.honorific}', source: '${b.shortName} (صـ $src)')),
            item(ico(Icons.sticky_note_2_outlined), 'ملاحظة', () => _addNote(text, lab)),
            item(ico(Icons.translate_rounded), 'المعجم', () => openDict(context, text)),
            sep(),
            item(ico(Icons.close_rounded), 'إغلاق', clearSel),
          ]),
        ),
      ),
    );
  }

  /// A note on the page as a whole, not on a chosen text.
  Future<void> _addPageNote() async {
    final ctl = TextEditingController();
    final p = pg;
    final note = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('ملاحظة على ${label(p)}'),
        content: TextField(controller: ctl, autofocus: true, maxLines: 6, minLines: 3, decoration: const InputDecoration(hintText: 'ملخّص الصفحة أو ما تريد تذكّره منها…', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('احفظ')),
        ],
      ),
    );
    if (note == null || note.trim().isEmpty || !mounted) return;
    Store.i.addNote(b.id, p, 'الصفحة كلها', note, label(p));
    toast(context, 'حُفظت ملاحظة الصفحة في «مكتبتي»');
  }

  Future<void> _addNote(String text, String lab) async {
    final ctl = TextEditingController();
    final p = selPg;
    final note = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ملاحظة'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('«$text»', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: bookFont, fontSize: 15.5, height: 1.7, color: C.muted(c))),
          const SizedBox(height: 10),
          TextField(controller: ctl, autofocus: true, maxLines: 4, minLines: 2, decoration: const InputDecoration(hintText: 'اكتب ملاحظتك…', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('احفظ')),
        ],
      ),
    );
    if (note == null || note.trim().isEmpty || !mounted) return;
    Store.i.addNote(b.id, p, text, note, lab);
    clearSel();
    toast(context, 'حُفظت الملاحظة في «مكتبتي»');
  }

  Widget _modeChip(BuildContext context, Color ink, IconData icon, String label, bool on, VoidCallback tap) {
    final ac = C.accent(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: on ? ac.withValues(alpha: 0.14) : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: on ? ac : ink.withValues(alpha: 0.18))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 17, color: on ? ac : ink.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? ac : ink.withValues(alpha: 0.8))),
            ]),
          ),
        ),
      ),
    );
  }

  void _menu(String v) {
    switch (v) {
      case 'pdf':
        if (index != null) openPdf(context, b, index!, pg);
      case 'search':
        Navigator.push(context, MaterialPageRoute(builder: (_) => BookSearchScreen(b, onOpen: goTo, onFind: (q, pages) => setState(() {
              find = q;
              findPages = pages.toSet().toList()..sort();
            }))));
      case 'goto':
        _askPage();
      case 'pagenote':
        _addPageNote();
      case 'look':
        showReadingLook(context);
      case 'download':
        startDownload(context, b);
      case 'book':
        openBook(context, b);
      case 'report':
        showReport(context, about: '${b.shortName} · ${label(pg)}');
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
            child: TocList(ix, current: pg, bookId: b.id, pages: b.pages, onOpen: (p) {
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
  final bool flow; // part of the continuous text
  const _Page({required this.state, required this.pg, required this.ink, this.flow = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RawPage>(
      future: state.pageFuture(pg),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return flow ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())) : const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          final err = Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              EmptyNote(
                  Icons.wifi_off_rounded,
                  kIsWeb && !Turath.hosted.contains(state.b.id)
                      ? 'هذا الكتاب لم يُضف إلى الموقع بعد، ويُضاف قريبًا بإذن الله. ويمكنك قراءته الآن في تطبيق أندرويد.'
                      : 'تعذّر فتح الصفحة. تأكّد من الإنترنت، أو حمّل الكتاب ليُقرأ بلا إنترنت.'),
              TextButton(onPressed: () => state.retry(pg), child: const Text('حاول مرة أخرى')),
            ]),
          );
          return flow ? Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: err) : err;
        }
        final st = Store.i;
        final pt = cleanPage(snap.data!.text, harakat: st.tashkeel);
        final base = TextStyle(fontFamily: st.readFont, fontSize: st.fontSize, height: st.readFont == 'Amiri' ? 2.0 : 1.9, color: ink);
        final heading = state.index?.headingAt(pg);
        final content = <Widget>[
            SelectableText.rich(
              key: ValueKey('t$pg-${state.selEpoch}'),
              TextSpan(children: _spans(context, pt, base)),
              textAlign: TextAlign.justify,
              onSelectionChanged: (sel, cause) {
                final n = pt.body.length;
                final a = sel.isValid ? sel.start.clamp(0, n) : 0;
                final e = sel.isValid ? sel.end.clamp(0, n) : 0;
                state.onSelect(pg, pt.body, a, e);
              },
              contextMenuBuilder: (context, es) => AdaptiveTextSelectionToolbar.editableText(editableTextState: es),
            ),
            if (pt.foot.isNotEmpty && !st.hideFoot) ...[
              const SizedBox(height: 16),
              Divider(color: ink.withValues(alpha: 0.2), endIndent: 160),
              SelectableText(pt.foot,
                  style: TextStyle(fontFamily: st.readFont, fontSize: st.fontSize * 0.72, height: 1.8, color: ink.withValues(alpha: 0.8))),
            ],
        ];
        if (flow) {
          // continuous text: pages one after another, with the page number between them
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ...content,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(children: [
                  Expanded(child: Divider(color: ink.withValues(alpha: 0.15))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(state.label(pg), style: TextStyle(fontSize: 12.5, color: ink.withValues(alpha: 0.5))),
                  ),
                  Expanded(child: Divider(color: ink.withValues(alpha: 0.15))),
                ]),
              ),
            ]),
          );
        }
        // a page like the printed book: header line, framed page, page number at the foot
        final paperCol = st.paper == 0 ? C.card(context) : Color.alphaBlend(Colors.white.withValues(alpha: C.dark(context) || st.paper == 3 ? 0.03 : 0.5), paperColors(context).$1);
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: paperCol,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: C.gold(context).withValues(alpha: 0.35)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(children: [
                  Expanded(
                    child: Text(heading?.title ?? state.b.shortName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: bookFont, fontSize: 14, color: C.accent(context))),
                  ),
                  const SizedBox(width: 8),
                  Text(state.b.shortName == (heading?.title ?? state.b.shortName) ? '' : state.b.shortName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: ink.withValues(alpha: 0.45))),
                ]),
              ),
              Divider(height: 1, indent: 14, endIndent: 14, color: C.gold(context).withValues(alpha: 0.45)),
              Expanded(
                child: Scrollbar(
                  child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 16), children: content),
                ),
              ),
              Divider(height: 1, indent: 14, endIndent: 14, color: C.gold(context).withValues(alpha: 0.45)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(state.label(pg), style: TextStyle(fontSize: 13, color: ink.withValues(alpha: 0.6))),
              ),
            ]),
          ),
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
    if (state.find.isNotEmpty) {
      final r = locate(pt.body, state.find);
      if (r != null) out.add((r.$1, r.$2, -1)); // -1: the searched words
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
          backgroundColor: color == null ? null : color < 0 ? const Color(0x99FFC107) : hlColor(color),
        ),
      ));
    }
    return spans;
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
