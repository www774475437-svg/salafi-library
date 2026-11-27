import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../store.dart';
import '../text.dart';
import '../turath.dart';
import '../ui.dart';
import 'reader.dart';
import 'scholar.dart' show BookTile;

/// Lets the reader choose one book from the whole library.
Future<BookInfo?> pickBook(BuildContext context) {
  return showModalBottomSheet<BookInfo>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => const _PickBook(),
  );
}

class _PickBook extends StatefulWidget {
  const _PickBook();
  @override
  State<_PickBook> createState() => _PickBookState();
}

class _PickBookState extends State<_PickBook> {
  String q = '';
  late final List<BookInfo> all = Catalog.byId.values.where((b) => b.pages > 0).toList()..sort((a, b) => a.shortName.compareTo(b.shortName));

  @override
  Widget build(BuildContext context) {
    final list = q.isEmpty ? all : all.where((b) => b.name.contains(q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(hintText: 'ابحث عن كتاب…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            onChanged: (v) => setState(() => q = v.trim()),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(list[i].shortName, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${list[i].scholar.short} · ${Ar.pages(list[i].pages)}'),
              onTap: () => Navigator.pop(context, list[i]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// «خطة ختم كتاب»: a book divided over a number of days, with today's share.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final b = await pickBook(context);
    if (b == null || !context.mounted) return;
    final days = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('في كم يومًا تختم «${b.shortName}»؟'),
        children: [
          for (final d in const [7, 14, 30, 60, 90, 180])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, d),
              child: Text('${Ar.num(d)} يومًا · نحو ${Ar.pages((b.pages / d).ceil())} في اليوم'),
            ),
        ],
      ),
    );
    if (days != null) Store.i.setPlan(b.id, days);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final plans = Store.i.plans;
        return Scaffold(
          appBar: AppBar(title: const Text('خطة ختم كتاب')),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context), icon: const Icon(Icons.add_rounded), label: const Text('خطة جديدة')),
          body: plans.isEmpty
              ? const EmptyNote(Icons.flag_outlined, 'اختر كتابًا وعدد الأيام، فيُقسَّم إلى ورد يومي وتتابع تقدّمك فيه.')
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
                  for (final e in plans.entries)
                    if (Catalog.byId[e.key] != null) _PlanCard(Catalog.byId[e.key]!, e.value[0], e.value[1]),
                ]),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final BookInfo b;
  final int start, days;
  const _PlanCard(this.b, this.start, this.days);

  @override
  Widget build(BuildContext context) {
    final daily = (b.pages / days).ceil();
    final t = DateTime.now();
    final day = DateTime(t.year, t.month, t.day).difference(DateTime.fromMillisecondsSinceEpoch(start)).inDays + 1;
    final done = (Store.i.lastPg[b.id] ?? 0).clamp(0, b.pages);
    final due = (daily * day).clamp(0, b.pages); // where the plan expects the reader by tonight
    final finished = done >= b.pages;
    final String status;
    if (finished) {
      status = 'أتممتَ الكتاب، بارك الله لك';
    } else if (done >= due) {
      status = day > days ? 'انتهت أيام الخطة' : 'أتممتَ ورد اليوم';
    } else {
      status = 'ورد اليوم: من صفحة ${Ar.num(done + 1)} إلى ${Ar.num(due)}'
          '${due - done > daily ? ' (متأخر ${Ar.pages(due - done - daily)})' : ''}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.shortName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: bookFont, fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
          const SizedBox(height: 4),
          Text('اليوم ${Ar.num(day.clamp(1, days))} من ${Ar.num(days)} · ${Ar.pages(daily)} في اليوم', style: TextStyle(fontSize: 13, color: C.muted(context))),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: b.pages == 0 ? 0 : done / b.pages, minHeight: 8, backgroundColor: C.soft(context), color: C.accent(context)),
          ),
          const SizedBox(height: 8),
          Text('وصلتَ إلى صفحة ${Ar.num(done)} من ${Ar.num(b.pages)}', style: TextStyle(fontSize: 13, color: C.muted(context))),
          const SizedBox(height: 6),
          Text(status, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.accent(context))),
          const SizedBox(height: 8),
          Row(children: [
            if (!finished)
              FilledButton.icon(
                onPressed: () => openReader(context, b, done < 1 ? 1 : done),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('اقرأ الورد'),
              ),
            const Spacer(),
            TextButton(onPressed: () => Store.i.removePlan(b.id), child: const Text('احذف الخطة')),
          ]),
        ]),
      ),
    );
  }
}

/// «المكتبة حسب العلم»: the books of all scholars together, by their science.
class SciencesScreen extends StatelessWidget {
  const SciencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cats = <String, List<BookInfo>>{};
    for (final b in Catalog.byId.values) {
      if (b.catName.isNotEmpty) cats.putIfAbsent(b.catName, () => []).add(b);
    }
    final names = cats.keys.toList()..sort((a, b) => cats[b]!.length.compareTo(cats[a]!.length));
    return Scaffold(
      appBar: AppBar(title: const Text('المكتبة حسب العلم')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        for (final n in names)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ScienceBooks(n, cats[n]!))),
              child: Row(children: [
                Expanded(child: Text(n, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context)))),
                Text(Ar.books(cats[n]!.length), style: TextStyle(fontSize: 13, color: C.muted(context))),
                const SizedBox(width: 6),
                Icon(Icons.chevron_left_rounded, color: C.muted(context)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _ScienceBooks extends StatelessWidget {
  final String name;
  final List<BookInfo> books;
  const _ScienceBooks(this.name, this.books);

  @override
  Widget build(BuildContext context) {
    final list = [...books]..sort((a, b) => a.shortName.compareTo(b.shortName));
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(padding: const EdgeInsets.only(top: 6, bottom: 40), children: [for (final b in list) BookTile(b)]),
    );
  }
}

/// «دفتر البحث»: quotes from different books gathered under one title, with the reader's own writing between them.
class NotebooksScreen extends StatelessWidget {
  const NotebooksScreen({super.key});

  Future<void> _new(BuildContext context) async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('بحث جديد'),
        content: TextField(controller: ctl, autofocus: true, decoration: const InputDecoration(hintText: 'عنوان البحث', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('أنشئ')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) Store.i.createNotebook(name);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final nb = Store.i.notebooks;
        return Scaffold(
          appBar: AppBar(title: const Text('دفتر البحث')),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _new(context), icon: const Icon(Icons.add_rounded), label: const Text('بحث جديد')),
          body: nb.isEmpty
              ? const EmptyNote(Icons.edit_note_rounded, 'اجمع اقتباساتك من كتب مختلفة تحت عنوان واحد، ورتّبها واكتب بينها، ثم شاركها نصًّا.')
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
                  for (final e in nb.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotebookScreen(e.key))),
                        child: Row(children: [
                          Expanded(child: Text(e.key, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context)))),
                          Text('${Ar.num(e.value.length)} فقرة', style: TextStyle(fontSize: 13, color: C.muted(context))),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                        ]),
                      ),
                    ),
                ]),
        );
      },
    );
  }
}

class NotebookScreen extends StatelessWidget {
  final String name;
  const NotebookScreen(this.name, {super.key});

  String _text(List<Map<String, dynamic>> items) {
    final out = StringBuffer('$name\n');
    for (final e in items) {
      if (e['k'] == 'q') {
        out.write('\n«${e['x']}»\n[${e['s']}]\n');
      } else {
        out.write('\n${e['x']}\n');
      }
    }
    return out.toString();
  }

  Future<void> _addQuote(BuildContext context) async {
    final quotes = Store.i.quotes;
    if (quotes.isEmpty) {
      toast(context, 'ليس في اقتباساتك شيء بعد');
      return;
    }
    final k = await showModalBottomSheet<Kept>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.8,
        child: ListView(children: [
          for (final q in quotes)
            ListTile(
              title: Text(q.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: bookFont, fontSize: 16, height: 1.6)),
              subtitle: Text('${Catalog.byId[q.book]?.shortName ?? 'كتاب'} · ${q.label}'),
              onTap: () => Navigator.pop(c, q),
            ),
        ]),
      ),
    );
    if (k == null) return;
    Store.i.addToNotebook(name, {'k': 'q', 'x': k.text, 's': '${Catalog.byId[k.book]?.shortName ?? 'كتاب'} · ${k.label}', 'b': k.book, 'p': k.pg});
  }

  Future<void> _addText(BuildContext context) async {
    final ctl = TextEditingController();
    final t = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('كتابة من عندك'),
        content: TextField(controller: ctl, autofocus: true, maxLines: 6, minLines: 3, decoration: const InputDecoration(hintText: 'تمهيد، أو تعليق، أو ربط بين اقتباسين…', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('أضف')),
        ],
      ),
    );
    if (t != null && t.isNotEmpty) Store.i.addToNotebook(name, {'k': 't', 'x': t});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final items = Store.i.notebooks[name] ?? const <Map<String, dynamic>>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(tooltip: 'شارك البحث نصًّا', icon: const Icon(Icons.ios_share_rounded), onPressed: items.isEmpty ? null : () => Share.share(_text(items))),
              IconButton(
                tooltip: 'احذف البحث',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('حذف البحث'),
                      content: Text('يُحذف «$name» بكل ما فيه، ولا تُحذف اقتباساتك الأصلية.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('احذف')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    Navigator.pop(context);
                    Store.i.deleteNotebook(name);
                  }
                },
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(children: [
                Expanded(child: FilledButton.icon(onPressed: () => _addQuote(context), icon: const Icon(Icons.format_quote_rounded), label: const Text('أضف اقتباسًا'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => _addText(context), icon: const Icon(Icons.edit_rounded), label: const Text('اكتب'))),
              ]),
            ),
          ),
          body: items.isEmpty
              ? const EmptyNote(Icons.edit_note_rounded, 'أضف اقتباسًا من اقتباساتك أو اكتب فقرة، ثم اسحب الفقرات لترتيبها.')
              : ReorderableListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  onReorder: (a, b) => Store.i.moveInNotebook(name, a, b),
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        key: ValueKey('$i-${items[i]['x'].hashCode}'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (items[i]['k'] == 'q') ...[
                              Text('«${items[i]['x']}»', style: TextStyle(fontFamily: bookFont, fontSize: 17, height: 1.8, color: C.ink(context))),
                              const SizedBox(height: 6),
                              Text('${items[i]['s']}', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
                            ] else
                              Text('${items[i]['x']}', style: TextStyle(fontSize: 15.5, height: 1.8, color: C.ink(context))),
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              if (items[i]['k'] == 'q' && Catalog.byId[items[i]['b']] != null)
                                TextButton(onPressed: () => openReader(context, Catalog.byId[items[i]['b']]!, items[i]['p'] as int), child: const Text('موضعه')),
                              TextButton(onPressed: () => Store.i.removeFromNotebook(name, i), child: const Text('أزل')),
                            ]),
                          ]),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// «تسميع المتون»: a page of a book with its words hidden; the reader recites, then uncovers to check.
class MemorizeScreen extends StatefulWidget {
  final BookInfo book;
  const MemorizeScreen(this.book, {super.key});
  @override
  State<MemorizeScreen> createState() => _MemorizeScreenState();
}

class _MemorizeScreenState extends State<MemorizeScreen> {
  late int pg = (Store.i.lastPg[widget.book.id] ?? 1).clamp(1, widget.book.pages);
  int mode = 0; // 0: the start of each line stays, 1: every other word, 2: all hidden
  final Set<int> shown = {}; // the lines uncovered
  Future<List<String>>? lines;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    shown.clear();
    lines = Turath.page(widget.book.id, pg).then((r) => cleanPage(r.text).body.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList());
  }

  void _go(int p) => setState(() {
        pg = p.clamp(1, widget.book.pages);
        _load();
      });

  /// A line with some of its words covered.
  String _covered(String line) {
    final words = line.split(' ');
    String dots(String w) => '⋯' * (w.length < 3 ? 1 : 2);
    return [
      for (var i = 0; i < words.length; i++)
        switch (mode) {
          0 => i < 2 ? words[i] : dots(words[i]),
          1 => i.isEven ? words[i] : dots(words[i]),
          _ => dots(words[i]),
        }
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تسميع: ${widget.book.shortName}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            IconButton(tooltip: 'الصفحة السابقة', icon: const Icon(Icons.chevron_right_rounded), onPressed: pg > 1 ? () => _go(pg - 1) : null),
            Expanded(child: Text('صفحة ${Ar.num(pg)} من ${Ar.num(widget.book.pages)}', textAlign: TextAlign.center, style: TextStyle(color: C.muted(context)))),
            IconButton(tooltip: 'الصفحة التالية', icon: const Icon(Icons.chevron_left_rounded), onPressed: pg < widget.book.pages ? () => _go(pg + 1) : null),
          ]),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('أول السطر')),
              ButtonSegment(value: 1, label: Text('كلمة وكلمة')),
              ButtonSegment(value: 2, label: Text('الكل مخفي')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              mode = s.first;
              shown.clear();
            }),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<String>>(
            future: lines,
            builder: (context, snap) {
              if (snap.hasError) return const EmptyNote(Icons.wifi_off_rounded, 'تعذّر فتح الصفحة. حمّل الكتاب ليعمل التسميع بلا إنترنت.');
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final ls = snap.data!;
              if (ls.isEmpty) return const EmptyNote(Icons.notes_rounded, 'هذه الصفحة فارغة.');
              return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), children: [
                Row(children: [
                  Expanded(child: Text('سمّع السطر ثم اضغطه لتتحقق.', style: TextStyle(fontSize: 13, color: C.muted(context)))),
                  TextButton(
                    onPressed: () => setState(() => shown.length == ls.length ? shown.clear() : shown.addAll([for (var i = 0; i < ls.length; i++) i])),
                    child: Text(shown.length == ls.length ? 'أخفِ الكل' : 'اكشف الكل'),
                  ),
                ]),
                for (var i = 0; i < ls.length; i++)
                  InkWell(
                    onTap: () => setState(() => shown.contains(i) ? shown.remove(i) : shown.add(i)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        shown.contains(i) ? ls[i] : _covered(ls[i]),
                        style: TextStyle(fontFamily: bookFont, fontSize: 20, height: 1.9, color: shown.contains(i) ? C.ink(context) : C.muted(context)),
                      ),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

/// «الفهرس الموضوعي»: the chapters about one subject, gathered from the tables of contents of the books.
class TopicIndexScreen extends StatefulWidget {
  const TopicIndexScreen({super.key});
  @override
  State<TopicIndexScreen> createState() => _TopicIndexScreenState();
}

class _TopicIndexScreenState extends State<TopicIndexScreen> {
  static const suggested = ['التوحيد', 'الإخلاص', 'الصبر', 'التوبة', 'الدعاء', 'العلم', 'الصلاة', 'الزكاة', 'الصيام', 'الحج', 'بر الوالدين', 'الذكر'];
  final _ctl = TextEditingController();
  int _scholar = -1;
  String _q = '';
  bool _busy = false;
  int _run = 0, _done = 0, _all = 0, _failed = 0;
  final Map<BookInfo, List<Heading>> _found = {};

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.length < 2) return;
    FocusScope.of(context).unfocus();
    final id = ++_run;
    final nq = norm(q);
    final books = Catalog.byId.values
        .where((b) => b.pages > 0 && (_scholar < 0 || b.scholar == Catalog.scholars[_scholar]) && (Turath.hosted.contains(b.id) || Store.i.downloaded.contains(b.id)))
        .toList();
    setState(() {
      _q = q;
      _busy = true;
      _found.clear();
      _done = 0;
      _failed = 0;
      _all = books.length;
    });
    // a few tables of contents at a time; each is kept after its first reading
    var next = 0;
    Future<void> worker() async {
      while (next < books.length && id == _run) {
        final b = books[next++];
        try {
          final idx = await Turath.index(b.id);
          final hs = idx.headings.where((h) => norm(h.title).contains(nq)).toList();
          if (id != _run) return;
          if (hs.isNotEmpty) _found[b] = hs;
        } catch (_) {
          _failed++;
        }
        if (id != _run || !mounted) return;
        setState(() => _done++);
      }
    }

    await Future.wait([for (var i = 0; i < 6; i++) worker()]);
    if (mounted && id == _run) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = _found.values.fold(0, (a, l) => a + l.length);
    return Scaffold(
      appBar: AppBar(title: const Text('الفهرس الموضوعي')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: TextField(
            controller: _ctl,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'موضوع: الصبر، التوحيد، صلاة الاستسقاء…',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: C.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: C.line(context))),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), children: [
            for (var i = -1; i < Catalog.scholars.length; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(i < 0 ? 'كل الكتب' : Catalog.scholars[i].short),
                  selected: _scholar == i,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _scholar = i);
                    if (_q.isNotEmpty) _search(_q);
                  },
                ),
              ),
          ]),
        ),
        if (_busy || _q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_busy) LinearProgressIndicator(value: _all == 0 ? null : _done / _all),
              const SizedBox(height: 4),
              Text(
                _busy
                    ? 'يقرأ فهارس الكتب: ${Ar.num(_done)} من ${Ar.num(_all)} · وُجد ${Ar.num(total)} بابًا'
                    : '${Ar.num(total)} بابًا في ${Ar.books(_found.length)}${_failed > 0 ? ' · تعذّر فتح فهارس ${Ar.books(_failed)}' : ''}',
                style: TextStyle(fontSize: 13, color: C.muted(context)),
              ),
            ]),
          ),
        Expanded(
          child: _q.isEmpty
              ? ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
                  Text('يجمع لك الأبواب التي في عنوانها الموضوع، من فهارس الكتب المضافة إلى المكتبة. أول بحث يأخذ وقتًا لقراءة الفهارس، وما بعده أسرع.',
                      style: TextStyle(fontSize: 14, height: 1.8, color: C.muted(context))),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in suggested)
                      ActionChip(
                        label: Text(t),
                        onPressed: () {
                          _ctl.text = t;
                          _search(t);
                        },
                      ),
                  ]),
                ])
              : !_busy && _found.isEmpty
                  ? EmptyNote(Icons.search_off_rounded, 'لا باب في عنوانه «$_q» في فهارس هذه الكتب.')
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                      for (final e in _found.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Row(children: [
                            Expanded(
                              child: Text('${e.key.shortName} · ${e.key.scholar.short}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: C.ink(context))),
                            ),
                            Text(Ar.num(e.value.length), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.accent(context))),
                          ]),
                        ),
                        for (final h in e.value.take(12))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: bookFont, fontSize: 16.5, height: 1.5)),
                            trailing: Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                            onTap: () => openReader(context, e.key, h.pg),
                          ),
                        if (e.value.length > 12)
                          Text('و${Ar.num(e.value.length - 12)} بابًا آخر في فهرس الكتاب', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
                      ],
                    ]),
        ),
      ]),
    );
  }
}
