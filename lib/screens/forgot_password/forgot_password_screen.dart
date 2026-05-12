// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../otp/otp_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_strings.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _inputController = TextEditingController();

  bool    _isLoading = false;
  String? _message;
  bool    _isError   = true;

  // ── Couleurs (identiques login/signup) ──────────────────────
  static const Color _bg         = Color(0xFFF5F0E8);
  static const Color _awning     = Color(0xFFE6F494);
  static const Color _fieldBg    = Color(0xFFE8DFFF);
  static const Color _btnColor   = Color(0xFFC6B3FF);
  static const Color _purpleText = Color(0xFF9B7FE8);
  static const Color _dark       = Color(0xFF1A1A1A);

  bool _isEmail(String v) => RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
  bool _isPhone(String v) => RegExp(r'^(05|06|07)[0-9]{8}$').hasMatch(v);

  Future<void> _sendOTP({String method = 'whatsapp'}) async {
    setState(() { _isLoading = true; _message = null; });

    final input = _inputController.text.trim();
    final res = await AuthService().forgotPassword(input, method: method);

    if (res['statusCode'] == 200) {
      setState(() {
        _message = res['body']['message'] ?? S.otpSent;
        _isError = false;
      });
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ForgotPasswordOTPPage(loginInput: input)),
      );
    } else {
      setState(() {
        _message = res['body']['message'] ?? S.failedSendOtp;
        _isError = true;
      });
    }

    setState(() => _isLoading = false);
  }

  // Shows choice sheet for phone input, sends directly for email
  void _onSendCodePressed() {
    if (!_formKey.currentState!.validate()) return;
    final input = _inputController.text.trim();

    if (_isPhone(input)) {
      _showMethodSheet();
    } else {
      _sendOTP(method: 'email');
    }
  }

  void _showMethodSheet() {
    final w = MediaQuery.of(context).size.width;
    final isSmall = w < 600;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: EdgeInsets.all(w * 0.04),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: w * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                S.sendOtpVia,
                style: TextStyle(
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 20),

              // WhatsApp option
              _methodTile(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                title: S.whatsapp,
                subtitle: S.viaWhatsApp,
                isSmall: isSmall,
                onTap: () {
                  Navigator.pop(context);
                  _sendOTP(method: 'whatsapp');
                },
              ),
              const SizedBox(height: 12),

              // Email option
              _methodTile(
                icon: Icons.email_outlined,
                iconColor: _purpleText,
                title: S.emailLabel,
                subtitle: S.viaEmail,
                isSmall: isSmall,
                onTap: () {
                  Navigator.pop(context);
                  _sendOTP(method: 'email');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodTile({
    required IconData icon,
    required Color    iconColor,
    required String   title,
    required String   subtitle,
    required bool     isSmall,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: isSmall ? 22 : 26),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isSmall ? 11 : 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq         = MediaQuery.of(context);
    final w          = mq.size.width;
    final h          = mq.size.height;
    final bottomPad  = mq.padding.bottom;

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
    final double subFont   = (w * 0.034).clamp(11.0, 15.0);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Form(
        key: _formKey,
        child: Column(
          children: [

            // ── AUVENT ────────────────────────────────────────────
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

            // ── CONTENU SCROLLABLE ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: h * 0.025),

                    // ── ICÔNE PANIER ──────────────────────────
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

                    // ── TITRE ─────────────────────────────────
                    Center(
                      child: Text(
                        S.forgotPasswordTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:   titleFont,
                          fontWeight: FontWeight.w800,
                          color:      _dark,
                          height:     1.25,
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.014),

                    // ── SOUS-TITRE ────────────────────────────
                    Center(
                      child: Text(
                        S.forgotPasswordSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:   subFont,
                          color:      Colors.black54,
                          height:     1.5,
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.030),

                    // ── LABEL CHAMP ───────────────────────────
                    Text(
                      S.emailOrPhone,
                      style: TextStyle(
                        fontSize:   labelFont,
                        fontWeight: FontWeight.w700,
                        color:      _dark,
                      ),
                    ),
                    SizedBox(height: gap * 0.35),

                    // ── CHAMP SAISIE ──────────────────────────
                    TextFormField(
                      controller:  _inputController,
                      keyboardType: TextInputType.text,
                      validator: (v) {
                        if (v == null || v.isEmpty) return S.required;
                        if (!_isEmail(v) && !_isPhone(v)) {
                          return S.validEmailOrPhone;
                        }
                        return null;
                      },
                      style: TextStyle(fontSize: hintFont + 1),
                      decoration: InputDecoration(
                        hintText:  S.emailHint,
                        hintStyle: TextStyle(
                          fontSize: hintFont,
                          color:    Colors.black38,
                        ),
                        prefixIcon: Icon(
                          Icons.mail_outline,
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
                          borderSide: const BorderSide(
                            color: Color(0xFFA78BFA), width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(radius),
                          borderSide: const BorderSide(
                            color: Colors.red, width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(radius),
                          borderSide: const BorderSide(
                            color: Colors.red, width: 1.5,
                          ),
                        ),
                      ),
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

            // ── BOUTON SEND CODE (épinglé en bas) ─────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, bottomPad + h * 0.018),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width:  double.infinity,
                    height: btnH,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onSendCodePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _btnColor,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            _btnColor.withValues(alpha: 0.6),
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
                              S.sendCode,
                              style: TextStyle(
                                fontSize:      btnFont,
                                fontWeight:    FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: h * 0.015),

                  // ── REMEMBER PASSWORD ─────────────────────
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${S.rememberPassword} ",
                          style: TextStyle(
                            fontSize: smallFont,
                            color:    Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            S.signInLink,
                            style: TextStyle(
                              fontSize:   smallFont,
                              fontWeight: FontWeight.bold,
                              color:      _purpleText,
                              decoration: TextDecoration.underline,
                              decorationColor: _purpleText,
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
}
