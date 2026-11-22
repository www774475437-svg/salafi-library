import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../catalog.dart';
import '../store.dart';
import '../turath.dart';
import '../ui.dart';
import '../update.dart' show openLink;

/// Opens the scanned printed book at the page being read.
void openPdf(BuildContext context, BookInfo b, BookIndex ix, int pg) {
  final (vol, printed) = ix.printed(pg);
  final file = ix.pdfFor(vol);
  if (file == null) {
    toast(context, 'لا توجد نسخة مصوّرة لهذا الكتاب');
    return;
  }
  final target = (printed + Store.i.offsetFor(b.id, vol)).clamp(1, 100000);
  if (kIsWeb) {
    openLink('${file.url}#page=$target');
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => PdfScreen(book: b, index: ix, file: file, vol: vol, printed: printed, start: target)));
}

class PdfScreen extends StatefulWidget {
  final BookInfo book;
  final BookIndex index;
  final PdfFile file;
  final String vol;
  final int printed;
  final int start;
  const PdfScreen({super.key, required this.book, required this.index, required this.file, required this.vol, required this.printed, required this.start});
  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  final _ctl = PdfViewerController();
  int _page = 1;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.start;
  }

  String get _volText => widget.index.vols > 1 && widget.vol.isNotEmpty ? 'ج${Ar.num(widget.vol)} ' : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.book.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          Text('النسخة المصوّرة · ${_volText}ص${Ar.num(widget.printed)}', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        ]),
        actions: [
          IconButton(tooltip: 'افتح في المتصفح', icon: const Icon(Icons.open_in_new_rounded), onPressed: () => openLink('${widget.file.url}#page=$_page')),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: PdfViewer.uri(
            Uri.parse(widget.file.url),
            controller: _ctl,
            initialPageNumber: widget.start,
            params: PdfViewerParams(
              backgroundColor: C.soft(context),
              onViewerReady: (document, controller) => setState(() => _count = document.pages.length),
              onPageChanged: (n) {
                if (n != null) setState(() => _page = n);
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(color: C.card(context), border: Border(top: BorderSide(color: C.line(context)))),
            child: Row(children: [
              Expanded(
                child: Text(_count > 0 ? 'صفحة ${Ar.num(_page)} من ${Ar.num(_count)}' : 'يُحمَّل الكتاب المصوّر…',
                    style: TextStyle(fontSize: 14, color: C.muted(context))),
              ),
              TextButton.icon(
                onPressed: _match,
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text('هذه ${_volText}ص${Ar.num(widget.printed)}'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  /// The reader shows that this scanned page is the printed page being read; remember the difference.
  void _match() {
    Store.i.setOffset(widget.book.id, widget.vol, _page - widget.printed);
    toast(context, 'حُفظت المطابقة، وستُفتح الصفحات بعدها في موضعها');
  }
}
