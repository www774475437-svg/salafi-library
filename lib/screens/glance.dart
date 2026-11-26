import 'package:flutter/material.dart';

import '../catalog.dart';
import '../store.dart';
import '../ui.dart';
import 'reader.dart';

/// «الاطلاع السريع»: a summary of today, then the reading log (what was opened,
/// marked, highlighted and quoted), newest first.
class QuickGlanceScreen extends StatelessWidget {
  const QuickGlanceScreen({super.key});

  static String _kindName(String k) => switch (k) {
        'open' => 'فتحتَ الكتاب',
        'read' => 'علّمتَ الصفحة مقروءة',
        'hl' => 'ظلّلتَ نصًّا',
        'quote' => 'اقتبستَ نصًّا',
        _ => 'نشاط',
      };

  static String _when(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final min = t.minute < 10 ? '0${t.minute}' : '${t.minute}';
    return '${Ar.num(t.day)}/${Ar.num(t.month)} · ${Ar.num(t.hour)}:${Ar.num(int.parse(min))}';
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final today = s.logToday();
    final pages = s.dayPages[Store.dayKey()] ?? 0;
    final booksToday = {for (final e in today) if (e['k'] == 'open') e['b'] as int}.length;
    final quotesToday = today.where((e) => e['k'] == 'quote').length;
    final hlToday = today.where((e) => e['k'] == 'hl').length;
    final due = s.dueReviews().length;
    final log = s.readLog;

    return Scaffold(
      appBar: AppBar(title: const Text('الاطلاع السريع')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اليوم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.ink(context))),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Stat('صفحات', pages),
              _Stat('كتب فتحتها', booksToday),
              _Stat('مظلّلات', hlToday),
              _Stat('اقتباسات', quotesToday),
              _Stat('للمراجعة', due),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Text('سجل القراءة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.ink(context))),
        const SizedBox(height: 8),
        if (log.isEmpty)
          const EmptyNote(Icons.history_rounded, 'لم تُسجَّل بعد أي قراءة. ستظهر هنا كل ما تفعله: الكتب التي تفتحها، والصفحات، والمظلّلات، والاقتباسات.')
        else
          for (final e in log)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LogRow(entry: e, onTap: () {
                final book = Catalog.byId[e['b'] as int];
                if (book != null) openReader(context, book, e['p'] as int);
              }),
            ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String name;
  final int value;
  const _Stat(this.name, this.value);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: C.accent(context).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(Ar.num(value), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.accent(context))),
        const SizedBox(height: 2),
        Text(name, style: TextStyle(fontSize: 12, color: C.muted(context))),
      ]),
    );
  }
}

class _LogRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  const _LogRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final book = Catalog.byId[entry['b'] as int];
    final text = (entry['x'] as String?) ?? '';
    final kind = entry['k'] as String;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(QuickGlanceScreen._kindName(kind), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: C.ink(context))),
            ),
            Text(QuickGlanceScreen._when(entry['t'] as int), style: TextStyle(fontSize: 12, color: C.muted(context))),
          ]),
          const SizedBox(height: 4),
          Text('${book?.shortName ?? 'كتاب'} · صـ ${Ar.num(entry['p'] as int)}', style: TextStyle(fontSize: 13, color: C.muted(context))),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('«$text»', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: bookFont, fontSize: 16, height: 1.6, color: C.ink(context))),
          ],
        ]),
      ),
    );
  }
}
