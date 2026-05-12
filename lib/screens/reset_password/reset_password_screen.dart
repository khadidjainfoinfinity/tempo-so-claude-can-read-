import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../login/login_screen.dart';
import '../../l10n/app_strings.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String loginInput;

  const ResetPasswordScreen({super.key, required this.loginInput});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool    _isLoading = false;
  String? _message;
  bool    _isError   = true;

  // ── Couleurs identiques forgot_password / login / signup ──
  static const Color _awning     = Color(0xFFE6F494);
  static const Color _fieldBg    = Color(0xFFE8DFFF);
  static const Color _btnColor   = Color(0xFFC6B3FF);
  static const Color _purpleText = Color(0xFF9B7FE8);
  static const Color _dark       = Color(0xFF1A1A1A);

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _message = null; });

    try {
      final res = await AuthService().resetPassword(
        loginInput:  widget.loginInput,
        newPassword: _passwordController.text.trim(),
      );

      if (res['statusCode'] == 200) {
        setState(() {
          _message = res['body']['message'] ?? S.passwordResetOk;
          _isError = false;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else {
        setState(() {
          _message = res['body']['message'] ?? S.failedResetPwd;
          _isError = true;
        });
      }
    } catch (e) {
      setState(() { _message = S.serverError; _isError = true; });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final mq        = MediaQuery.of(context);
    final w         = mq.size.width;
    final h         = mq.size.height;
    final bottomPad = mq.padding.bottom;

    // ── Tailles responsive ───────────────────────────────────
    final bool   isSmall   = w < 600;
    final double awningH   = (h * 0.11).clamp(70.0, 120.0);
    final double hPad      = w * 0.07;
    final double iconSize  = (w * (isSmall ? 0.130 : 0.165)).clamp(isSmall ? 42.0 : 55.0, 90.0);
    final double titleFont = (w * (isSmall ? 0.055 : 0.065)).clamp(isSmall ? 18.0 : 20.0, 32.0);
    final double labelFont = (w * (isSmall ? 0.035 : 0.042)).clamp(isSmall ? 12.0 : 13.0, 20.0);
    final double hintFont  = (w * (isSmall ? 0.030 : 0.037)).clamp(isSmall ? 11.0 : 12.0, 17.0);
    final double fieldVPad = (h * (isSmall ? 0.013 : 0.019)).clamp(isSmall ?  8.0 : 13.0, 22.0);
    final double radius    = (w * 0.04).clamp(10.0, 20.0);
    final double gap       = (h * (isSmall ? 0.012 : 0.016)).clamp(isSmall ?  6.0 : 10.0, 20.0);
    final double btnH      = (h * (isSmall ? 0.050 : 0.072)).clamp(isSmall ? 40.0 : 50.0, 72.0);
    final double btnFont   = (w * (isSmall ? 0.036 : 0.044)).clamp(isSmall ? 12.0 : 14.0, 20.0);
    final double smallFont = (w * 0.036).clamp(12.0, 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              // ── AUVENT ──────────────────────────────────────────
              SizedBox(
                width:  double.infinity,
                height: awningH,
                child: Row(
                  children: List.generate(
                    (w / 50).ceil(),
                    (_) => Expanded(
                      child: Container(
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: _awning,
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

              // ── CONTENU SCROLLABLE ───────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: h * 0.025),

                      // ── ICÔNE PANIER ────────────────────────
                      Center(
                        child: SvgPicture.asset(
                          "images/cart-5-svgrepo-com.svg",
                          width:  iconSize,
                          height: iconSize,
                          colorFilter: const ColorFilter.mode(
                            _purpleText, BlendMode.srcIn,
                          ),
                        ),
                      ),

                      SizedBox(height: h * 0.018),

                      // ── TITRE ───────────────────────────────
                      Center(
                        child: Text(
                          S.resetPasswordTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:   titleFont,
                            fontWeight: FontWeight.w800,
                            color:      _dark,
                            height:     1.25,
                          ),
                        ),
                      ),

                      SizedBox(height: h * 0.030),

                      // ── NEW PASSWORD ─────────────────────────
                      Text(
                        S.newPassword,
                        style: TextStyle(
                          fontSize:   labelFont,
                          fontWeight: FontWeight.w700,
                          color:      _dark,
                        ),
                      ),
                      SizedBox(height: gap * 0.35),
                      _buildField(
                        controller: _passwordController,
                        hint:       "••••••••",
                        hintFont:   hintFont,
                        labelFont:  labelFont,
                        fieldVPad:  fieldVPad,
                        radius:     radius,
                        validator: (v) {
                          if (v == null || v.isEmpty) return S.required;
                          if (v.length < 6) return S.min6Chars;
                          return null;
                        },
                      ),

                      SizedBox(height: gap),

                      // ── CONFIRM PASSWORD ─────────────────────
                      Text(
                        S.confirmPwd,
                        style: TextStyle(
                          fontSize:   labelFont,
                          fontWeight: FontWeight.w700,
                          color:      _dark,
                        ),
                      ),
                      SizedBox(height: gap * 0.35),
                      _buildField(
                        controller: _confirmController,
                        hint:       "••••••••",
                        hintFont:   hintFont,
                        labelFont:  labelFont,
                        fieldVPad:  fieldVPad,
                        radius:     radius,
                        validator: (v) {
                          if (v == null || v.isEmpty) return S.required;
                          if (v != _passwordController.text) return S.passwordMismatch;
                          return null;
                        },
                      ),

                      // ── MESSAGE ERREUR / SUCCÈS ───────────────
                      if (_message != null) ...[
                        SizedBox(height: h * 0.012),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:   smallFont,
                            fontWeight: FontWeight.w600,
                            color:      _isError ? Colors.red : Colors.green,
                          ),
                        ),
                      ],

                      SizedBox(height: h * 0.02),
                    ],
                  ),
                ),
              ),

              // ── BOUTON CONFIRM (épinglé en bas) ──────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, bottomPad + h * 0.018),
                child: SizedBox(
                  width:  double.infinity,
                  height: btnH,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _btnColor,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: _btnColor.withValues(alpha: 0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(btnH / 2),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width:  24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color:       Colors.black,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            S.confirm,
                            style: TextStyle(
                              fontSize:      btnFont,
                              fontWeight:    FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required double hintFont,
    required double labelFont,
    required double fieldVPad,
    required double radius,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller:   controller,
      obscureText:  true,
      validator:    validator,
      style: TextStyle(fontSize: hintFont + 1),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(
          fontSize:      hintFont,
          color:         Colors.black38,
          letterSpacing: 2,
        ),
        prefixIcon: Icon(
          Icons.lock_outline,
          size:  labelFont + 4,
          color: Colors.black54,
        ),
        filled:    true,
        fillColor: _fieldBg,
        contentPadding: EdgeInsets.symmetric(
          vertical:   fieldVPad,
          horizontal: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide:   BorderSide.none,
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
    );
  }
}
