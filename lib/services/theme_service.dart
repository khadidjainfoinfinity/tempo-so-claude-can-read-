import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeService extends ValueNotifier<ThemeMode> {
  ThemeService._() : super(ThemeMode.light);
  static final instance = ThemeService._();
  final _storage = const FlutterSecureStorage();

  Future<void> load() async {
    final val = await _storage.read(key: 'app_theme');
    value = val == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDark(bool dark) async {
    value = dark ? ThemeMode.dark : ThemeMode.light;
    await _storage.write(key: 'app_theme', value: dark ? 'dark' : 'light');
  }

  bool get isDark => value == ThemeMode.dark;
}
