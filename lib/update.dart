import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const appBuild = int.fromEnvironment('BUILD', defaultValue: 0);
const siteUrl = 'https://www774475437-svg.github.io/salafi-library/';
const apkUrl = 'https://github.com/www774475437-svg/salafi-library/releases/latest/download/salafi-library.apk';
const contactUrl = 'https://t.me/alhsaar4';
const developerName = 'أبو عبد الرحمن أحمد الأثري';

/// The app's page in the store; empty until it is published there.
const storeUrl = '';

Future<void> openLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Tells the reader when a newer APK is on GitHub (Android only).
class Updates {
  static final newer = ValueNotifier<int>(0);

  static Future<void> check() async {
    if (kIsWeb || appBuild == 0) return;
    try {
      final r = await http
          .get(Uri.parse('https://api.github.com/repos/www774475437-svg/salafi-library/releases/latest'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      final tag = (jsonDecode(r.body) as Map<String, dynamic>)['tag_name'] as String? ?? '';
      final n = int.tryParse(tag.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > appBuild) newer.value = n;
    } catch (_) {}
  }
}
