import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/chargily_service.dart';
import '../../l10n/app_strings.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PaymentCardScreen
// ─────────────────────────────────────────────────────────────────────────────

class PaymentCardScreen extends StatefulWidget {
  /// Optional discounted total from a promo code applied in the cart.
  /// When null, the full cart total is used.
  final double? discountedTotal;

  const PaymentCardScreen({super.key, this.discountedTotal});

  @override
  State<PaymentCardScreen> createState() => _PaymentCardScreenState();
}

class _PaymentCardScreenState extends State<PaymentCardScreen>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _cart        = CartService.instance;
  final _storage     = const FlutterSecureStorage();
  final _authService = AuthService();

  // ── card type ──────────────────────────────────────────────────────
  String _cardType = 'edahabia'; // or 'cib'

  // ── controllers ────────────────────────────────────────────────────
  final _numberCtrl  = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _expiryCtrl  = TextEditingController();
  final _cvvCtrl     = TextEditingController();

  // ── card preview live values ────────────────────────────────────────
  String _previewNumber = '•••• •••• •••• ••••';
  String _previewName   = 'FULL NAME';
  String _previewExpiry = 'MM/YY';
  String _previewCvv    = '•••';

  // ignore: unused_field
  bool _cvvFocused = false;
  bool _paying     = false;
  String _email    = '';

  // ── flip animation ──────────────────────────────────────────────────
  late final AnimationController _flipCtrl;
  late final Animation<double>   _flipAnim;

  // ── palette ─────────────────────────────────────────────────────────
  static const _bg    = Color(0xFFF5F0E8);
  static const _navy  = Color(0xFF0D1B2A);
  // ignore: unused_field
  static const _lime  = Color(0xFFD6F36A);

  // EDAHABIA — Algérie Poste green
  static const _edGrad1 = Color(0xFF005A32);
  static const _edGrad2 = Color(0xFF00A86B);

  // CIB — interbank blue/indigo
  static const _cibGrad1 = Color(0xFF0D1B2A);
  static const _cibGrad2 = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );

    _numberCtrl.addListener(_syncNumber);
    _nameCtrl.addListener(_syncName);
    _expiryCtrl.addListener(_syncExpiry);
    _cvvCtrl.addListener(_syncCvv);

    _loadEmail();
  }

  Future<void> _loadEmail() async {
    try {
      final e = await _storage.read(key: 'user_email') ?? '';
      if (mounted) setState(() => _email = e);
    } catch (_) {}
  }

  void _syncNumber() {
    final raw = _numberCtrl.text.replaceAll(' ', '');
    var s = '';
    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) s += ' ';
      s += i < raw.length ? raw[i] : '•';
    }
    setState(() => _previewNumber = s);
  }

  void _syncName() => setState(() =>
      _previewName = _nameCtrl.text.isEmpty ? 'FULL NAME' : _nameCtrl.text.toUpperCase());

  void _syncExpiry() => setState(() =>
      _previewExpiry = _expiryCtrl.text.isEmpty ? 'MM/YY' : _expiryCtrl.text);

  void _syncCvv() => setState(() =>
      _previewCvv = _cvvCtrl.text.isEmpty ? '•••' : _cvvCtrl.text);

  void _onCvvFocus(bool focused) {
    setState(() => _cvvFocused = focused);
    focused ? _flipCtrl.forward() : _flipCtrl.reverse();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  // ── getters ─────────────────────────────────────────────────────────
  Color get _grad1 => _cardType == 'edahabia' ? _edGrad1 : _cibGrad1;
  Color get _grad2 => _cardType == 'edahabia' ? _edGrad2 : _cibGrad2;
  Color get _accentColor => _cardType == 'edahabia' ? _edGrad1 : _cibGrad2;
  String get _cardLabel => _cardType == 'edahabia' ? 'EDAHABIA' : 'CIB';

  // ── payment ──────────────────────────────────────────────────────────
  //
  // Full flow:
  //   1. Validate card form
  //   2. Read JWT token from secure storage
  //   3. POST /api/place-order → creates order with status='pending', gets orderId
  //   4. POST Chargily /checkouts with orderId in metadata → gets checkout_url
  //   5. Open checkout_url in browser
  //   6. Chargily calls POST /api/webhook/chargily when payment succeeds
  //   7. Backend marks order status='completed'
  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _paying = true);

    try {
      // ── Step 2: auth token ──────────────────────────────────────
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        _snack(S.pleaseLoginFirst, error: true);
        return;
      }

      // ── Step 3: create pending order ────────────────────────────
      // Map Chargily card type to Order.paymentMethod enum values
      final paymentMethodLabel = _cardType == 'edahabia' ? 'Dahabia' : 'CIB';

      final orderRes = await _authService.placeOrder(
        token:         token,
        items:         _cart.items.map((i) => {
          'name':     i.name,
          'quantity': i.quantity,
          'price':    i.price.toDouble(),
        }).toList(),
        total:         widget.discountedTotal ?? _cart.totalPrice,
        paymentMethod: paymentMethodLabel,
      );

      if (!mounted) return;

      if (orderRes['statusCode'] != 201) {
        _snack(
          orderRes['body']['message'] ?? S.couldNotCreateOrder,
          error: true,
        );
        return;
      }

      final orderId = orderRes['body']['order']['_id'] as String;

      // ── Step 4: create Chargily checkout ────────────────────────
      final url = await ChargilyService().createCheckout(
        amount:        widget.discountedTotal ?? _cart.totalPrice,
        customerName:  _nameCtrl.text.trim(),
        customerEmail: _email.isNotEmpty ? _email : 'customer@novashop.app',
        orderId:       orderId,
        paymentMethod: _cardType,
      );

      if (!mounted) return;

      if (url == null || url.isEmpty) {
        _snack(S.couldNotGetPayLink, error: true);
        return;
      }

      // ── Step 5: open browser ─────────────────────────────────────
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;

      if (launched) {
        // Clear the cart — order is created and user is at Chargily's page.
        // The webhook will set status='completed' asynchronously.
        _cart.clear();
        _snack(S.redirectedToPayment);
      } else {
        _snack(S.couldNotOpenBrowser, error: true);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _snack(
        'Payment error: ${e.toString().replaceAll('Exception: ', '')}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(msg),
        backgroundColor: error ? Colors.red : _navy,
        duration:        const Duration(seconds: 4),
      ));

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(S.cardPayment,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Card type selector ─────────────────────────────
                Container(
                  padding:    const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10),
                    ],
                  ),
                  child: Row(children: [
                    _typeTab('edahabia', 'EDAHABIA', _edGrad1),
                    _typeTab('cib',      'CIB',       _cibGrad2),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Animated card ──────────────────────────────────
                AnimatedBuilder(
                  animation: _flipAnim,
                  builder: (_, _) {
                    final angle = _flipAnim.value * 3.14159;
                    final showBack = _flipAnim.value > 0.5;
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: showBack
                          ? Transform(
                              transform: Matrix4.identity()..rotateY(3.14159),
                              alignment: Alignment.center,
                              child: _cardWidget(back: true),
                            )
                          : _cardWidget(back: false),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Card number ─────────────────────────────────────
                _fieldLabel(S.cardNumber),
                const SizedBox(height: 6),
                _inputField(
                  controller:  _numberCtrl,
                  hint:        '0000  0000  0000  0000',
                  inputType:   TextInputType.number,
                  formatters:  [FilteringTextInputFormatter.digitsOnly, _CardNumberFmt()],
                  maxLength:   19,
                  prefixIcon:  Icons.credit_card,
                  validator:   (v) {
                    if ((v ?? '').replaceAll(' ', '').length != 16) return S.invalidCardNumber;
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ── Cardholder name ─────────────────────────────────
                _fieldLabel(S.cardholderName),
                const SizedBox(height: 6),
                _inputField(
                  controller: _nameCtrl,
                  hint:       'FIRST NAME LAST NAME',
                  inputType:  TextInputType.name,
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    _UpperCaseFmt(),
                  ],
                  prefixIcon: Icons.person_outline,
                  validator:  (v) {
                    if (v == null || v.trim().length < 3) return S.enterFullName;
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ── Expiry + CVV row ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel(S.expiryDate),
                          const SizedBox(height: 6),
                          _inputField(
                            controller: _expiryCtrl,
                            hint:       'MM/YY',
                            inputType:  TextInputType.number,
                            formatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFmt()],
                            maxLength:  5,
                            prefixIcon: Icons.date_range_outlined,
                            validator:  (v) {
                              if (v == null || v.length != 5) return S.invalid;
                              final m = int.tryParse(v.split('/').first) ?? 0;
                              if (m < 1 || m > 12) return S.invalidMonth;
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel(S.cvv),
                          const SizedBox(height: 6),
                          Focus(
                            onFocusChange: _onCvvFocus,
                            child: _inputField(
                              controller: _cvvCtrl,
                              hint:       '•••',
                              inputType:  TextInputType.number,
                              formatters: [FilteringTextInputFormatter.digitsOnly],
                              maxLength:  3,
                              obscure:    true,
                              prefixIcon: Icons.lock_outline,
                              validator:  (v) {
                                if ((v ?? '').length < 3) return S.invalid;
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Pay button ──────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_grad1, _grad2],
                      begin: Alignment.centerLeft,
                      end:   Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:      _grad1.withValues(alpha: 0.4),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _paying ? null : _pay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:         Colors.transparent,
                      shadowColor:             Colors.transparent,
                      disabledBackgroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _paying
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Pay ${_fmtDA(widget.discountedTotal ?? _cart.totalPrice)} — $_cardLabel',
                                style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Security badge ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 13, color: Colors.black38),
                    const SizedBox(width: 5),
                    Text(
                      S.securedByChargily,
                      style: const TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Card preview widget ───────────────────────────────────────────────────

  Widget _cardWidget({required bool back}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 195,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_grad1, _grad2],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _grad1.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: back ? _cardBackFace() : _cardFrontFace(),
    );
  }

  Widget _cardFrontFace() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: label + chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_cardLabel,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 17,
                      fontWeight: FontWeight.w900, letterSpacing: 2.5,
                    )),
                _chipWidget(),
              ],
            ),

            const Spacer(),

            // Card number
            Text(_previewNumber,
                style: const TextStyle(
                  color: Colors.white, fontSize: 19, letterSpacing: 4,
                  fontWeight: FontWeight.w500, fontFamily: 'monospace',
                )),

            const SizedBox(height: 14),

            // Name + expiry
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _cardFooterCol(S.cardHolder, _previewName),
                _cardFooterCol(S.expires, _previewExpiry, align: CrossAxisAlignment.end),
              ],
            ),
          ],
        ),
      );

  Widget _cardBackFace() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Magnetic stripe
          const SizedBox(height: 26),
          Container(height: 46, color: Colors.black87),
          const SizedBox(height: 18),

          // Signature + CVV panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: const Color(0xFFEEEEEE),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _previewName.replaceAll(RegExp(r'[A-Z]'), '/'),
                      style: const TextStyle(
                        color: Colors.black45, fontSize: 11,
                        fontStyle: FontStyle.italic, letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 58, height: 38,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Text(_previewCvv,
                      style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 3,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('CVV',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 9, letterSpacing: 2,
                  )),
            ),
          ),
        ],
      );

  Widget _chipWidget() => Container(
        width: 42, height: 32,
        decoration: BoxDecoration(
          color:        const Color(0xFFD4AF37).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(5),
        ),
        child: CustomPaint(painter: _EMVChipPainter()),
      );

  Widget _cardFooterCol(String label, String value, {CrossAxisAlignment align = CrossAxisAlignment.start}) =>
      Column(
        crossAxisAlignment: align,
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55), fontSize: 8, letterSpacing: 1.2,
              )),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8,
              )),
        ],
      );

  // ─── Helper widgets ────────────────────────────────────────────────────────

  Widget _typeTab(String value, String label, Color activeColor) {
    final sel = _cardType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _cardType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin:  const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color:        sel ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: sel
                ? [BoxShadow(color: activeColor.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                value == 'edahabia' ? Icons.account_balance : Icons.credit_card,
                size: 16,
                color: sel ? Colors.white : Colors.black45,
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color:      sel ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize:   13,
                    letterSpacing: 0.8,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700, color: _navy, fontSize: 13,
        ),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    int? maxLength,
    bool obscure = false,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller:     controller,
        keyboardType:   inputType,
        inputFormatters: formatters,
        maxLength:      maxLength,
        obscureText:    obscure,
        validator:      validator,
        style: const TextStyle(
          color: _navy, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1.5,
        ),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 1, fontWeight: FontWeight.normal),
          counterText: '',
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: Colors.black38)
              : null,
          filled:     true,
          fillColor:  Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide(color: _accentColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   const BorderSide(color: Colors.red, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      );

  String _fmtDA(double v) =>
      '${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} DA';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Text formatters
// ─────────────────────────────────────────────────────────────────────────────

class _CardNumberFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue val) {
    var digits = val.text.replaceAll(' ', '');
    if (digits.length > 16) digits = digits.substring(0, 16);
    var out = '';
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) out += ' ';
      out += digits[i];
    }
    return val.copyWith(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

class _ExpiryFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue val) {
    // Allow deletion: if removing a '/', strip the digit before it
    var digits = val.text.replaceAll('/', '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    var out = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) out += '/';
      out += digits[i];
    }
    return val.copyWith(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

class _UpperCaseFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue val) =>
      val.copyWith(text: val.text.toUpperCase());
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMV chip painter
// ─────────────────────────────────────────────────────────────────────────────

class _EMVChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = const Color(0xFFB8860B)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final w = size.width;
    final h = size.height;

    // outer rect
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(4)),
      p,
    );
    // vertical dividers
    canvas.drawLine(Offset(w * 0.35, 0), Offset(w * 0.35, h), p);
    canvas.drawLine(Offset(w * 0.65, 0), Offset(w * 0.65, h), p);
    // horizontal dividers
    canvas.drawLine(Offset(0, h * 0.38), Offset(w, h * 0.38), p);
    canvas.drawLine(Offset(0, h * 0.62), Offset(w, h * 0.62), p);
    // centre contact
    canvas.drawRect(Rect.fromLTWH(w * 0.35, h * 0.38, w * 0.30, h * 0.24), p..style = PaintingStyle.fill..color = const Color(0xFFDAA520).withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
