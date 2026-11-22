import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Colours of «مكتبة العلماء السلفية»: warm paper, deep green and gold.
class C {
  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color bg(BuildContext c) => dark(c) ? const Color(0xFF0F1513) : const Color(0xFFF6F3EC);
  static Color card(BuildContext c) => dark(c) ? const Color(0xFF18211E) : const Color(0xFFFFFDF8);
  static Color line(BuildContext c) => dark(c) ? const Color(0xFF2A3632) : const Color(0xFFE4DCCB);
  static Color ink(BuildContext c) => dark(c) ? const Color(0xFFEAE4D8) : const Color(0xFF1C1F1D);
  static Color muted(BuildContext c) => dark(c) ? const Color(0xFF9AA39E) : const Color(0xFF75736C);
  static Color accent(BuildContext c) => dark(c) ? const Color(0xFF7FC4A8) : const Color(0xFF1F5C4A);
  static Color gold(BuildContext c) => dark(c) ? const Color(0xFFD9B970) : const Color(0xFFA9832F);
  static Color soft(BuildContext c) => dark(c) ? const Color(0xFF223029) : const Color(0xFFE9E3D4);
}

const green = Color(0xFF1F5C4A);
const gold = Color(0xFFA9832F);
const bookFont = 'Amiri';
const uiFont = 'Tajawal';

/// Highlight colours: yellow, red, green.
const hlColors = [Color(0x88FFD54F), Color(0x66EF5350), Color(0x6666BB6A)];
const hlNames = ['أصفر', 'أحمر', 'أخضر'];

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final accent = dark ? const Color(0xFF7FC4A8) : green;
  final bg = dark ? const Color(0xFF0F1513) : const Color(0xFFF6F3EC);
  final ink = dark ? const Color(0xFFEAE4D8) : const Color(0xFF1C1F1D);
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    fontFamily: uiFont,
    scaffoldBackgroundColor: bg,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: b, surface: bg, primary: accent),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: uiFont, fontSize: 20, fontWeight: FontWeight.w700, color: ink),
    ),
    textTheme: (dark ? Typography.material2021().white : Typography.material2021().black)
        .apply(fontFamily: uiFont, bodyColor: ink, displayColor: ink),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: green,
      contentTextStyle: TextStyle(fontFamily: uiFont, color: Colors.white, fontSize: 15),
    ),
  );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

/// Arabic-Indic digits.
class Ar {
  static const _d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static String num(Object n) => n.toString().split('').map((c) {
        final i = c.codeUnitAt(0) - 48;
        return i >= 0 && i <= 9 ? _d[i] : c;
      }).join();

  static String books(int n) {
    if (n == 1) return 'كتاب واحد';
    if (n == 2) return 'كتابان';
    if (n >= 3 && n <= 10) return '${num(n)} كتب';
    return '${num(n)} كتابًا';
  }

  static String pages(int n) {
    if (n == 1) return 'صفحة واحدة';
    if (n == 2) return 'صفحتان';
    if (n >= 3 && n <= 10) return '${num(n)} صفحات';
    return '${num(n)} صفحة';
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionTitle(this.title, {super.key, this.onMore});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink(context)))),
        if (onMore != null)
          InkWell(
            onTap: onMore,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('المزيد', style: TextStyle(fontSize: 16, color: C.accent(context))),
                Icon(Icons.chevron_left_rounded, color: C.accent(context), size: 22),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// A soft rounded card with a thin border.
class SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  const SoftCard({super.key, required this.child, this.onTap, this.onLongPress, this.padding = const EdgeInsets.all(16), this.margin = EdgeInsets.zero, this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? C.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: C.line(context))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, onLongPress: onLongPress, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class RoundIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  const RoundIcon(this.icon, {super.key, this.size = 48, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: C.soft(context), shape: BoxShape.circle),
      child: Icon(icon, color: color ?? C.accent(context), size: size * 0.5),
    );
  }
}

/// The scholar's round mark: the first letter of his short name in gold.
class ScholarMark extends StatelessWidget {
  final String name;
  final double size;
  const ScholarMark(this.name, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) {
    var n = name.replaceFirst(RegExp(r'^(ابن|الشيخ|الإمام)\s+'), '');
    n = n.replaceFirst(RegExp(r'^ال'), '');
    final letter = n.isEmpty ? '؟' : n.substring(0, 1);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF1F5C4A), Color(0xFF2E7A62)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: C.gold(context), width: 1.4),
      ),
      child: Text(letter, style: TextStyle(fontFamily: bookFont, fontSize: size * 0.46, color: const Color(0xFFF1DFA8), fontWeight: FontWeight.w700, height: 1.25)),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyNote(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(children: [
        RoundIcon(icon, size: 68),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: C.muted(context), height: 1.6)),
      ]),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  const Tag(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: (color ?? C.muted(context)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 12.5, color: color ?? C.muted(context), fontWeight: FontWeight.w500)),
      );
}

/// Approximate Hijri date (arithmetic calendar).
class Hijri {
  static const months = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];
  static const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  static String today() {
    final d = DateTime.now();
    final a = (14 - d.month) ~/ 12;
    final y = d.year + 4800 - a;
    final m = d.month + 12 * a - 3;
    final jd = d.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
    final hm = (24 * l) ~/ 709;
    final hd = l - (709 * hm) ~/ 24;
    final hy = 30 * n + j - 30;
    return '${weekdays[d.weekday - 1]} · ${Ar.num(hd)} ${months[(hm - 1).clamp(0, 11)]} ${Ar.num(hy)} هـ';
  }
}
