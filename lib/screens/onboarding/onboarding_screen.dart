import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import '../signup/signup_screen.dart';
import '../../l10n/app_strings.dart';

class ShoppingOnboardingPage extends StatefulWidget {
  const ShoppingOnboardingPage({super.key});

  @override
  State<ShoppingOnboardingPage> createState() => _ShoppingOnboardingPageState();
}

class _ShoppingOnboardingPageState extends State<ShoppingOnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double w          = constraints.maxWidth;
            final double h          = constraints.maxHeight;
            final bool   isLandscape = w > h;
            final double shorter    = math.min(w, h);

            final double topHeight = isLandscape ? h * 0.35 : h * 0.42;
            final double contentH  = h - topHeight;

            final double titleFont    = math.min(w * 0.045, contentH * 0.085);
            final double shoppingFont = math.min(w * 0.110, contentH * 0.140);
            final double subFont      = math.min(w * 0.033, contentH * 0.043).clamp(9.0, 22.0);
            final double subGap       = contentH * 0.030;
            final double cartSize     = math.min(w * 0.25,  contentH * 0.25);
            final double btnHeight    = math.min(shorter * 0.11, contentH * 0.13).clamp(38.0, 54.0);
            final double btnFont      = btnHeight * 0.36;
            final double boxSize      = (shorter * 0.090).clamp(30.0, 52.0);
            final double iconSz       = (shorter * 0.045).clamp(14.0, 26.0);
            final double hPad         = w * 0.09;

            return Column(
              children: [
                // ── Zone verte + icônes animées ───────────────────
                SizedBox(
                  width: w,
                  height: topHeight,
                  child: Stack(
                    children: [
                      // Barres vertes
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          (w / 46).ceil(),
                          (_) => Expanded(
                            child: Container(
                              height: topHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDFF076),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(26),
                                  bottomRight: Radius.circular(26),
                                ),
                                border: Border.all(color: Colors.white, width: 5),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Icônes avec animation flottante (phase différente pour chacune)
                      _animIcon(Icons.shopping_bag_outlined, left: w * 0.03, top: topHeight * 0.08, angle: -18, size: boxSize, iconSz: iconSz, phase: 0.0),
                      _animIcon(Icons.headphones,            left: w * 0.27, top: topHeight * 0.04, angle:  12, size: boxSize, iconSz: iconSz, phase: 1.0),
                      _animIcon(Icons.card_giftcard,         left: w * 0.58, top: topHeight * 0.06, angle:  -8, size: boxSize, iconSz: iconSz, phase: 2.0),
                      _animIcon(Icons.diamond_outlined,      left: w * 0.80, top: topHeight * 0.03, angle:  15, size: boxSize, iconSz: iconSz, phase: 0.5),
                      _animIcon(Icons.location_on_outlined,  left: w * 0.06, top: topHeight * 0.45, angle: -10, size: boxSize, iconSz: iconSz, phase: 1.5),
                      _animIcon(Icons.shopping_cart_outlined,left: w * 0.60, top: topHeight * 0.43, angle:  18, size: boxSize, iconSz: iconSz, phase: 2.5),
                    ],
                  ),
                ),

                // ── Contenu bas ────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [

                        // Groupe 1 — Textes
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              S.onboardTagline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "Unbounded",
                                fontWeight: FontWeight.w600,
                                fontSize: titleFont,
                                color: Colors.black87,
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -6),
                              child: Text(
                                "SHOPPING",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: "Unbounded",
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3,
                                  fontSize: shoppingFont,
                                  color: const Color(0xFFAC93F8),
                                ),
                              ),
                            ),
                            SizedBox(height: subGap),
                            Text(
                              S.onboardSub,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: subFont,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),

                        // Groupe 2 — Caddie
                        SvgPicture.asset(
                          "images/frame3.svg",
                          width: cartSize,
                          height: cartSize,
                        ),

                        // Groupe 3 — Bouton
                        SizedBox(
                          width: double.infinity,
                          height: btnHeight,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SignUpScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC6B3FF),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              textStyle: TextStyle(
                                fontFamily: "Unbounded",
                                fontWeight: FontWeight.w700,
                                fontSize: btnFont,
                                letterSpacing: 1,
                              ),
                            ),
                            child: Text(S.startNow),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Icône avec animation flottante + rotation douce
  Widget _animIcon(IconData icon, {
    required double left,
    required double top,
    required double angle,
    required double size,
    required double iconSz,
    required double phase,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _controller.value * 2 * math.pi + phase;
        final double dy     = math.sin(t) * 5.0;       // flottement ±5px
        final double dAngle = math.sin(t * 0.7) * 0.08; // légère rotation ±5°

        return Positioned(
          left: left,
          top: top + dy,
          child: Transform.rotate(
            angle: angle * math.pi / 180 + dAngle,
            child: child,
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: Colors.black87, width: 1.2),
        ),
        child: Icon(icon, size: iconSz, color: Colors.black87),
      ),
    );
  }
}
