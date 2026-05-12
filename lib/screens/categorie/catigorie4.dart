import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../../l10n/app_strings.dart';

class AllSetPage extends StatefulWidget {
  final String name;
  const AllSetPage({super.key, required this.name});

  @override
  State<AllSetPage> createState() => _AllSetPageState();
}

class _AllSetPageState extends State<AllSetPage> with TickerProviderStateMixin {
  // Entrée de page
  late final AnimationController _enterController;
  late final Animation<double> _enterFade;
  late final Animation<double> _enterScale;

  // Slide du caddie (sort droite → entre gauche)
  late final AnimationController _floatController;

  // Flottement après l'entrée
  late final AnimationController _bobController;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _enterFade = CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    _enterScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutBack),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _enterController.forward().then((_) =>
        _floatController.forward().then((_) =>
            _bobController.repeat(reverse: true)));
  }

  @override
  void dispose() {
    _enterController.dispose();
    _floatController.dispose();
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    final double horizontalPadding = width > 900
        ? width * 0.06
        : width > 600
            ? width * 0.05
            : 24.0;

    final double iconBoxSize   = width > 900 ? 80 : width > 600 ? 70 : 60;
    final double iconSize      = width > 900 ? 46 : width > 600 ? 40 : 34;
    final double titleFontSize = (width * 0.065).clamp(22.0, 36.0);
    final double subFontSize   = (width * 0.042).clamp(13.0, 18.0);
    final double btnFontSize   = (width * 0.044).clamp(14.0, 20.0);
    final double btnHeight     = width > 600 ? 60 : 52;

    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE6),
      body: SafeArea(
        child: FadeTransition(
          opacity: _enterFade,
          child: ScaleTransition(
            scale: _enterScale,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  SizedBox(height: width > 600 ? 24 : 20),

                  // User icon
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(iconBoxSize * 0.27),
                      border: Border.all(color: Colors.black12, width: 1.5),
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: iconSize,
                      color: Colors.black87,
                    ),
                  ),

                  SizedBox(height: width > 600 ? 20 : 16),

                  // Title
                  Text(
                    S.allSetTitle(widget.name),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  SizedBox(height: width > 600 ? 12 : 8),

                  // Subtitle
                  Text(
                    S.allSetSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: subFontSize,
                      color: Colors.black54,
                    ),
                  ),

                  // Cart SVG — sort droite → entre gauche → reste + flotte
                  Expanded(
                    child: ClipRect(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_floatController, _bobController]),
                          builder: (context, child) {
                            // Slide (une fois)
                            double dx = 0;
                            if (_floatController.value <= 0.5) {
                              final t = _floatController.value / 0.5;
                              dx = Curves.easeIn.transform(t) * width;
                            } else {
                              final t = (_floatController.value - 0.5) / 0.5;
                              dx = -width + Curves.easeOut.transform(t) * width;
                            }
                            // Flottement vertical après arrêt
                            final double dy = _bobController.isAnimating
                                ? (_bobController.value * 2 - 1) * 8.0
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(dx, dy),
                              child: child,
                            );
                          },
                          child: SvgPicture.asset(
                            "images/caddie.svg",
                            width: width * 0.75,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // GO TO HOME button
                  Padding(
                    padding: EdgeInsets.only(bottom: width > 600 ? 32 : 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: btnHeight,
                      child: ElevatedButton(
                        onPressed: () async {
                          const storage = FlutterSecureStorage();

                          // Lire les préférences sauvegardées localement
                          List<String> parse(String? raw) {
                            if (raw == null || raw.isEmpty) return [];
                            try {
                              return List<String>.from(jsonDecode(raw));
                            } catch (_) { return []; }
                          }

                          final lifestyles  = parse(await storage.read(key: 'user_lifestyles'));
                          final allergies   = parse(await storage.read(key: 'user_allergies'));
                          final shopCats    = parse(await storage.read(key: 'user_shopping_categories'));
                          final token       = await storage.read(key: 'jwt_token') ?? '';

                          // Envoyer les préférences au backend si connecté
                          if (token.isNotEmpty) {
                            await AuthService().updatePreferences(
                              token:              token,
                              lifestyles:         lifestyles,
                              allergies:          allergies,
                              shoppingCategories: shopCats,
                            );
                          }

                          // Marquer l'onboarding comme complété localement
                          await storage.write(key: 'categories_completed', value: 'true');

                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                            (_) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC6B3FF),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          S.goToHome,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: btnFontSize,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
