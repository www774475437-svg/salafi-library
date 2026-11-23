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
