import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../catalog.dart';
import '../files/files.dart';
import '../store.dart';
import '../text.dart';
import '../turath.dart';
import '../ui.dart';
import 'reader.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  String _q = '';
  int _scholar = -1; // -1 all
  bool _offline = false;
  bool _busy = false;
  String? _error;
  int _total = 0;
  int _page = 1;
  final List<SearchHit> _hits = [];
  int _searchId = 0;
  String _progress = '';
  bool _exact = false; // only results that hold the phrase as written
  String _without = ''; // results holding this word are left out
  final Set<int> _open = {}; // books whose results are all shown

  List<Scholar> get _chosen => _scholar < 0 ? Catalog.scholars.where((s) => s.authorId > 0).toList() : [Catalog.scholars[_scholar]];

  Future<void> _run({bool more = false}) async {
    final q = _ctl.text.trim();
    if (q.length < 2) return;
    FocusScope.of(context).unfocus();
    final id = ++_searchId;
    if (!more) Store.i.addSearch(q);
    final byBook = kIsWeb || (_scholar >= 0 && Catalog.scholars[_scholar].collection);
    setState(() {
      _busy = true;
      _error = null;
      _q = q;
      if (!more) {
        _open.clear();
        _hits.clear();
        _total = 0;
        _page = 1;
      } else {
        _page++;
      }
    });
    try {
      if (_offline) {
        final ids = Store.i.downloaded.where((b) {
          final info = Catalog.byId[b];
          return info != null && _chosen.contains(info.scholar);
        }).toList();
        for (final bid in ids) {
          final r = await BookFiles.search(bid, q, 60);
          if (id != _searchId) return;
          final info = Catalog.byId[bid]!;
          setState(() {
            for (final m in r) {
              _hits.add(SearchHit(bid, info.scholar.authorId, m['pg'] as int, '${m['vol']}', m['page'] as int, info.name, m['snip'] as String));
            }
            _total = _hits.length;
          });
        }
      } else if (byBook) {
        // the website cannot ask «تراث», and a collection has no single author there:
        // both search the books kept in the library, book by book
        final books = [for (final s in _chosen) ...s.books.where((b) => Turath.hosted.contains(b.id))];
        if (more) return;
        if (books.isEmpty) {
          _error = kIsWeb
              ? 'كتب ${_scholar < 0 ? 'هؤلاء العلماء' : Catalog.scholars[_scholar].short} لم تُضف إلى الموقع بعد. ويمكنك البحث فيها كلها في تطبيق أندرويد.'
              : 'كتب هذا القسم لم تُضف إلى المخزن بعد.';
        }
        for (var i = 0; i < books.length && _hits.length < 400; i++) {
          final bk = books[i];
          setState(() => _progress = 'يبحث في ${Ar.num(i + 1)} من ${Ar.num(books.length)}: ${bk.shortName}');
          try {
            final r = await Turath.searchHosted(bk.id, bk.scholar.authorId, bk.name, q, limit: 40);
            if (id != _searchId) return;
            setState(() {
              _hits.addAll(r);
              _total = _hits.length;
            });
          } catch (_) {}
        }
        _progress = '';
      } else {
        final results = await Future.wait(_chosen.map((s) => Turath.search(q, s.authorId, page: _page).catchError((_) => (0, <SearchHit>[]))));
        if (id != _searchId) return;
        final lists = results.map((r) => r.$2).toList();
        final merged = <SearchHit>[];
        for (var i = 0; lists.any((l) => i < l.length); i++) {
          for (final l in lists) {
            if (i < l.length) merged.add(l[i]);
          }
        }
        if (!more) _total = results.fold(0, (a, r) => a + r.$1);
        if (merged.isEmpty && !more && results.every((r) => r.$1 == 0) && _total == 0) {
          // nothing found, or no internet: say which
          try {
            await Turath.search(q, _chosen.first.authorId);
          } catch (_) {
            _error = kIsWeb
                ? 'البحث في كتب «تراث» لا يعمل من الموقع حاليًا، وهو يعمل في تطبيق أندرويد.'
                : 'تعذّر البحث، تأكّد من الإنترنت. ويمكنك البحث في كتبك المحمّلة بلا إنترنت.';
          }
        }
        setState(() => _hits.addAll(merged));
      }
    } catch (_) {
      _error = 'تعذّر البحث، تأكّد من الإنترنت.';
    }
    if (mounted && id == _searchId) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: TextField(
            controller: _ctl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(),
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(
              hintText: 'ابحث في كتب العلماء…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_back_rounded), tooltip: 'ابحث', onPressed: () => _run()),
              filled: true,
              fillColor: C.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), children: [
            _chip('كل العلماء', _scholar < 0, () => _pick(-1)),
            for (var i = 0; i < Catalog.scholars.length; i++)
              _chip(Catalog.scholars[i].short, _scholar == i, () => _pick(i)),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(label: const Text('العبارة كما هي'), selected: _exact, onSelected: (v) => setState(() => _exact = v)),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: InputChip(
                label: Text(_without.isEmpty ? 'بدون كلمة…' : 'بدون «$_without»'),
                selected: _without.isNotEmpty,
                showCheckmark: false,
                onPressed: _askWithout,
                onDeleted: _without.isEmpty ? null : () => setState(() => _without = ''),
              ),
            ),
          ]),
        ),
        if (BookFiles.supported)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.public_rounded), label: Text('في «تراث»')),
                ButtonSegment(value: true, icon: Icon(Icons.download_done_rounded), label: Text('في كتبي المحمّلة')),
              ],
              selected: {_offline},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() => _offline = s.first);
                if (_ctl.text.trim().length >= 2) _run();
              },
            ),
          ),
        Expanded(child: _results()),
      ]),
    );
  }

  Future<void> _askWithout() async {
    final ctl = TextEditingController(text: _without);
    final w = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('استثنِ كلمة من النتائج'),
        content: TextField(controller: ctl, autofocus: true, decoration: const InputDecoration(hintText: 'الكلمة التي لا تريدها', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('تم')),
        ],
      ),
    );
    if (w != null && mounted) setState(() => _without = w);
  }

  /// The results after the reader's conditions. They are judged on the lines shown,
  /// so a word further down the page is not seen.
  List<SearchHit> get _shown {
    if (!_exact && _without.isEmpty) return _hits;
    return _hits.where((h) {
      final t = h.snip.contains('<em>') ? emSnippet(h.snip).$1 : h.snip;
      if (_exact && locate(t, _q) == null) return false;
      if (_without.isNotEmpty && locate(t, _without) != null) return false;
      return true;
    }).toList();
  }

  Widget _history() {
    final s = Store.i;
    final list = [...s.searches.where(s.pinnedSearches.contains), ...s.searches.where((q) => !s.pinnedSearches.contains(q))];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 110), children: [
      Text('سجل البحث', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.ink(context))),
      const SizedBox(height: 6),
      for (final q in list)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(s.pinnedSearches.contains(q) ? Icons.push_pin_rounded : Icons.history_rounded, color: C.muted(context)),
          title: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
          onTap: () {
            _ctl.text = q;
            _run();
          },
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: s.pinnedSearches.contains(q) ? 'أزل التثبيت' : 'ثبّت',
              icon: Icon(s.pinnedSearches.contains(q) ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 20),
              onPressed: () => setState(() => s.togglePinSearch(q)),
            ),
            IconButton(tooltip: 'احذف', icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(() => s.removeSearch(q))),
          ]),
        ),
    ]);
  }

  void _pick(int i) {
    setState(() => _scholar = i);
    if (_ctl.text.trim().length >= 2) _run();
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(label: Text(label), selected: on, showCheckmark: false, onSelected: (_) => tap()),
      );

  Widget _results() {
    if (_q.isEmpty && Store.i.searches.isNotEmpty) return _history();
    if (_q.isEmpty) {
      return EmptyNote(Icons.manage_search_rounded,
          _offline ? 'اكتب كلمة للبحث في كتبك المحمّلة، ويعمل بلا إنترنت.' : 'اكتب كلمة أو جملة للبحث في كتب العلماء كلها، أو اختر عالمًا.');
    }
    if (_error != null && _hits.isEmpty) return EmptyNote(Icons.wifi_off_rounded, _error!);
    if (!_busy && _hits.isEmpty) {
      return EmptyNote(Icons.search_off_rounded,
          _offline && Store.i.downloaded.isEmpty ? 'لم تحمّل أي كتاب بعد. حمّل الكتب من صفحاتها لتبحث فيها بلا إنترنت.' : 'لا نتائج لـ«$_q».');
    }
    final canMore = !_offline && !kIsWeb && _hits.length < _total;
    final shown = _shown;
    // each book's results together, in the order the books first appeared
    final groups = <int, List<SearchHit>>{};
    for (final h in shown) {
      groups.putIfAbsent(h.book, () => []).add(h);
    }
    final filtered = _exact || _without.isNotEmpty;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 110), children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
            _busy && _progress.isNotEmpty
                ? 'النتائج: ${Ar.num(_hits.length)} · $_progress'
                : _busy && _hits.isEmpty
                    ? 'يبحث…'
                    : filtered
                        ? 'يوافق شروطك ${Ar.num(shown.length)} من ${Ar.num(_hits.length)} نتيجة معروضة، في ${Ar.books(groups.length)}'
                        : 'النتائج: ${Ar.num(_total)} · المعروض منها في ${Ar.books(groups.length)}',
            style: TextStyle(color: C.muted(context), fontSize: 13.5)),
      ),
      if (filtered && shown.isEmpty && !_busy)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text('لا نتيجة توافق شروطك فيما عُرض. جرّب «المزيد من النتائج» أو خفّف الشروط.', textAlign: TextAlign.center, style: TextStyle(color: C.muted(context), fontSize: 15, height: 1.7)),
        ),
      for (final e in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(children: [
            Expanded(
              child: Text(bookOrStub(e.key, e.value.first.bookName, e.value.first.authorId).shortName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.ink(context))),
            ),
            Text(Ar.num(e.value.length), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.accent(context))),
          ]),
        ),
        for (final h in (_open.contains(e.key) ? e.value : e.value.take(3))) HitCard(h, query: _q),
        if (e.value.length > 3)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _open.contains(e.key) ? _open.remove(e.key) : _open.add(e.key)),
              icon: Icon(_open.contains(e.key) ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text(_open.contains(e.key) ? 'أقل' : 'المزيد (${Ar.num(e.value.length - 3)})'),
            ),
          ),
      ],
      if (_busy) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
      if (!_busy && canMore) TextButton(onPressed: () => _run(more: true), child: const Text('المزيد من النتائج')),
    ]);
  }
}

class HitCard extends StatelessWidget {
  final SearchHit h;
  final String query;
  final void Function(int pg)? onOpen;
  const HitCard(this.h, {super.key, required this.query, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final book = bookOrStub(h.book, h.bookName, h.authorId);
    final (text, marks) = h.snip.contains('<em>') ? emSnippet(h.snip) : (h.snip, <(int, int)>[]);
    final ranges = marks.isNotEmpty ? marks : _find(text, query);
    final base = TextStyle(fontFamily: bookFont, fontSize: 17, height: 1.8, color: C.ink(context));
    final spans = <TextSpan>[];
    var last = 0;
    for (final (a, b) in ranges) {
      if (a < last || b > text.length) continue;
      spans.add(TextSpan(text: text.substring(last, a)));
      spans.add(TextSpan(text: text.substring(a, b), style: TextStyle(backgroundColor: hlColor(0), fontWeight: FontWeight.w700)));
      last = b;
    }
    spans.add(TextSpan(text: text.substring(last)));
    final pageLabel = h.vol.isNotEmpty && h.vol != '1' ? 'ج${Ar.num(h.vol)} ص${Ar.num(h.page)}' : 'ص${Ar.num(h.page)}';
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () {
        if (onOpen != null) {
          Navigator.pop(context);
          onOpen!(h.pg);
        } else {
          openReader(context, book, h.pg);
        }
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(style: base, children: spans), maxLines: 6, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(children: [
          ScholarMark(book.scholar.short, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${book.shortName} · ${book.scholar.short}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: C.accent(context), fontWeight: FontWeight.w700)),
          ),
          Text(pageLabel, style: TextStyle(fontSize: 13, color: C.muted(context))),
        ]),
      ]),
    );
  }

  static List<(int, int)> _find(String text, String q) {
    final r = locate(text, q);
    return r == null ? const [] : [r];
  }
}

/// Search inside one book: the whole book when downloaded, otherwise through «تراث».
class BookSearchScreen extends StatefulWidget {
  final BookInfo book;
  final void Function(int pg)? onOpen;
  const BookSearchScreen(this.book, {super.key, this.onOpen});
  @override
  State<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends State<BookSearchScreen> {
  final _ctl = TextEditingController();
  final List<SearchHit> _hits = [];
  bool _busy = false;
  String _q = '';
  String? _note;

  Future<void> _run() async {
    final q = _ctl.text.trim();
    if (q.length < 2) return;
    FocusScope.of(context).unfocus();
    final b = widget.book;
    setState(() {
      _busy = true;
      _q = q;
      _hits.clear();
      _note = null;
    });
    try {
      if (Store.i.downloaded.contains(b.id)) {
        final r = await BookFiles.search(b.id, q, 400);
        for (final m in r) {
          _hits.add(SearchHit(b.id, b.scholar.authorId, m['pg'] as int, '${m['vol']}', m['page'] as int, b.name, m['snip'] as String));
        }
      } else if (Turath.hosted.contains(b.id)) {
        _hits.addAll(await Turath.searchHosted(b.id, b.scholar.authorId, b.name, q, limit: 400));
      } else if (kIsWeb) {
        _note = 'هذا الكتاب لم يُضف إلى الموقع بعد، ويمكنك البحث فيه في تطبيق أندرويد.';
      } else {
        for (var p = 1; p <= 6; p++) {
          final (total, hits) = await Turath.search(q, b.scholar.authorId, page: p);
          _hits.addAll(hits.where((h) => h.book == b.id));
          if (p * 20 >= total) break;
        }
        _note = BookFiles.supported ? 'حمّل الكتاب ليكون البحث فيه كاملًا وبلا إنترنت.' : null;
      }
    } catch (_) {
      _note = 'تعذّر البحث، تأكّد من الإنترنت.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ابحث في «${widget.book.shortName}»', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: TextField(
            controller: _ctl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(),
            decoration: InputDecoration(
              hintText: 'كلمة أو جملة…',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: C.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
            ),
          ),
        ),
        if (_note != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(_note!, style: TextStyle(color: C.muted(context), fontSize: 13.5))),
        Expanded(
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : _q.isEmpty
                  ? const EmptyNote(Icons.manage_search_rounded, 'اكتب ما تبحث عنه في هذا الكتاب.')
                  : _hits.isEmpty
                      ? EmptyNote(Icons.search_off_rounded, 'لا نتائج لـ«$_q» في هذا الكتاب.')
                      : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                          Text('النتائج: ${Ar.num(_hits.length)}', style: TextStyle(color: C.muted(context), fontSize: 13.5)),
                          const SizedBox(height: 8),
                          for (final h in _hits) HitCard(h, query: _q, onOpen: widget.onOpen),
                        ]),
        ),
      ]),
    );
  }
}
