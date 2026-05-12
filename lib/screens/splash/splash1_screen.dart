import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'splash2_screen.dart';

class Splash1Screen extends StatefulWidget {
  const Splash1Screen({super.key});

  @override
  State<Splash1Screen> createState() => _Splash1ScreenState();
}

class _Splash1ScreenState extends State<Splash1Screen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // ── Phases de l'animation (valeurs 0.0 → 1.0) ──────────────
  // 0.00 – 0.18 : apparition (fade + scale in)
  // 0.18 – 0.60 : vibration moteur (shake gauche/droite)
  // 0.60 – 1.00 : accélération + slide vers la droite (vroom)

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Splash2Screen()),
        );
      }
    });

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Courte pause avant de démarrer
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _ctrl.forward();

    // ── Phase vibration : démarre à t=0.18 ──────────────────
    // 0.18 * 2600 = 468ms après le départ
    await Future.delayed(const Duration(milliseconds: 468));
    if (!mounted) return;

    // Vibrations rapides = son moteur qui démarre
    for (int i = 0; i < 10; i++) {
      if (!mounted) break;
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 85));
    }

    // Coup final = accélération
    if (mounted) HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    if (mounted) HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Calcul du shake (vibration moteur) ─────────────────────
  double _shakeX(double t) {
    if (t < 0.18 || t > 0.62) return 0;
    final p = (t - 0.18) / 0.44;
    // Oscillation décroissante (moteur qui prend le régime)
    return sin(p * pi * 12) * 9 * (1 - p * 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final iconSize = (size.width * 0.22).clamp(70.0, 150.0);

    return Scaffold(
      backgroundColor: const Color(0xFFA997E7),
      body: SafeArea(
        child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final t = _ctrl.value;

          // ── Scale ─────────────────────────────────────────
          double scale;
          if (t < 0.18) {
            // Apparition
            scale = 0.3 + Curves.easeOut.transform(t / 0.18) * 0.7;
          } else if (t < 0.60) {
            // Légère pulsation pendant la vibration
            scale = 1.0 + sin((t - 0.18) / 0.42 * pi * 6) * 0.03;
          } else {
            // Accélération
            scale = 1.0 + Curves.easeIn.transform((t - 0.60) / 0.40) * 1.2;
          }

          // ── Slide horizontal ──────────────────────────────
          double slideX = 0;
          if (t > 0.60) {
            slideX = Curves.easeIn.transform((t - 0.60) / 0.40) *
                size.width * 1.6;
          }

          // ── Opacité ───────────────────────────────────────
          double opacity;
          if (t < 0.12) {
            opacity = t / 0.12;
          } else if (t < 0.72) {
            opacity = 1.0;
          } else {
            opacity = 1.0 - (t - 0.72) / 0.28;
          }

          final shakeX = _shakeX(t);

          // ── Traits de vitesse (visibles pendant le vroom) ─
          final showLines = t > 0.60;
          final lineOpacity = showLines
              ? Curves.easeIn.transform((t - 0.60) / 0.40)
              : 0.0;

          return SizedBox.expand(
            child: Stack(
            alignment: Alignment.center,
            children: [

              // ── Traits de vitesse ──────────────────────────
              if (showLines)
                Opacity(
                  opacity: lineOpacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(slideX * 0.4, 0),
                    child: _SpeedLines(
                      iconSize: iconSize,
                      progress: (t - 0.60) / 0.40,
                    ),
                  ),
                ),

              // ── Caddie ────────────────────────────────────
              Transform.translate(
                offset: Offset(slideX + shakeX, 0),
                child: Transform.scale(
                  scale: scale.clamp(0.0, 3.0),
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: SvgPicture.asset(
                      "images/cart-5-svgrepo-com.svg",
                      width:  iconSize,
                      height: iconSize,
                      colorFilter: const ColorFilter.mode(
                        Colors.white, BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),  // Stack
          ); // SizedBox.expand
        },
        ),
      ),
    );
  }
}

// ── Widget : traits de vitesse ────────────────────────────────
class _SpeedLines extends StatelessWidget {
  final double iconSize;
  final double progress;

  const _SpeedLines({required this.iconSize, required this.progress});

  @override
  Widget build(BuildContext context) {
    final lines = [
      _LineData(yOffset: -iconSize * 0.28, length: 0.55, thickness: 2.5),
      _LineData(yOffset: -iconSize * 0.10, length: 0.80, thickness: 3.5),
      _LineData(yOffset:  iconSize * 0.08, length: 0.90, thickness: 4.0),
      _LineData(yOffset:  iconSize * 0.24, length: 0.65, thickness: 2.8),
      _LineData(yOffset: -iconSize * 0.44, length: 0.35, thickness: 1.8),
      _LineData(yOffset:  iconSize * 0.40, length: 0.40, thickness: 2.0),
    ];

    return SizedBox(
      width:  iconSize * 2.2,
      height: iconSize * 1.2,
      child: Stack(
        alignment: Alignment.centerRight,
        children: lines.map((l) {
          final w = iconSize * l.length * (0.4 + progress * 0.6);
          return Positioned(
            right:  iconSize * 0.42,
            top:    (iconSize * 1.2) / 2 + l.yOffset - l.thickness / 2,
            child: Container(
              width:  w,
              height: l.thickness,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(l.thickness),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LineData {
  final double yOffset;
  final double length;
  final double thickness;
  const _LineData({
    required this.yOffset,
    required this.length,
    required this.thickness,
  });
}
