// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../login/login_screen.dart';
import 'signup_controller.dart';
import '../categorie/catigorie1.dart';
import '../../l10n/app_strings.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final controller = SignUpController();
  bool isLoading = false;
  // ignore: unused_field
  bool _isGoogleLoading = false;

  static const String _googleClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  // ignore: unused_field
  static const _dark = Color(0xFF1A1A1A);

  // ignore: unused_element
  Future<void> _signUpWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final googleSignIn = GoogleSignIn(serverClientId: _googleClientId);
      final account = await googleSignIn.signIn();
      if (account == null) return;

      final auth    = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in failed: no token')),
        );
        return;
      }

      setState(() => isLoading = true);
      final res = await controller.googleSignIn(idToken);
      setState(() => isLoading = false);

      if (res['statusCode'] == 200 || res['statusCode'] == 201) {
        if (!mounted) return;
        if (res['needsOnboarding'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LifestyleSelectionPage(name: res['userName'] ?? ''),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        final msg = res['body']['message'] ?? 'Google sign-up failed';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq         = MediaQuery.of(context);
    final w          = mq.size.width;
    final h          = mq.size.height;
    // Toutes les tailles proportionnelles à l'écran (sans maxWidth fixe)
    final bool   isSmall   = w < 600;
    final double awningH   = (h * 0.11).clamp(70.0, 120.0);
    final double hPad      = w * 0.07;   // 7% de chaque côté → même rendu partout
    final double iconSize  = (w * (isSmall ? 0.13  : 0.165)).clamp(isSmall ? 42.0 : 55.0, 90.0);
    final double titleFont = (w * (isSmall ? 0.055 : 0.065)).clamp(isSmall ? 18.0 : 20.0, 32.0);
    final double labelFont = (w * (isSmall ? 0.035 : 0.042)).clamp(isSmall ? 12.0 : 13.0, 20.0);
    final double hintFont  = (w * (isSmall ? 0.030 : 0.037)).clamp(isSmall ? 11.0 : 12.0, 17.0);
    final double fieldVPad = (h * (isSmall ? 0.013 : 0.019)).clamp(isSmall ?  8.0 : 13.0, 22.0);
    final double iconFs    = labelFont + 4;
    final double radius    = (w * 0.04).clamp(10.0, 20.0);
    final double btnH      = (h * (isSmall ? 0.060 : 0.072)).clamp(isSmall ? 44.0 : 50.0, 72.0);
    final double btnFont   = (w * (isSmall ? 0.038 : 0.044)).clamp(isSmall ? 13.0 : 14.0, 20.0);
    final double smallFont = (w * 0.036).clamp(12.0, 16.0);
    final double gap       = (h * (isSmall ? 0.012 : 0.016)).clamp(isSmall ?  6.0 : 10.0, 20.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        top: true,
        bottom: true,
        child: Column(
        children: [

          // ── Awning ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: awningH,
            child: Row(
              children: List.generate(
                (w / 50).ceil(),
                (_) => Expanded(
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F494),
                      borderRadius: const BorderRadius.only(
                        bottomLeft:  Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      border: Border.all(color: Colors.white, width: 6),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Contenu scrollable (pleine largeur – padding géré ici) ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: h * 0.025),

                    // Logo
                    Center(
                      child: SvgPicture.asset(
                        "images/cart-5-svgrepo-com.svg",
                        width: iconSize,
                        height: iconSize,
                      ),
                    ),

                    SizedBox(height: h * 0.018),

                    // Titre
                    Center(
                      child: Text(
                        S.createAccount,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Unbounded',
                          fontWeight: FontWeight.w800,
                          fontSize: titleFont,
                          color: Colors.black,
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.025),

                    // ── Champs ──
                    _field(
                      label: S.fullName,       hint: S.namehint,
                      icon: Icons.person_outline, ctrl: controller.nameController,
                      labelFont: labelFont,    hintFont: hintFont,
                      vPad: fieldVPad,         iconFs: iconFs,
                      radius: radius,          gap: gap,
                      validator: (v) {
                        if (v == null || v.isEmpty) return S.required;
                        if (RegExp(r'[0-9]').hasMatch(v)) return S.required;
                        return null;
                      },
                    ),

                    _field(
                      label: S.phoneSignup,    hint: "+213 ••••••••",
                      icon: Icons.phone_outlined, ctrl: controller.phoneController,
                      keyboardType: TextInputType.phone,
                      errorText: controller.phoneError,
                      labelFont: labelFont,    hintFont: hintFont,
                      vPad: fieldVPad,         iconFs: iconFs,
                      radius: radius,          gap: gap,
                      validator: (v) {
                        if (v == null || v.isEmpty) return S.required;
                        if (!RegExp(r'^0[5-7][0-9]{8}$').hasMatch(v)) return S.required;
                        return null;
                      },
                    ),

                    _field(
                      label: S.emailSignup,    hint: S.emailHint,
                      icon: Icons.email_outlined, ctrl: controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      errorText: controller.emailError,
                      labelFont: labelFont,    hintFont: hintFont,
                      vPad: fieldVPad,         iconFs: iconFs,
                      radius: radius,          gap: gap,
                      validator: (v) {
                        if (v == null || v.isEmpty) return S.required;
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return S.required;
                        return null;
                      },
                    ),

                    _field(
                      label: S.passwordLabel,  hint: "••••••",
                      icon: Icons.lock_outline, ctrl: controller.passwordController,
                      obscure: true,
                      errorText: controller.passwordError,
                      labelFont: labelFont,    hintFont: hintFont,
                      vPad: fieldVPad,         iconFs: iconFs,
                      radius: radius,          gap: gap,
                      validator: (v) {
                        if (v == null || v.isEmpty) return S.required;
                        if (v.length < 6) return S.min6Chars;
                        return null;
                      },
                    ),

                    _field(
                      label: S.confirmPwd,     hint: "••••••",
                      icon: Icons.lock_outline, ctrl: controller.confirmController,
                      obscure: true,
                      errorText: controller.confirmError,
                      labelFont: labelFont,    hintFont: hintFont,
                      vPad: fieldVPad,         iconFs: iconFs,
                      radius: radius,          gap: gap,
                      validator: (v) {
                        if (v == null || v.isEmpty) return S.required;
                        if (v != controller.passwordController.text) return S.passwordMismatch;
                        return null;
                      },
                    ),

                    SizedBox(height: h * 0.03),

                    // ── Bouton ──
                    SizedBox(
                      width: double.infinity,
                      height: btnH,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                setState(() => isLoading = true);
                                final res = await controller.signup();
                                setState(() => isLoading = false);
                                if (res['statusCode'] == 201) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res['body']['message'])),
                                  );
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LifestyleSelectionPage(
                                        name: controller.nameController.text.trim(),
                                      ),
                                    ),
                                  );
                                } else {
                                  final msg = res['body']['message'] ?? "Signup failed";
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text(msg)));
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC6B3FF),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(btnH / 2),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                S.signUp,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: btnFont,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(height: h * 0.014),
                    /*
                    // ── OR DIVIDER ──────────────────────────────────
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.black26, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize:   (w * 0.030).clamp(10.0, 13.0),
                              color:      Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Colors.black26, thickness: 1)),
                      ],
                    ),

                     SizedBox(height: h * 0.014),

                    // ── GOOGLE BUTTON ────────────────────────────────
                    SizedBox(
                      width:  double.infinity,
                      height: btnH,
                      child: ElevatedButton(
                        onPressed: (_isGoogleLoading || isLoading)
                            ? null
                            : _signUpWithGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:         const Color(0xFFC6B3FF),
                          foregroundColor:         Colors.black,
                          disabledBackgroundColor: const Color(0xFFC6B3FF).withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(btnH / 2),
                          ),
                        ),
                        child: _isGoogleLoading
                            ? const SizedBox(
                                width:  24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color:       Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width:  isSmall ? 20.0 : 24.0,
                                    height: isSmall ? 20.0 : 24.0,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF4CAF50),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          color:      Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize:   isSmall ? 12.0 : 14.0,
                                          height:     1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    S.continueGoogle,
                                    style: TextStyle(
                                      fontSize:   btnFont,
                                      fontWeight: FontWeight.w600,
                                      color:      _dark,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ), */

                    SizedBox(height: h * 0.02),

                    // ── Sign In ──
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            S.haveAccount,
                            style: TextStyle(fontSize: smallFont, color: Colors.black87),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            ),
                            child: Text(
                              S.signInLink,
                              style: TextStyle(
                                fontSize: smallFont,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF9B7FE8),
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF9B7FE8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: h * 0.04),
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required double labelFont,
    required double hintFont,
    required double vPad,
    required double iconFs,
    required double radius,
    required double gap,
    TextEditingController? ctrl,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? errorText,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: labelFont,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: gap * 0.35),
          TextFormField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(fontSize: hintFont + 1),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: hintFont, color: const Color(0xFF9E9E9E)),
              prefixIcon: Icon(icon, size: iconFs, color: Colors.black54),
              filled: true,
              fillColor: const Color(0xFFE8DFFF),
              errorText: errorText,
              contentPadding: EdgeInsets.symmetric(vertical: vPad, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: const BorderSide(color: Color(0xFFA78BFA), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
