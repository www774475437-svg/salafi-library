import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';

/// The highlight colours: rename each one, or add a new one (six at most).
void showColorsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: ListenableBuilder(
        listenable: Store.i,
        builder: (c, _) {
          final st = Store.i;
          final unused = hlPalette.where((v) => !st.colors.any((x) => x.value == v)).toList();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ألوان التظليل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(c))),
                const SizedBox(height: 4),
                Text('سمِّ كل لون بما تجمع فيه، مثل «طرائف» أو «فوائد»، فيظهر الاسم تحت اللون وفي «مكتبتي».',
                    style: TextStyle(fontSize: 13.5, height: 1.6, color: C.muted(c))),
                const SizedBox(height: 10),
                for (var i = 0; i < st.colors.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: hlSolid(i), radius: 15),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('c$i'),
                          initialValue: st.colors[i].name,
                          maxLength: 14,
                          decoration: const InputDecoration(isDense: true, counterText: '', hintText: 'اسم اللون'),
                          onChanged: (v) => st.renameColor(i, v),
                        ),
                      ),
                    ]),
                  ),
                if (st.colors.length < 6 && unused.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('أضف لونًا', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(c))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    for (final v in unused)
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => st.addColor(v, ''),
                        child: CircleAvatar(
                          backgroundColor: Color(0xFF000000 | v),
                          radius: 18,
                          child: const Icon(Icons.add_rounded, color: Colors.black54, size: 20),
                        ),
                      ),
                  ]),
                ] else
                  Text('وصلت إلى ستة ألوان، وهو الحد الأعلى.', style: TextStyle(fontSize: 13, color: C.muted(c))),
              ]),
            ),
          );
        },
      ),
    ),
  );
}
