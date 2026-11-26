import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../fawaid.dart';
import '../ui.dart';
import 'quote_image.dart';
import 'reader.dart';

/// The publisher shown on the sample sayings (the developer, as the app names him).
const samplePublisher = 'أبو عبد الرحمن أحمد الأثري';

/// Full-screen sayings, one per screen, swiped up and down like the poetry app.
/// The buttons sit on the side: like, image, copy, source and share.
class ReadersFeed extends StatelessWidget {
  const ReadersFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final items = Fawaid.all.take(4).toList();
    if (items.isEmpty) {
      return const EmptyNote(Icons.forum_outlined, 'لا توجد فوائد بعد.');
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: items.length,
      itemBuilder: (_, i) => _FeedPage(faida: items[i]),
    );
  }
}

class _FeedPage extends StatefulWidget {
  final Faida faida;
  const _FeedPage({required this.faida});
  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  bool liked = false;
  int likes = 0;

  void _like() => setState(() {
        liked = !liked;
        likes += liked ? 1 : -1;
      });

  @override
  Widget build(BuildContext context) {
    final f = widget.faida;
    final size = f.text.length < 120 ? 27.0 : f.text.length < 260 ? 23.0 : 19.0;
    const cream = Color(0xFFF3E9CF);
    const gold = Color(0xFFE1C478);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1C1612), Color(0xFF2A211A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: SafeArea(
        child: Stack(children: [
          // the saying itself, centred
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 84, 110),
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    f.raw ? f.text : '«${f.text}»',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: bookFont, fontSize: size, height: 1.9, color: cream),
                  ),
                ),
              ),
            ),
          ),
          // side buttons
          Positioned(
            left: 10,
            bottom: 120,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SideBtn(icon: liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined, label: '$likes', color: liked ? gold : cream, onTap: _like),
              const SizedBox(height: 18),
              _SideBtn(icon: Icons.image_outlined, label: 'صورة', color: cream, onTap: () => showQuoteImage(context, text: f.text, scholar: f.scholar.name, source: f.source)),
              const SizedBox(height: 18),
              _SideBtn(
                icon: Icons.copy_rounded,
                label: 'نسخ',
                color: cream,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: f.shareText));
                  toast(context, 'نُسخت الفائدة مع مصدرها');
                },
              ),
              const SizedBox(height: 18),
              _SideBtn(
                icon: Icons.share_rounded,
                label: 'مشاركة',
                color: cream,
                onTap: () => Share.share(f.shareText),
              ),
              const SizedBox(height: 18),
              _SideBtn(
                icon: Icons.menu_book_rounded,
                label: 'المصدر',
                color: cream,
                onTap: () {
                  final b = f.book > 0 ? Catalog.byId[f.book] : null;
                  if (b != null) {
                    openReader(context, b, f.pg);
                  } else {
                    toast(context, 'المصدر: ${f.source}');
                  }
                },
              ),
            ]),
          ),
          // publisher and source, bottom right
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(f.scholar.name, style: const TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w700, color: gold)),
              ]),
              const SizedBox(height: 4),
              Text('اقتبسه $samplePublisher · ${f.source}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: uiFont, fontSize: 12.5, color: Color(0xB3F3E9CF))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SideBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SideBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}
