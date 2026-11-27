import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../store.dart';
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
