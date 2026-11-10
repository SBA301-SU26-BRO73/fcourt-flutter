import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A device preference, independent of the signed-in account.
class ThemeController extends ChangeNotifier {
  ThemeController({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : _read = read ?? (() => const FlutterSecureStorage().read(key: _key)),
       _write =
           write ??
           ((value) =>
               const FlutterSecureStorage().write(key: _key, value: value));
  static const _key = 'fcourt_theme_mode';
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  // Light until the user picks another mode in Settings.
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  int _revision = 0;
  bool _disposed = false;
  Future<void> _pendingWrite = Future.value();

  Future<void> restore() async {
    final revision = _revision;
    try {
      final stored = await _read();
      if (_disposed || revision != _revision) return;
      _mode =
          ThemeMode.values.where((mode) => mode.name == stored).firstOrNull ??
          ThemeMode.light;
      notifyListeners();
    } catch (_) {
      // Storage failure must not prevent opening the application.
    }
  }

  Future<bool> select(ThemeMode mode) async {
    _revision++;
    _mode = mode;
    notifyListeners();
    var saved = true;
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _write(mode.name);
      } catch (_) {
        saved = false;
      }
    });
    await _pendingWrite;
    return saved;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);
  static ThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!;
}
