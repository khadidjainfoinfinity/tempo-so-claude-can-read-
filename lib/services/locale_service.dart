import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleService extends ValueNotifier<Locale> {
  LocaleService._() : super(const Locale('en'));
  static final instance = LocaleService._();
  final _storage = const FlutterSecureStorage();

  static const supported = [
    Locale('en'),
    Locale('fr'),
    Locale('ar'),
  ];

  Future<void> load() async {
    final code = await _storage.read(key: 'app_locale') ?? 'en';
    value = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    value = locale;
    await _storage.write(key: 'app_locale', value: locale.languageCode);
  }

  String get languageCode => value.languageCode;
  bool   get isArabic     => value.languageCode == 'ar';
  bool   get isFrench     => value.languageCode == 'fr';
}
