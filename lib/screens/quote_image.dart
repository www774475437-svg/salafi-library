import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../ui.dart';

/// Shows the quote as a card and shares it as a picture.
void showQuoteImage(BuildContext context, {required String text, required String scholar, required String source}) {
  final key = GlobalKey();
  showDialog(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            child: RepaintBoundary(key: key, child: _Card(text: text.trim(), scholar: scholar, source: source)),
          ),
        ),
        const SizedBox(height: 12),
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
  );
}

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
  const _Card({required this.text, required this.scholar, required this.source});
  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFF6EED6);
    const goldC = Color(0xFFE1C478);
    final n = text.length;
    final size = n < 120 ? 23.0 : n < 260 ? 20.0 : n < 500 ? 17.5 : 15.5;
    return Container(
      width: 360,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF17493B), Color(0xFF2E7A62)], begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(border: Border.all(color: goldC, width: 1.2), borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.format_quote_rounded, color: goldC, size: 34),
          const SizedBox(height: 4),
          Text(scholar, textAlign: TextAlign.center, style: const TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w700, color: goldC)),
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
