import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../store.dart';
import '../ui.dart';
import '../update.dart';
import 'colors.dart';
import '../files/files.dart';
import 'fawaid.dart' show PendingFawaidScreen;
import 'more.dart';
import 'reader.dart' show showReadingLook;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final st = Store.i;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 110), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text('الإعدادات', style: TextStyle(fontFamily: bookFont, fontSize: 26, fontWeight: FontWeight.w700, color: C.ink(context))),
            ),
            _Group(title: 'المظهر', children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, icon: Icon(Icons.brightness_auto_rounded), label: Text('كالجوال')),
                    ButtonSegment(value: 1, icon: Icon(Icons.light_mode_rounded), label: Text('نهاري')),
                    ButtonSegment(value: 2, icon: Icon(Icons.dark_mode_rounded), label: Text('ليلي')),
                  ],
                  selected: {st.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => st.setSettings(themeMode: s.first),
                ),
              ),
              _Row(icon: Icons.text_fields_rounded, title: 'الخط ولون الصفحة', sub: 'حجم الخط ${Ar.num(st.fontSize.round())} · ${st.readFont == 'Amiri' ? 'أميري' : 'تجوّل'}', onTap: () => showReadingLook(context)),
              _Row(icon: Icons.palette_outlined, title: 'ألوان التظليل وأسماؤها', sub: [for (final c in st.colors) c.name].join('، '), onTap: () => showColorsSheet(context)),
              SwitchListTile(
                secondary: const _Ico(Icons.font_download_rounded),
                title: const Text('إظهار التشكيل في الكتب'),
                value: st.tashkeel,
                onChanged: (v) => st.setSettings(tashkeel: v),
              ),
            ]),
            _Group(title: 'القراءة', children: [
              SwitchListTile(
                secondary: const _Ico(Icons.notes_rounded),
                title: const Text('إخفاء الحواشي'),
                subtitle: const Text('يظهر المتن وحده'),
                value: st.hideFoot,
                onChanged: (v) => st.setSettings(hideFoot: v),
              ),
              if (!kIsWeb)
                SwitchListTile(
                  secondary: const _Ico(Icons.light_mode_outlined),
                  title: const Text('الشاشة لا تنطفئ أثناء القراءة'),
                  value: st.keepOn,
                  onChanged: (v) => st.setSettings(keepOn: v),
                ),
              ListTile(
                leading: const _Ico(Icons.tune_rounded),
                title: const Text('أزرار شريط التحديد'),
                subtitle: const Text('اختر ما يظهر منها ورتّبها بالسحب'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolsScreen())),
              ),
              if (!kIsWeb)
                SwitchListTile(
                  secondary: const _Ico(Icons.notifications_active_outlined),
                  title: const Text('تنبيه بموعد المراجعة'),
                  subtitle: const Text('إشعار حين يحين موعد مراجعة ما حفظتَه في «احفظ وراجِع»'),
                  value: st.reviewNotify,
                  onChanged: (v) => st.setSettings(reviewNotify: v),
                ),
              if (!kIsWeb)
                ListTile(
                  leading: const _Ico(Icons.bedtime_outlined),
                  title: const Text('مؤقت إطفاء الشاشة أثناء القراءة'),
                  subtitle: Text(st.sleepMinutes == 0 ? 'معطّل' : 'بعد ${Ar.num(st.sleepMinutes)} دقيقة من بدء القراءة'),
                  onTap: () => _pickSleep(context),
                ),
              if (!kIsWeb)
                SwitchListTile(
                  secondary: const _Ico(Icons.volume_up_outlined),
                  title: const Text('تقليب الصفحات بزرّي الصوت'),
                  subtitle: const Text('الأسفل للصفحة التالية، والأعلى للسابقة'),
                  value: st.volKeys,
                  onChanged: (v) => st.setSettings(volKeys: v),
                ),
              if (BookFiles.supported)
                _Row(
                  icon: Icons.sd_storage_outlined,
                  title: 'الكتب المحمّلة ومساحتها',
                  sub: '${Ar.books(st.downloaded.length)} على الجوال',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageScreen())),
                ),
            ]),
            _Group(title: 'نسخة من مكتبتي', children: [
              _Row(
                icon: Icons.upload_rounded,
                title: 'انسخ مظلّلاتي واقتباساتي وفواصلي',
                sub: 'احفظ النص في مكان آمن، أو انقله إلى جوال جديد',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: st.backup()));
                  toast(context, 'نُسخت مكتبتك، الصقها في ملاحظة أو رسالة لنفسك');
                },
              ),
              _Row(
                icon: Icons.ios_share_rounded,
                title: 'شارك مظلّلاتي وملاحظاتي نصًّا',
                sub: 'نص مرتّب بالمصادر، ترسله أو تطبعه',
                onTap: () {
                  if (st.highlights.isEmpty && st.quotes.isEmpty && st.notes.isEmpty) {
                    toast(context, 'ليس في مكتبتك شيء بعد');
                    return;
                  }
                  Share.share(st.exportText((id) => Catalog.byId[id]?.shortName ?? 'كتاب'));
                },
              ),
              _Row(
                icon: Icons.save_alt_rounded,
                title: 'احفظ نسخة كملف',
                sub: 'يُحفظ ملف النسخة في التنزيلات أو الملفات، أو تشاركه',
                onTap: () => _saveFile(context),
              ),
              _Row(icon: Icons.restore_rounded, title: 'استعادة نسخة احتياطية', sub: 'اختر ملف النسخة الذي حفظته، فيُضاف كل شيء', onTap: () => _restoreFile(context)),
              _Row(icon: Icons.download_rounded, title: 'أرجع نسخة', sub: 'الصق النص الذي نسخته من قبل', onTap: () => _restore(context)),
            ]),
            _Group(title: 'عن التطبيق', children: [
              _Row(
                icon: Icons.menu_book_rounded,
                title: 'عن التطبيق',
                sub: 'نسخة ${Ar.num(appBuild)} · ${Ar.books(Catalog.totalBooks)}',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
              ),
              _Row(icon: Icons.ios_share_rounded, title: 'شارك التطبيق', sub: 'أرسل رابط المكتبة لمن تحب', onTap: shareApp),
              _Row(icon: Icons.thumb_up_alt_outlined, title: 'قيّم التطبيق', sub: 'يتوفّر بعد نشره في المتجر', onTap: () => rateApp(context)),
              _Row(
                icon: Icons.person_rounded,
                title: 'المطوّر',
                sub: developerName,
                // hidden door: a long press opens the developer's review page
                onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingFawaidScreen())),
              ),
              _Row(icon: Icons.send_rounded, title: 'تواصل مع المطوّر', sub: 'تيليجرام', onTap: () => openLink(contactUrl)),
              if (kIsWeb)
                _Row(icon: Icons.android_rounded, title: 'تطبيق أندرويد', sub: 'للقراءة والبحث بلا إنترنت', onTap: () => openLink(apkUrl))
              else
                _Row(icon: Icons.public_rounded, title: 'موقع المكتبة', sub: 'افتح المكتبة في المتصفح', onTap: () => openLink(siteUrl)),
              _Row(icon: Icons.library_books_rounded, title: 'مصدر النصوص', sub: 'مكتبة «تراث» (turath.io)', onTap: () => openLink('https://app.turath.io')),
            ]),
          ]);
        },
      ),
    );
  }

  Future<void> _pickSleep(BuildContext context) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('مؤقت إطفاء الشاشة'),
        children: [
          for (final m in const [0, 15, 30, 60])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, m),
              child: Text(m == 0 ? 'معطّل' : '${Ar.num(m)} دقيقة'),
            ),
        ],
      ),
    );
    if (picked != null) Store.i.setSettings(sleepMinutes: picked);
  }

  /// Saves everything personal as a JSON file, and opens the share sheet so it can be saved to Downloads.
  Future<void> _saveFile(BuildContext context) async {
    try {
      final name = 'salafi-backup-${Store.dayKey()}.json';
      final bytes = Uint8List.fromList(utf8.encode(Store.i.backup()));
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'application/json', name: name)], fileNameOverrides: [name], subject: 'نسخة احتياطية من مكتبة العلماء السلفية');
    } catch (_) {
      if (context.mounted) toast(context, 'تعذّر حفظ الملف');
    }
  }

  /// Restores from a backup file chosen by the reader. Nothing already here is removed.
  Future<void> _restoreFile(BuildContext context) async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      final bytes = picked?.files.single.bytes;
      if (bytes == null || !context.mounted) return;
      final n = Store.i.restore(utf8.decode(bytes));
      toast(context, 'أُرجع ${Ar.num(n)} عنصرًا');
    } catch (_) {
      if (context.mounted) toast(context, 'هذا الملف ليس نسخة احتياطية صحيحة');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('أرجع نسخة'),
        content: TextField(controller: ctl, maxLines: 6, decoration: const InputDecoration(hintText: 'الصق النص هنا')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('أرجع')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    try {
      final n = Store.i.restore(text);
      toast(context, 'أُرجع ${Ar.num(n)} عنصرًا');
    } catch (_) {
      toast(context, 'النص غير صحيح');
    }
  }
}

/// The buttons of the reader's selection bar: shown or hidden, and their order.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  static const all = ['انسخ الآية', 'نسخ', 'نسخ بالمصدر', 'اقتباس', 'اقتبس المظلّل', 'مشاركة', 'مشاركة صورة', 'ملاحظة', 'المعجم', 'أصل النقل'];
  late final List<String> order = [...Store.i.toolOrder.where(all.contains), ...all.where((t) => !Store.i.toolOrder.contains(t))];
  late final Set<String> hidden = {...Store.i.hiddenTools};

  void _save() => Store.i.setTools(order, hidden);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أزرار شريط التحديد')),
      body: ReorderableListView(
        padding: const EdgeInsets.only(bottom: 30),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Text('هذه الأزرار تظهر حين تحدّد نصًّا في القراءة. أطفئ ما لا تستعمله، واسحب لتغيير الترتيب. الألوان والإغلاق ثابتان.',
              style: TextStyle(fontSize: 13.5, height: 1.7, color: C.muted(context))),
        ),
        onReorder: (a, b) => setState(() {
          if (b > a) b--;
          order.insert(b, order.removeAt(a));
          _save();
        }),
        children: [
          for (final t in order)
            SwitchListTile(
              key: ValueKey(t),
              secondary: const Icon(Icons.drag_handle_rounded),
              title: Text(t),
              value: !hidden.contains(t),
              onChanged: (v) => setState(() {
                v ? hidden.remove(t) : hidden.add(t);
                _save();
              }),
            ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
        child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.muted(context))),
      ),
      Material(
        color: C.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: C.line(context))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    ]);
  }
}

class _Ico extends StatelessWidget {
  final IconData icon;
  const _Ico(this.icon);
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: C.accent(context).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: C.accent(context)),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _Row({required this.icon, required this.title, this.sub, this.onTap, this.onLongPress});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: _Ico(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: sub == null ? null : Text(sub!),
        trailing: onTap == null ? null : Icon(Icons.chevron_left_rounded, color: C.muted(context)),
        onTap: onTap,
        onLongPress: onLongPress,
      );
}
