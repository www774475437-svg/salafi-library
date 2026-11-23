import 'package:flutter/material.dart';

import '../catalog.dart';
import '../store.dart';
import '../ui.dart';
import 'reader.dart';

/// «احفظ وراجِع»: the highlights, quotes and notes put to review, shown
/// one at a time when they are due. Remembered ones come back later.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    Store.i.addListener(_refresh);
  }

  @override
  void dispose() {
    Store.i.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final due = s.dueReviews();
    final total = s.review.length;
    final first = due.isEmpty ? null : due.first;
    return Scaffold(
      appBar: AppBar(title: const Text('احفظ وراجِع')),
      body: total == 0
          ? const EmptyNote(Icons.autorenew_rounded, 'اضغط علامة المراجعة على أي اقتباس أو مظلّل أو ملاحظة، فيُعاد عليك في أوقات متباعدة حتى يثبت في حفظك.')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
              SoftCard(
                child: Row(children: [
                  Expanded(
                    child: Text(
                      due.isEmpty ? 'لا مراجعة الآن. محفوظ للمراجعة: ${Ar.num(total)}' : 'للمراجعة الآن: ${Ar.num(due.length)} من ${Ar.num(total)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (first == null)
                const EmptyNote(Icons.check_circle_outline_rounded, 'أحسنت، لا شيء يستحقّ المراجعة الآن. ستظهر المادة عند موعدها.')
              else
                _ReviewCard(first, key: ValueKey(first.id)),
            ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Kept k;
  const _ReviewCard(this.k, {super.key});

  @override
  Widget build(BuildContext context) {
    final book = Catalog.byId[k.book];
    final name = book?.shortName ?? 'كتاب';
    final stage = Store.i.review[k.id]?[0] ?? 0;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('«${k.text}»', style: TextStyle(fontFamily: bookFont, fontSize: 19, height: 1.9, color: C.ink(context))),
        const SizedBox(height: 10),
        Text('$name · ${k.label}', style: TextStyle(fontSize: 13, color: C.muted(context))),
        if (k.note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('ملاحظتي: ${k.note}', style: TextStyle(fontSize: 15, height: 1.6, color: C.ink(context))),
        ],
        const SizedBox(height: 6),
        Text('المرحلة ${Ar.num(stage + 1)} من ${Ar.num(reviewDays.length)}', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: const Text('تذكّرتُه'),
              onPressed: () => Store.i.answerReview(k.id, true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('لم أتذكّره'),
              onPressed: () => Store.i.answerReview(k.id, false),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 4, children: [
          if (book != null)
            TextButton.icon(
              onPressed: () => openReader(context, book, k.pg),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('افتح موضعه'),
            ),
          TextButton.icon(
            onPressed: () => Store.i.toggleReview(k),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            label: const Text('أخرجه من المراجعة'),
          ),
        ]),
      ]),
    );
  }
}
