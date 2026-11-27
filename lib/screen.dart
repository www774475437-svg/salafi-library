import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// The phone's screen and side buttons while reading (Android app only).
class Screen {
  static const _ch = MethodChannel('salafi_library/screen');
  static void Function(int step)? _onVolume;
  static bool _bound = false;

  static void _bind() {
    if (_bound) return;
    _bound = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'volume') _onVolume?.call((call.arguments as num).toInt());
    });
  }

  /// Keeps the screen lit (or lets it sleep again).
  static Future<void> keepOn(bool on) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('keepOn', on);
    } catch (_) {}
  }

  /// Asks the phone to allow notifications (Android 13 and later ask the reader).
  static Future<void> askNotify() async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('askNotify');
    } catch (_) {}
  }

  /// One reminder at the time [at] (ms); zero removes it. The phone may show it a little late.
  static Future<void> remind(int at, String title, String text) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('remind', {'at': at, 'title': title, 'text': text});
    } catch (_) {}
  }

  /// Leaves the coming days' sayings for the home-screen widget: [items] is a JSON list of [text, source],
  /// the first of them for the day numbered [start].
  static Future<void> widget(String items, int start) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('widget', {'items': items, 'start': start});
    } catch (_) {}
  }

  /// The volume buttons turn the pages: down is the next page, up the one before.
  static Future<void> volumeKeys(void Function(int step)? onPress) async {
    if (kIsWeb) return;
    _onVolume = onPress;
    try {
      _bind();
      await _ch.invokeMethod('volumeKeys', onPress != null);
    } catch (_) {}
  }
}
