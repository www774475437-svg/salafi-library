import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show BrowserContextMenu;

import 'catalog.dart';
import 'fawaid.dart';
import 'screens/home.dart';
import 'screens/library.dart';
import 'screens/search.dart';
import 'screens/settings.dart';
import 'store.dart';
import 'turath.dart';
import 'ui.dart';
import 'update.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Catalog.load(),
    Store.i.load(),
    Turath.loadHosted().timeout(const Duration(seconds: 4), onTimeout: () {}),
  ]);
  await Fawaid.load();
  // on the website our own bar handles selected text, not the browser's menu
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  runApp(const SalafiLibraryApp());
  Updates.check();
}

final shellTab = ValueNotifier<int>(0);

class SalafiLibraryApp extends StatelessWidget {
  const SalafiLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) => MaterialApp(
        title: 'مكتبة العلماء السلفية',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: Store.i.mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
    (Icons.search_rounded, Icons.manage_search_rounded, 'البحث'),
    (Icons.bookmarks_outlined, Icons.bookmarks_rounded, 'مكتبتي'),
    (Icons.settings_outlined, Icons.settings_rounded, 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, tab, _) => PopScope(
        canPop: tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) shellTab.value = 0;
        },
        child: Scaffold(
          extendBody: true,
          body: IndexedStack(index: tab, children: const [HomeScreen(), SearchScreen(), LibraryScreen(), SettingsScreen()]),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: C.card(context),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: C.line(context)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: C.dark(context) ? 0.4 : 0.08), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => shellTab.value = i,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                          decoration: BoxDecoration(
                            color: tab == i ? C.accent(context).withValues(alpha: 0.14) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(tab == i ? _tabs[i].$2 : _tabs[i].$1, color: tab == i ? C.accent(context) : C.muted(context), size: 25),
                        ),
                        const SizedBox(height: 2),
                        Text(_tabs[i].$3,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: tab == i ? FontWeight.w700 : FontWeight.w500,
                                color: tab == i ? C.accent(context) : C.muted(context))),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
