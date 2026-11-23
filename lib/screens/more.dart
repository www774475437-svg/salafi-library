import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../files/files.dart';
import '../store.dart';
import '../turath.dart';
import '../ui.dart';
import '../update.dart';
import 'reader.dart';
import 'scholar.dart' show BookTile;

/// Opens a page at random from the whole library.
void openRandomPage(BuildContext context) {
  final books = Catalog.byId.values.where((b) => b.pages > 0).toList();
  if (books.isEmpty) return;
  final r = Random();
  final b = books[r.nextInt(books.length)];
  openReader(context, b, 1 + r.nextInt(b.pages));
}

void shareApp() => Share.share('مكتبة العلماء السلفية: كتب العلماء للقراءة والبحث بلا إنترنت\n$siteUrl');

/// Asked for now and then; does nothing until the app is in the store.
void rateApp(BuildContext context) {
  if (storeUrl.isEmpty) {
    toast(context, 'التقييم يتوفّر قريبًا بإذن الله');
  } else {
    openLink(storeUrl);
  }
}

/// True on the days the reader may be reminded to rate the app:
/// after a week, a month, three months, six months and a year.
bool rateReminderDue() {
  if (storeUrl.isEmpty || Store.i.firstRun == 0) return false;
  final days = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(Store.i.firstRun)).inDays;
  return const [7, 30, 90, 180, 365].any((d) => days >= d && days < d + 3);
}

/// Downloaded books and the room each takes on the phone.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});
  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final Map<int, int> sizes = {};
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    for (final id in Store.i.downloaded.toList()) {
      sizes[id] = await BookFiles.size(id);
    }
    if (mounted) setState(() => loaded = true);
  }

  String _mb(int bytes) => bytes < 1024 * 1024 ? '${Ar.num((bytes / 1024).ceil())} ك.ب' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';

  Future<void> _delete(int id) async {
    await BookFiles.delete(id);
    Store.i.setDownloaded(id, false);
    sizes.remove(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ids = Store.i.downloaded.toList()..sort((a, b) => (sizes[b] ?? 0).compareTo(sizes[a] ?? 0));
    final total = sizes.values.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(title: const Text('الكتب المحمّلة ومساحتها')),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : ids.isEmpty
              ? const EmptyNote(Icons.download_rounded, 'لم تحمّل كتابًا بعد.')
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                  SoftCard(
                    child: Row(children: [
                      Expanded(
                        child: Text('${Ar.books(ids.length)} · ${_mb(total)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('احذف الكل'),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              content: const Text('تُحذف كل الكتب المحمّلة من الجوال؟ مظلّلاتك وملاحظاتك تبقى، وتستطيع تحميل الكتب مرة أخرى.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('احذف الكل')),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          for (final id in ids) {
                            await _delete(id);
                          }
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  for (final id in ids)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(Catalog.byId[id]?.shortName ?? 'كتاب $id', maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_mb(sizes[id] ?? 0)),
                        trailing: IconButton(tooltip: 'احذف من الجوال', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(id)),
                      ),
                    ),
                ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget line(IconData i, String t, String s, [VoidCallback? tap]) => ListTile(
          leading: Icon(i, color: C.accent(context)),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(s),
          onTap: tap,
        );
    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        SoftCard(
          child: Column(children: [
            const Icon(Icons.menu_book_rounded, size: 54, color: green),
            const SizedBox(height: 8),
            Text('مكتبة العلماء السلفية', style: TextStyle(fontFamily: bookFont, fontSize: 24, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 6),
            Text('كتب العلماء للقراءة والبحث والتظليل والاقتباس، بلا إنترنت بعد تحميلها.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, height: 1.7, color: C.muted(context))),
          ]),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(children: [
            line(Icons.person_rounded, 'المطوّر', developerName),
            line(Icons.send_rounded, 'تواصل مع المطوّر', 'تيليجرام', () => openLink(contactUrl)),
            line(Icons.tag_rounded, 'الإصدار', 'نسخة ${Ar.num(appBuild)} · ${Ar.books(Catalog.totalBooks)}'),
            line(Icons.inventory_2_outlined, 'الكتب المحفوظة في مخازن المكتبة', Ar.books(Turath.hosted.length)),
            line(Icons.library_books_rounded, 'مصدر النصوص', 'مكتبة «تراث» (turath.io)', () => openLink('https://app.turath.io')),
          ]),
        ),
      ]),
    );
  }
}

/// «منهج طالب العلم»: books in steps. Empty until its books are chosen.
class MinhajScreen extends StatelessWidget {
  const MinhajScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('منهج طالب العلم')),
        body: const EmptyNote(Icons.school_outlined, 'يتوفّر قريبًا بإذن الله.'),
      );
}

/// Books the reader put aside to read later.
class ReadLaterList extends StatelessWidget {
  const ReadLaterList({super.key});
  @override
  Widget build(BuildContext context) {
    final books = Store.i.readLater.map((id) => Catalog.byId[id]).whereType<BookInfo>().toList();
    return books.isEmpty
        ? const EmptyNote(Icons.watch_later_outlined, 'افتح صفحة أي كتاب واضغط «سأقرؤه لاحقًا»، فيظهر هنا.')
        : ListView(padding: const EdgeInsets.only(top: 6, bottom: 110), children: [for (final b in books) BookTile(b)]);
  }
}

/// «فوائد القرّاء»: what readers publish from their quotes, with likes,
/// follows and a profile for each. The screens are ready; accounts come later.
class ReadersFawaidScreen extends StatelessWidget {
  const ReadersFawaidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void soon() => toast(context, 'يتوفّر قريبًا بإذن الله');
    Widget stat(String n, String label) => Expanded(
          child: Column(children: [
            Text(n, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
            Text(label, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
          ]),
        );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فوائد القرّاء'),
          actions: [IconButton(tooltip: 'ابحث برقم القارئ', icon: const Icon(Icons.person_search_rounded), onPressed: soon)],
          bottom: const TabBar(tabs: [Tab(text: 'الجديد'), Tab(text: 'من أتابعهم'), Tab(text: 'ملفّي')]),
        ),
        body: TabBarView(children: [
          const EmptyNote(Icons.forum_outlined, 'هنا تظهر الفوائد التي ينشرها القرّاء من اقتباساتهم، مع الإعجاب والمتابعة.\nيتوفّر قريبًا بإذن الله.'),
          const EmptyNote(Icons.group_outlined, 'هنا تظهر فوائد من تتابعهم.\nيتوفّر قريبًا بإذن الله.'),
          ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
            SoftCard(
              child: Column(children: [
                CircleAvatar(radius: 34, backgroundColor: C.accent(context).withValues(alpha: 0.14), child: Icon(Icons.person_rounded, size: 38, color: C.accent(context))),
                const SizedBox(height: 10),
                Text('زائر', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
                Text('الرقم الشخصي: ـــــــ', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                const SizedBox(height: 14),
                Row(children: [stat('٠', 'فوائدي'), stat('٠', 'الإعجابات'), stat('٠', 'المتابِعون'), stat('٠', 'أتابعهم')]),
              ]),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: soon, icon: const Icon(Icons.login_rounded), label: const Text('الدخول بحساب جوجل')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: soon, icon: const Icon(Icons.person_add_alt_rounded), label: const Text('إنشاء حساب بالاسم')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: soon, icon: const Icon(Icons.support_agent_rounded), label: const Text('تواصل معنا (ثلاث رسائل في اليوم)')),
            const SizedBox(height: 14),
            Text('بعد الدخول: تنشر اقتباساتك بموضوعاتها، ويراها القرّاء ويعجبون بها ويتابعونك، ولا مراسلة بين القرّاء.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.7, color: C.muted(context))),
          ]),
        ]),
      ),
    );
  }
}
