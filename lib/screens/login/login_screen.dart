// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../signup/signup_screen.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../home/home_screen.dart';
import '../categorie/catigorie1.dart';
import 'login_controller.dart';
import '../../l10n/app_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final controller = LoginController();
  bool _obscurePassword  = true;
  bool _isGoogleLoading  = false;

  // Web OAuth 2.0 Client ID from Google Cloud Console
  static const String _googleClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final googleSignIn = GoogleSignIn(serverClientId: _googleClientId);
      final account = await googleSignIn.signIn();
      if (account == null) return; // user cancelled

      final auth    = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in failed: no token')),
        );
        return;
      }

      setState(() => controller.isLoading = true);
      final res = await controller.googleSignIn(idToken);
      setState(() => controller.isLoading = false);

      if (res['statusCode'] == 200) {
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
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        final msg = res['body']['message'] ?? 'Google sign-in failed';
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

  // ── Couleurs ────────────────────────────────────────────────
  static const Color _awning     = Color(0xFFE6F494);
  static const Color _fieldBg    = Color(0xFFE8DFFF);
  static const Color _purple     = Color(0xFFC6B3FF);
  static const Color _purpleText = Color(0xFF9B7FE8);
  static const Color _red        = Color(0xFFE53935);
  static const Color _dark       = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final mq         = MediaQuery.of(context);
    final w          = mq.size.width;
    final h          = mq.size.height;
    final bottomPad  = mq.padding.bottom;
    final bool   isSmall  = w < 600;
    final double hPad     = w * 0.07;
    final double awningH  = (h * 0.11).clamp(70.0, 120.0);
    final double btnH     = (h * (isSmall ? 0.060 : 0.072)).clamp(isSmall ? 44.0 : 50.0, 72.0);
    final double btnFont  = (w * (isSmall ? 0.038 : 0.044)).clamp(isSmall ? 13.0 : 14.0, 20.0);
    final double iconSize = (w * (isSmall ? 0.130 : 0.165)).clamp(isSmall ? 42.0 : 55.0, 90.0);
    final double fieldPad = isSmall ? 11.0 : 14.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── BARRE D'AUVENT (top) ──────────────────────────────
            SizedBox(
              width: double.infinity,
              height: awningH,
              child: _awningDecoration(w),
            ),

            // ── CONTENU SCROLLABLE ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: h * 0.025),

                    // ── ICÔNE PANIER ────────────────────────────
                    Center(
                      child: SvgPicture.asset(
                        "images/cart-5-svgrepo-com.svg",
                        width:  iconSize,
                        height: iconSize,
                        colorFilter: const ColorFilter.mode(
                          _purple, BlendMode.srcIn,
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.018),

                    // ── TITRE ───────────────────────────────────
                    Center(
                      child: Text(
                        S.signInTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:   (w * (isSmall ? 0.055 : 0.065)).clamp(isSmall ? 18.0 : 18.0, 30.0),
                          fontWeight: FontWeight.w800,
                          color:      _dark,
                          height:     1.25,
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.030),

                    // ── CHAMP EMAIL ─────────────────────────────
                    _fieldLabel(S.emailOrPhone),
                    SizedBox(height: h * 0.008),
                    _buildField(
                      hint:       S.emailHint,
                      icon:       Icons.mail_outline,
                      controller: controller.emailController,
                      obscure:    false,
                      w: w,
                      isSmall: isSmall,
                      fieldPad: fieldPad,
                    ),

                    SizedBox(height: h * (isSmall ? 0.012 : 0.018)),

                    // ── CHAMP MOT DE PASSE ──────────────────────
                    _fieldLabel(S.passwordLabel),
                    SizedBox(height: h * 0.008),
                    _buildField(
                      hint:       "••••••",
                      icon:       Icons.lock_outline,
                      controller: controller.passwordController,
                      obscure:    _obscurePassword,
                      isPassword: true,
                      w: w,
                      isSmall: isSmall,
                      fieldPad: fieldPad,
                    ),

                    SizedBox(height: h * 0.010),

                    // ── FORGOT PASSWORD ─────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: Text(
                          S.forgotPassword,
                          style: TextStyle(
                            fontSize:   (w * 0.030).clamp(10.0, 14.0),
                            color:      _red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.02),
                  ],
                ),
              ),
            ),

            // ── BOUTON SIGN IN (épinglé en bas) ───────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, bottomPad + h * 0.018),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width:  double.infinity,
                    height: btnH,
                    child: ElevatedButton(
                      onPressed: controller.isLoading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              setState(() => controller.isLoading = true);
                              final res = await controller.login();
                              setState(() => controller.isLoading = false);
                              if (res['statusCode'] == 200) {
                                if (!mounted) return;
                                if (res['needsOnboarding'] == true) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LifestyleSelectionPage(
                                        name: res['userName'] ?? '',
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const HomeScreen()),
                                  );
                                }
                              } else {
                                final msg =
                                    res['body']['message'] ?? "Login failed";
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            _purple.withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(btnH / 2),
                        ),
                      ),
                      child: controller.isLoading
                          ? const SizedBox(
                              width:  24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color:       Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              S.signIn,
                              style: TextStyle(
                                fontSize:     btnFont,
                                fontWeight:   FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: h * 0.014),

                  // ── OR DIVIDER ──────────────────────────────
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.black26, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          S.or,
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

                  // ── GOOGLE BUTTON ───────────────────────────
                  SizedBox(
                    width:  double.infinity,
                    height: btnH,
                    child: ElevatedButton(
                      onPressed: (_isGoogleLoading || controller.isLoading)
                          ? null
                          : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:         _purple,
                        foregroundColor:         Colors.black,
                        disabledBackgroundColor: _purple.withValues(alpha: 0.6),
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
                                // Google "G" logo
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
                                    color:      Colors.black,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: h * 0.015),

                  // ── DON'T HAVE AN ACCOUNT ───────────────────
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          S.noAccount,
                          style: TextStyle(
                            fontSize: (w * 0.033).clamp(11.0, 15.0),
                            color:    Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignUpScreen()),
                          ),
                          child: Text(
                            S.signUpLink,
                            style: TextStyle(
                              fontSize:   (w * 0.033).clamp(11.0, 15.0),
                              fontWeight: FontWeight.bold,
                              color:      _purpleText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ── Auvent en haut ───────────────────────────────────────────
  Widget _awningDecoration(double w) {
    final int count = (w / 50).ceil();
    return Row(
      children: List.generate(
        count,
        (_) => Expanded(
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color:        _awning,
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              border: Border.all(color: Colors.white, width: 6),
            ),
          ),
        ),
      ),
    );
  }

  // ── Label champ ──────────────────────────────────────────────
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize:   14,
        fontWeight: FontWeight.w700,
        color:      _dark,
      ),
    );
  }

  // ── Champ texte ──────────────────────────────────────────────
  Widget _buildField({
    required String               hint,
    required IconData             icon,
    required TextEditingController controller,
    required bool                 obscure,
    required double               w,
    required bool                 isSmall,
    required double               fieldPad,
    bool                          isPassword = false,
  }) {
    final double fontSize = (w * (isSmall ? 0.030 : 0.036)).clamp(11.0, 16.0);
    return TextFormField(
      controller:  controller,
      obscureText: obscure,
      validator: (v) {
        if (v == null || v.isEmpty) return S.required;
        if (isPassword && v.length < 6) return S.min6Chars;
        return null;
      },
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(
          color:    Colors.black38,
          fontSize: fontSize,
        ),
        prefixIcon: Icon(icon, color: Colors.black54, size: isSmall ? 18 : 20),
        suffixIcon: isPassword
            ? GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.black38,
                  size: isSmall ? 18 : 20,
                ),
              )
            : null,
        filled:    true,
        fillColor: _fieldBg,
        contentPadding: EdgeInsets.symmetric(vertical: fieldPad),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _purple, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _red, width: 1.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _red, width: 1.8),
        ),
      ),
    );
  }
}
