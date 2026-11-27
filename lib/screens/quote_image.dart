import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../ui.dart';

/// Shows the quote as a card and shares it as a picture.
void showQuoteImage(BuildContext context, {required String text, required String scholar, required String source}) {
  final key = GlobalKey();
  var tpl = 0;
  showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            child: RepaintBoundary(key: key, child: _Card(text: text.trim(), scholar: scholar, source: source, tpl: tpl)),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < cardTemplates.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => setSt(() => tpl = i),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: cardTemplates[i].$1, begin: Alignment.topRight, end: Alignment.bottomLeft),
                    border: Border.all(color: tpl == i ? Colors.white : Colors.white24, width: tpl == i ? 3 : 1),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13)),
            onPressed: () => _share(c, key),
            icon: const Icon(Icons.share_rounded),
            label: const Text('شارك الصورة', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          FilledButton.tonal(
            style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13)),
            onPressed: () => Navigator.pop(c),
            child: const Text('إغلاق'),
          ),
        ]),
      ]),
    ),
    ),
  );
}

/// Colour templates of the quote card: the two gradient colours and the gold of the frame.
const cardTemplates = <(List<Color>, Color)>[
  ([Color(0xFF17493B), Color(0xFF2E7A62)], Color(0xFFE1C478)), // أخضر وذهبي
  ([Color(0xFF0E1B2E), Color(0xFF1F4E79)], Color(0xFFE6C36A)), // أزرق ليلي وذهبي
  ([Color(0xFF2B1B12), Color(0xFF6B4226)], Color(0xFFF0D9A8)), // بني داكن
  ([Color(0xFF1C1C1C), Color(0xFF3A3A3A)], Color(0xFFD9D9D9)), // فحمي وفضي
];

Future<void> _share(BuildContext context, GlobalKey key) async {
  try {
    final box = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image img = await box.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = data!.buffer.asUint8List();
    await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'image/png', name: 'iqtibas.png')], fileNameOverrides: ['iqtibas.png']);
  } catch (_) {
    if (context.mounted) toast(context, 'تعذّرت مشاركة الصورة');
  }
}

class _Card extends StatelessWidget {
  final String text, scholar, source;
  final int tpl;
  const _Card({required this.text, required this.scholar, required this.source, this.tpl = 0});
  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFF6EED6);
    final t = cardTemplates[tpl.clamp(0, cardTemplates.length - 1)];
    final goldC = t.$2;
    final n = text.length;
    final size = n < 120 ? 23.0 : n < 260 ? 20.0 : n < 500 ? 17.5 : 15.5;
    return Container(
      width: 360,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: t.$1, begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(border: Border.all(color: goldC, width: 1.2), borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.format_quote_rounded, color: goldC, size: 34),
          const SizedBox(height: 4),
          Text(scholar, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w700, color: goldC)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: bookFont, fontSize: size, height: 1.9, color: cream)),
          const SizedBox(height: 14),
          Container(height: 1, width: 90, color: goldC.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          if (source.isNotEmpty)
            Text(source, textAlign: TextAlign.center, style: const TextStyle(fontFamily: uiFont, fontSize: 13.5, color: cream, height: 1.6)),
          const SizedBox(height: 10),
          const Text('مكتبة العلماء السلفية', style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: Color(0xB3F6EED6))),
        ]),
      ),
    );
  }
}
