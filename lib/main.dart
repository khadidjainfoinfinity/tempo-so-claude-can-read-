import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash/splash1_screen.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ThemeService.instance.load(),
    LocaleService.instance.load(),
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance,
      builder: (_, mode, _) => ValueListenableBuilder<Locale>(
        valueListenable: LocaleService.instance,
        builder: (_, locale, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          locale:            locale,
          supportedLocales:  LocaleService.supported,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: mode,
          theme: ThemeData(
            useMaterial3:            false,
            brightness:              Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F6F8),
            colorScheme: const ColorScheme.light(
              primary:   Color(0xFF0D1B2A),
              secondary: Color(0xFFD6F36A),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3:            false,
            brightness:              Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(
              primary:   Color(0xFFD6F36A),
              secondary: Color(0xFF0D1B2A),
              surface:   Color(0xFF1E1E1E),
            ),
            cardColor: const Color(0xFF1E1E1E),
          ),
          home: const Splash1Screen(),
        ),
      ),
    );
  }
}
