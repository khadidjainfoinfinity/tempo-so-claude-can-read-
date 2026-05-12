import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../reset_password/reset_password_screen.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_strings.dart';

String maskLoginInput(String input) {
  if (RegExp(r'^(05|06|07)[0-9]{8}$').hasMatch(input)) {
    return '+213 ${input.substring(2, 4)}******${input.substring(input.length - 2)}';
  }
  if (input.contains("@")) {
    final parts = input.split("@");
    return '${parts[0].substring(0, 2)}***@${parts[1]}';
  }
  return input;
}

class ForgotPasswordOTPPage extends StatefulWidget {
  final String loginInput;
  const ForgotPasswordOTPPage({super.key, required this.loginInput});

  @override
  State<ForgotPasswordOTPPage> createState() => _ForgotPasswordOTPPageState();
}

class _ForgotPasswordOTPPageState extends State<ForgotPasswordOTPPage> {
  final int    codeLength = 6;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode>             _focusNodes  = [];
  final _formKey = GlobalKey<FormState>();

  bool    isLoading = false;
  String? errorText;

  // ── Couleurs (identiques login/signup/forgot) ────────────────
  static const Color _awning     = Color(0xFFE6F494);
  static const Color _fieldBg    = Color(0xFFE8DFFF);
  static const Color _btnColor   = Color(0xFFC6B3FF);
  static const Color _purpleText = Color(0xFF9B7FE8);
  static const Color _dark       = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < codeLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes)  f.dispose();
    super.dispose();
  }
  
String get _otp => _controllers.map((e) => e.text).join();

Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { isLoading = true; errorText = null; });

    final res = await AuthService().verifyOtp(
      loginInput: widget.loginInput,
      otp: _otp,
    );

    if (res['statusCode'] != 200) {
      HapticFeedback.heavyImpact();
      setState(() {
        errorText = res['body']['message'] ?? S.wrongOtp;
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = false);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ResetPasswordScreen(loginInput: widget.loginInput),
    ));
  }

  Future<void> _resendOTP() async {
    final res = await AuthService().forgotPassword(widget.loginInput);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['statusCode'] == 200
              ? S.otpResentSuccess
              : res['body']['message'] ?? S.failedResendOtp,
        ),
      ),
    );
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
    final double subFont   = (w * 0.034).clamp(11.0, 15.0);
    final double smallFont = (w * 0.036).clamp(12.0, 16.0);
    final double btnH      = (h * (isSmall ? 0.050 : 0.072)).clamp(isSmall ? 40.0 : 50.0, 72.0);
    final double btnFont   = (w * (isSmall ? 0.036 : 0.044)).clamp(isSmall ? 12.0 : 14.0, 20.0);

    // Cases OTP — gap fixe, hauteur proportionnelle à la largeur
    final double boxGap    = (w * 0.025).clamp(6.0, 14.0);
    final double boxH      = ((w - hPad * 2 - boxGap * 5) / 6).clamp(isSmall ? 36.0 : 40.0, 64.0);
    final double otpFont   = (boxH * 0.44).clamp(isSmall ? 14.0 : 16.0, 26.0);
    final double boxRadius = (boxH * 0.20).clamp(8.0, 14.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: true,
        child: Column(
        children: [

          // ── AUVENT ──────────────────────────────────────────────
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

          // ── CONTENU ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: h * 0.025),

                    // ── ICÔNE PANIER ───────────────────────────
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
                        S.otpTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:   titleFont,
                          fontWeight: FontWeight.w800,
                          color:      _dark,
                          height:     1.25,
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.022),

                    // ── DESCRIPTION ───────────────────────────
                    Text(
                      "${S.enterCodeSentTo} ${maskLoginInput(widget.loginInput)}",
                      style: TextStyle(
                        fontSize: subFont,
                        color:    Colors.black54,
                      ),
                    ),

                    SizedBox(height: h * 0.022),

                    // ── CASES OTP ─────────────────────────────
                    Row(
                      children: List.generate(codeLength * 2 - 1, (idx) {
                        if (idx.isOdd) return SizedBox(width: boxGap);
                        final i = idx ~/ 2;
                        return Expanded(
                          child: SizedBox(
                          height: boxH,
                          child: TextFormField(
                            controller:  _controllers[i],
                            focusNode:   _focusNodes[i],
                            keyboardType: TextInputType.number,
                            textAlign:   TextAlign.center,
                            maxLength:   1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(
                              fontSize:   otpFont,
                              fontWeight: FontWeight.bold,
                              color:      _dark,
                            ),
                            decoration: InputDecoration(
                              counterText: "",
                              filled:      true,
                              fillColor:   _fieldBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(boxRadius),
                                borderSide:   BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(boxRadius),
                                borderSide:   BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(boxRadius),
                                borderSide: const BorderSide(
                                  color: Color(0xFFA78BFA), width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(boxRadius),
                                borderSide: const BorderSide(
                                  color: Colors.red, width: 1.5,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? "" : null,
                            onChanged: (v) {
                              if (v.isNotEmpty && i < codeLength - 1) {
                                _focusNodes[i + 1].requestFocus();
                              } else if (v.isEmpty && i > 0) {
                                _focusNodes[i - 1].requestFocus();
                              }
                              if (i == codeLength - 1 &&
                                  v.isNotEmpty &&
                                  !isLoading) {
                                _verifyOTP();
                              }
                            },
                          ),
                        ),  // SizedBox
                        ); // Expanded
                      }),
                    ),

                    SizedBox(height: h * 0.018),

                    // ── ERREUR ────────────────────────────────
                    if (errorText != null)
                      Text(
                        errorText!,
                        style: TextStyle(
                          color:    Colors.red,
                          fontSize: smallFont * 0.9,
                        ),
                      ),

                    SizedBox(height: h * 0.014),

                    // ── RESEND ────────────────────────────────
                    Row(
                      children: [
                        Text(
                          "${S.didntGetCode} ",
                          style: TextStyle(
                            fontSize: smallFont,
                            color:    Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: _resendOTP,
                          child: Text(
                            S.resend,
                            style: TextStyle(
                              fontSize:   smallFont,
                              fontWeight: FontWeight.bold,
                              color:      _purpleText,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // ── BOUTON SUBMIT ─────────────────────────
                    SizedBox(
                      width:  double.infinity,
                      height: btnH,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _verifyOTP,
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
                        child: isLoading
                            ? const SizedBox(
                                width:  24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color:       Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                S.submitOtp,
                                style: TextStyle(
                                  fontSize:      btnFont,
                                  fontWeight:    FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(height: h * 0.018),

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
                                fontSize:        smallFont,
                                fontWeight:      FontWeight.bold,
                                color:           _purpleText,
                                decoration:      TextDecoration.underline,
                                decorationColor: _purpleText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: h * 0.030 + bottomPad),
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
}
