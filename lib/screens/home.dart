import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../catalog.dart';
import '../fawaid.dart';
import '../main.dart' show shellTab;
import '../store.dart';
import '../ui.dart';
import '../update.dart';
import 'book.dart';
import 'fawaid.dart';
import 'more.dart';
import 'review.dart';
import 'reader.dart';
import 'scholar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final recent = Store.i.recent.where(Catalog.byId.containsKey).take(12).toList();
        final lastHl = Store.i.highlights.isEmpty ? null : Store.i.highlights.first;
        return SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
            const _Header(),
            ValueListenableBuilder<int>(
              valueListenable: Updates.newer,
              builder: (context, n, _) => n == 0
                  ? const SizedBox.shrink()
                  : _Banner(
                      icon: Icons.system_update_rounded,
                      title: 'نسخة جديدة من التطبيق',
                      text: 'اضغط لتحميل النسخة ${Ar.num(n)} وتثبيتها فوق القديمة.',
                      onTap: () => openLink(apkUrl),
                    ),
            ),
            if (kIsWeb)
              _Banner(
                icon: Icons.android_rounded,
                title: 'حمّل تطبيق أندرويد',
                text: 'لتقرأ الكتب وتبحث فيها بلا إنترنت بعد تحميلها.',
                onTap: () => openLink(apkUrl),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Material(
                color: C.card(context),
                shape: StadiumBorder(side: BorderSide(color: C.line(context))),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => shellTab.value = 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                    child: Row(children: [
                      Icon(Icons.search_rounded, color: C.accent(context)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('ابحث في كتب العلماء…', style: TextStyle(fontSize: 16, color: C.muted(context)))),
                    ]),
                  ),
                ),
              ),
            ),
            if (Fawaid.today() != null) ...[
              SectionTitle('الفوائد المنتقاة', onMore: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FawaidScreen()))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: FaidaCard(Fawaid.today()!, title: 'فائدة اليوم')),
            ],
            if (recent.isNotEmpty) ...[
              const SectionTitle('أكمل القراءة'),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _ContinueCard(Catalog.byId[recent[i]]!),
                ),
              ),
            ],
            SectionTitle('العلماء', onMore: null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 560 ? 3 : 2;
                final w = (c.maxWidth - (cols - 1) * 10) / cols;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final s in Catalog.people) SizedBox(width: w, child: _ScholarCard(s)),
                ]);
              }),
            ),
            if (Catalog.sections.isNotEmpty) ...[
              SectionTitle('أقسام الكتب', onMore: null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 560 ? 3 : 2;
                  final w = (c.maxWidth - (cols - 1) * 10) / cols;
                  return Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final s in Catalog.sections) SizedBox(width: w, child: _ScholarCard(s)),
                  ]);
                }),
              ),
            ],
            const SectionTitle('المزيد', onMore: null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 560 ? 3 : 1;
                final w = (c.maxWidth - (cols - 1) * 10) / cols;
                Widget tile(IconData icon, String title, String text, VoidCallback tap) => SizedBox(
                      width: w,
                      child: SoftCard(
                        onTap: tap,
                        child: Row(children: [
                          RoundIcon(icon, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
                              Text(text, style: TextStyle(fontSize: 13, color: C.muted(context))),
                            ]),
                          ),
                          Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                        ]),
                      ),
                    );
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  tile(Icons.forum_outlined, 'فوائد القرّاء', 'ما ينشره القرّاء من اقتباساتهم', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadersFawaidScreen()))),
                  tile(Icons.autorenew_rounded, 'احفظ وراجِع', Store.i.dueReviews().isEmpty ? 'مراجعة ما حفظته في أوقات متباعدة' : 'لديك ${Ar.num(Store.i.dueReviews().length)} للمراجعة الآن', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewScreen()))),
                  tile(Icons.school_outlined, 'منهج طالب العلم', 'كتب مرتّبة بالتدرّج', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MinhajScreen()))),
                  tile(Icons.shuffle_rounded, 'افتح لي صفحة', 'صفحة عشوائية من المكتبة', () => openRandomPage(context)),
                ]);
              }),
            ),
            if (Store.i.recent.isNotEmpty && Store.i.idleDays() >= 3 && Catalog.byId[Store.i.recent.first] != null)
              _Banner(
                icon: Icons.schedule_rounded,
                title: 'استأنف قراءتك',
                text: 'لم تفتح «${Catalog.byId[Store.i.recent.first]!.shortName}» منذ ${Ar.num(Store.i.idleDays())} أيام.',
                onTap: () => openReader(context, Catalog.byId[Store.i.recent.first]!, Store.i.lastPg[Store.i.recent.first] ?? 1),
              ),
            if (rateReminderDue())
              _Banner(icon: Icons.thumb_up_alt_outlined, title: 'قيّم التطبيق', text: 'تقييمك يعين على وصول المكتبة إلى غيرك.', onTap: () => rateApp(context)),
            if (lastHl != null && Catalog.byId[lastHl.book] != null) ...[
              SectionTitle('من مظلّلاتك', onMore: () => shellTab.value = 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SoftCard(
                  onTap: () => openReader(context, Catalog.byId[lastHl.book]!, lastHl.pg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: hlColor(lastHl.color), borderRadius: BorderRadius.circular(6)),
                      child: Text(lastHl.text, maxLines: 5, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: bookFont, fontSize: 18, height: 1.8, color: C.ink(context))),
                    ),
                    const SizedBox(height: 10),
                    Text('${Catalog.byId[lastHl.book]!.shortName} · ${lastHl.label}', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                  ]),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
              child: Text(
                Catalog.totalBooks > 0
                    ? '${Ar.books(Catalog.totalBooks)} · النصوص من مكتبة «تراث»'
                    : 'النصوص من مكتبة «تراث»',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: C.muted(context)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFF1F5C4A), Color(0xFF2E7A62)], begin: Alignment.topRight, end: Alignment.bottomLeft),
          ),
          child: const Icon(Icons.menu_book_rounded, color: Color(0xFFF1DFA8), size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مكتبة العلماء السلفية', style: TextStyle(fontFamily: bookFont, fontSize: 25, fontWeight: FontWeight.w700, color: C.ink(context), height: 1.4)),
            Text(Hijri.today(), style: TextStyle(fontSize: 13.5, color: C.muted(context))),
          ]),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final VoidCallback onTap;
  const _Banner({required this.icon, required this.title, required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      color: C.accent(context).withValues(alpha: 0.10),
      onTap: onTap,
      child: Row(children: [
        RoundIcon(icon, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.accent(context))),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(fontSize: 13.5, color: C.ink(context), height: 1.5)),
          ]),
        ),
        Icon(Icons.chevron_left_rounded, color: C.accent(context)),
      ]),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final BookInfo book;
  const _ContinueCard(this.book);
  @override
  Widget build(BuildContext context) {
    final pg = Store.i.lastPg[book.id] ?? 1;
    final frac = book.pages > 0 ? (pg / book.pages).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 230,
      child: SoftCard(
        onTap: () => openReader(context, book, pg),
        onLongPress: () => openBook(context, book),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ScholarMark(book.scholar.short, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(book.scholar.short, style: TextStyle(fontSize: 13.5, color: C.muted(context)), maxLines: 1)),
            if (Store.i.downloaded.contains(book.id)) Icon(Icons.download_done_rounded, size: 18, color: C.accent(context)),
          ]),
          const SizedBox(height: 10),
          Text(book.shortName,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: bookFont, fontSize: 17, height: 1.5, fontWeight: FontWeight.w700, color: C.ink(context))),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: frac, minHeight: 5, backgroundColor: C.soft(context), color: C.gold(context)),
          ),
          const SizedBox(height: 5),
          Text('${Ar.num(pg)} من ${Ar.num(book.pages)}', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        ]),
      ),
    );
  }
}

class _ScholarCard extends StatelessWidget {
  final Scholar s;
  const _ScholarCard(this.s);
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScholarScreen(s))),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ScholarMark(s.short, size: 46),
        const SizedBox(height: 10),
        Text(s.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 2),
        Text(s.collection ? 'قسم' : s.deathText, style: TextStyle(fontSize: 13, color: C.muted(context))),
        const SizedBox(height: 8),
        Tag(s.books.isEmpty ? 'قريبًا' : Ar.books(s.books.length), color: C.accent(context)),
      ]),
    );
  }
}
