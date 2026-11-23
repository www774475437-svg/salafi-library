import 'package:flutter/material.dart';

import '../ui.dart';
import '../update.dart';

const _reasons = [
  'خطأ إملائي',
  'نقص في النص أو سقط',
  'موضع الفائدة غير صحيح',
  'المصدر أو رقم الصفحة خطأ',
  'النص منسوب لغير قائله',
  'تكرار',
  'فائدة لا تناسب القسم',
  'مشكلة في النسخة المصوّرة',
  'مشكلة في التطبيق',
  'اقتراح',
];

/// A report about a saying or a page. Until the supervisor's panel is ready
/// it reaches the developer as a ready-written Telegram message.
Future<void> showReport(BuildContext context, {required String about, String text = ''}) async {
  final picked = <String>{};
  final note = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(c).viewInsets.bottom + 18),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إبلاغ', style: TextStyle(fontFamily: bookFont, fontSize: 22, fontWeight: FontWeight.w700, color: C.ink(c))),
            const SizedBox(height: 4),
            Text(about, style: TextStyle(fontSize: 13.5, color: C.muted(c))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final r in _reasons)
                FilterChip(
                  label: Text(r),
                  selected: picked.contains(r),
                  onSelected: (v) => set(() => v ? picked.add(r) : picked.remove(r)),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'اكتب ما تريد أن توضّحه (اختياري)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text('أرسل الإبلاغ'),
                onPressed: () {
                  if (picked.isEmpty && note.text.trim().isEmpty) {
                    toast(c, 'اختر سببًا أو اكتب ملاحظتك');
                    return;
                  }
                  final short = text.length > 300 ? '${text.substring(0, 300)}…' : text;
                  final msg = [
                    'إبلاغ من «مكتبة العلماء السلفية»',
                    'الموضع: $about',
                    if (picked.isNotEmpty) 'السبب: ${picked.join('، ')}',
                    if (note.text.trim().isNotEmpty) 'التوضيح: ${note.text.trim()}',
                    if (short.isNotEmpty) 'النص: $short',
                  ].join('\n');
                  Navigator.pop(c);
                  openLink('$contactUrl?text=${Uri.encodeComponent(msg)}');
                },
              ),
            ),
            const SizedBox(height: 6),
            Text('يُفتح تيليجرام برسالة جاهزة إلى المطوّر، فاضغط «إرسال» هناك.', style: TextStyle(fontSize: 12.5, color: C.muted(c))),
          ]),
        ),
      ),
    ),
  );
}
