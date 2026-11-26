import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../store.dart';
import '../ui.dart';
import '../update.dart' show siteUrl;
import 'reader.dart';

const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

/// «الترتيب»: how books and quotes are listed.
Future<void> showSortSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _SortSheet(),
    );

class _SortSheet extends StatelessWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        Widget head(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Text(t, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: C.ink(context))),
            );
        Widget opt(String text, bool on, VoidCallback tap) => ListTile(
              title: Text(text),
              trailing: on ? Icon(Icons.check_rounded, color: C.accent(context)) : null,
              onTap: tap,
            );
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              head('ترتيب الكتب'),
              opt('كما في الفهرس', s.bookSort == 0, () => s.setBookSort(0)),
              opt('حسب آخر قراءة', s.bookSort == 1, () => s.setBookSort(1)),
              opt('حسب حجم الكتاب، الأكبر أولًا', s.bookSort == 2, () => s.setBookSort(2)),
              opt('أبجديًا', s.bookSort == 3, () => s.setBookSort(3)),
              const Divider(),
              head('ترتيب الاقتباسات'),
              opt('الأحدث حفظًا أولًا', s.quoteSort == 0, () => s.setQuoteSort(0)),
              opt('كما حُفظت، الأقدم أولًا', s.quoteSort == 1, () => s.setQuoteSort(1)),
              opt('مجمّعة حسب الكتاب', s.quoteSort == 2, () => s.setQuoteSort(2)),
              opt('مجمّعة حسب المؤلف', s.quoteSort == 3, () => s.setQuoteSort(3)),
            ],
          ),
        );
      },
    );
  }
}

/// «إحصاءات القراءة»: pages turned this week against the week before.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  int _pagesOn(DateTime d) => Store.i.dayPages[Store.dayKey(d)] ?? 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    final counts = [for (final d in days) _pagesOn(d)];
    final thisWeek = counts.fold<int>(0, (a, b) => a + b);
    final lastWeek = [for (var i = 7; i < 14; i++) _pagesOn(now.subtract(Duration(days: i)))].fold<int>(0, (a, b) => a + b);
    final daysRead = counts.where((n) => n > 0).length;
    final top = counts.fold<int>(1, (a, b) => a > b ? a : b);
    final cmp = thisWeek == lastWeek
        ? 'مساوية لأسبوعك الماضي'
        : thisWeek > lastWeek
            ? 'أكثر من أسبوعك الماضي، بارك الله فيك'
            : 'أقل من أسبوعك الماضي، فاحرص على الاستمرار';
    TextStyle st(double size, {bool bold = false}) =>
        TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, height: 1.7, color: C.ink(context));
    return Scaffold(
      appBar: AppBar(title: const Text('إحصاءات القراءة')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('هذا الأسبوع: ${Ar.num(thisWeek)} صفحة في ${Ar.num(daysRead)} أيام', style: st(16.5, bold: true)),
            Text('الأسبوع الماضي: ${Ar.num(lastWeek)} صفحة', style: st(15)),
            Text('قراءتك $cmp.', style: TextStyle(fontSize: 14.5, height: 1.7, color: C.muted(context))),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(Ar.num(counts[i]), style: TextStyle(fontSize: 12, color: C.muted(context))),
                  const SizedBox(height: 4),
                  Container(
                    height: 6 + 110 * counts[i] / top,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: counts[i] > 0 ? C.accent(context) : C.accent(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(child: Text(_weekdays[days[i].weekday - 1], style: TextStyle(fontSize: 11, color: C.muted(context)))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Text('الصفحات تُحسب بعدد مرات تقليب الصفحات في القراءة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
      ]),
    );
  }
}

/// «قوائمي للكتب»: named lists of books the reader makes.
class ShelvesScreen extends StatelessWidget {
  const ShelvesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('قوائمي للكتب')),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: const Text('قائمة جديدة'),
          onPressed: () => _newShelf(context),
        ),
        body: ListenableBuilder(
          listenable: Store.i,
          builder: (context, _) {
            final names = Store.i.shelves.keys.toList();
            if (names.isEmpty) {
              return const EmptyNote(Icons.collections_bookmark_outlined, 'أنشئ قائمة، مثل «أقرؤها هذا الشهر» أو «للحفظ»، ثم أضِف إليها الكتب.');
            }
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [for (final n in names) _ShelfCard(n)]);
          },
        ),
      );
}

Future<void> _newShelf(BuildContext context) async {
  final ctl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('اسم القائمة'),
      content: TextField(controller: ctl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('إنشاء')),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;
  if (Store.i.shelves.containsKey(name)) {
    if (context.mounted) toast(context, 'توجد قائمة بهذا الاسم');
    return;
  }
  Store.i.createShelf(name);
}

class _ShelfCard extends StatelessWidget {
  final String name;
  const _ShelfCard(this.name);

  @override
  Widget build(BuildContext context) {
    final ids = Store.i.shelves[name] ?? const <int>[];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('$name (${Ar.books(ids.length)})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context)))),
            IconButton(
              tooltip: 'شارك القائمة',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Share.share('$name:\n${ids.map((id) => '- ${Catalog.byId[id]?.shortName ?? ''}').join('\n')}\n$siteUrl'),
            ),
            IconButton(
              tooltip: 'احذف القائمة',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => Store.i.deleteShelf(name),
            ),
          ]),
          for (final id in ids)
            if (Catalog.byId[id] != null)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(Catalog.byId[id]!.shortName, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => openReader(context, Catalog.byId[id]!, Store.i.lastPg[id] ?? 1),
                trailing: IconButton(
                  tooltip: 'أزله من القائمة',
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: () => Store.i.toggleShelf(name, id),
                ),
              ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('أضِف كتابًا'),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _BookPicker(name),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BookPicker extends StatelessWidget {
  final String shelf;
  const _BookPicker(this.shelf);

  @override
  Widget build(BuildContext context) {
    final books = Catalog.byId.values.where((b) => b.pages > 0).toList()..sort((a, b) => a.shortName.compareTo(b.shortName));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final inShelf = Store.i.shelves[shelf] ?? const <int>[];
          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, i) {
              final b = books[i];
              final on = inShelf.contains(b.id);
              return ListTile(
                title: Text(b.shortName, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: on ? C.accent(context) : null),
                onTap: () => Store.i.toggleShelf(shelf, b.id),
              );
            },
          );
        },
      ),
    );
  }
}

/// «وقت القراءة اليومي»: a time to be reminded to read, if the day has no reading yet.
Future<void> setDailyReminder(BuildContext context) async {
  final cur = Store.i.dailyMinutes;
  final picked = await showTimePicker(
    context: context,
    initialTime: cur >= 0 ? TimeOfDay(hour: cur ~/ 60, minute: cur % 60) : TimeOfDay.now(),
  );
  if (picked != null) {
    Store.i.setDailyMinutes(picked.hour * 60 + picked.minute);
    if (context.mounted) toast(context, 'سيذكّرك التطبيق في ${picked.format(context)} إن لم تقرأ اليوم');
  }
}

/// The reminder time as written in Arabic digits, e.g. «٩:٣٠».
String dailyText() {
  final m = Store.i.dailyMinutes;
  final mm = m % 60;
  return '${Ar.num(m ~/ 60)}:${Ar.num(mm < 10 ? '0$mm' : '$mm')}';
}

/// Opens the reader on the last book read, used by reminders.
void openLastBook(BuildContext context) {
  if (Store.i.recent.isEmpty) return;
  final id = Store.i.recent.first;
  final b = Catalog.byId[id];
  if (b != null) openReader(context, b, Store.i.lastPg[id] ?? 1);
}
