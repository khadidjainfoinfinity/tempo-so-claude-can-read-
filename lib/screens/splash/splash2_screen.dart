import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';

class Splash2Screen extends StatefulWidget {
  const Splash2Screen({super.key});

  @override
  State<Splash2Screen> createState() => _Splash2ScreenState();
}

class _Splash2ScreenState extends State<Splash2Screen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final storage = const FlutterSecureStorage();
    final token   = await storage.read(key: 'jwt_token');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ShoppingOnboardingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    double svgWidth;
    double svgHeight;

    if (width > 1200) {
      svgWidth = width * 0.08;
      svgHeight = height * 0.15;
    } else if (width > 800) {
      svgWidth = width * 0.15;
      svgHeight = height * 0.2;
    } else if (width > 500) {
      svgWidth = width * 0.2;
      svgHeight = height * 0.25;
    } else {
      svgWidth = width * 0.2;
      svgHeight = height * 0.2;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE7E2DB),
      body: SafeArea(
        child: Center(
          child: SvgPicture.asset(
            "images/frame3.svg",
            width: svgWidth,
            height: svgHeight,
          ),
        ),
      ),
    );
  }
}
