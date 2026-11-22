import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog.dart';
import '../store.dart';
import '../ui.dart';
import '../update.dart';
import 'colors.dart';
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
              _Row(icon: Icons.download_rounded, title: 'أرجع نسخة', sub: 'الصق النص الذي نسخته من قبل', onTap: () => _restore(context)),
            ]),
            _Group(title: 'عن التطبيق', children: [
              _Row(icon: Icons.menu_book_rounded, title: 'مكتبة العلماء السلفية', sub: 'نسخة ${Ar.num(appBuild)} · ${Ar.books(Catalog.totalBooks)}'),
              _Row(icon: Icons.person_rounded, title: 'المطوّر', sub: developerName),
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
  const _Row({required this.icon, required this.title, this.sub, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: _Ico(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: sub == null ? null : Text(sub!),
        trailing: onTap == null ? null : Icon(Icons.chevron_left_rounded, color: C.muted(context)),
        onTap: onTap,
      );
}
