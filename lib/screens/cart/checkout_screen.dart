import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../payment/payment_card_screen.dart';
import '../../l10n/app_strings.dart';

class CheckoutScreen extends StatefulWidget {
  /// Optional discounted total from a promo code applied in the cart.
  /// When null, the full cart total is used.
  final double? discountedTotal;

  const CheckoutScreen({super.key, this.discountedTotal});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _cart        = CartService.instance;
  final _storage     = const FlutterSecureStorage();
  final _authService = AuthService();

  String _paymentMethod = 'Cash';
  bool   _placing       = false;
  bool   _success       = false;

  static const _bg   = Color(0xFFF5F0E8);
  static const _navy = Color(0xFF0D1B2A);
  static const _lime = Color(0xFFD6F36A);
  static const _red  = Color(0xFFEF4444);

  String _fmt(num p) =>
      '${p.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} DA';

  // ── Cash order ──────────────────────────────────────────────────────
  Future<void> _placeCashOrder(String token) async {
    setState(() => _placing = true);

    final items = _cart.items
        .map((i) => {'name': i.name, 'quantity': i.quantity, 'price': i.price.toDouble()})
        .toList();

    final total = widget.discountedTotal ?? _cart.totalPrice;

    final res = await _authService.placeOrder(
      token:         token,
      items:         items,
      total:         total,
      paymentMethod: 'Cash',
    );

    if (!mounted) return;
    setState(() => _placing = false);

    if (res['statusCode'] == 201) {
      _cart.clear();
      setState(() => _success = true);
    } else {
      _snack(res['body']['message'] ?? 'Order failed', error: true);
    }
  }

  // ── Main action ─────────────────────────────────────────────────────
  Future<void> _placeOrder() async {
    if (_placing) return;

    if (_paymentMethod == 'Electronic') {
      // Delegate entirely to the card payment screen
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => PaymentCardScreen(
            discountedTotal: widget.discountedTotal,
          )));
      return;
    }

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) { _snack(S.pleaseLoginFirst, error: true); return; }
    await _placeCashOrder(token);
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(msg),
        backgroundColor: error ? _red : _navy,
        duration:        const Duration(seconds: 4),
      ));

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_success) return _successScreen();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: _navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(S.checkout,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Order summary ─────────────────────────────────────
              _sectionLabel(S.orderSummary),
              const SizedBox(height: 8),
              _card(child: Column(children: [
                ..._cart.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Text(item.name,
                          style: const TextStyle(color: _navy, fontWeight: FontWeight.w600)),
                    ),
                    Text('${item.quantity} × ${_fmt(item.price)}',
                        style: const TextStyle(color: Colors.black54)),
                  ]),
                )),
                const Divider(height: 16),
                if (widget.discountedTotal != null && widget.discountedTotal != _cart.totalPrice) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(S.subtotal,
                          style: const TextStyle(color: Colors.black54)),
                      Text(_fmt(_cart.totalPrice),
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.black38, fontSize: 13,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(S.discount,
                          style: const TextStyle(color: _red)),
                      Text('-${_fmt(_cart.totalPrice - widget.discountedTotal!)}',
                          style: const TextStyle(color: _red, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.total,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
                    Text(_fmt(widget.discountedTotal ?? _cart.totalPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: _navy,
                        )),
                  ],
                ),
              ])),

              const SizedBox(height: 20),

              // ── Payment method ────────────────────────────────────
              _sectionLabel(S.paymentMethod),
              const SizedBox(height: 8),
              _card(child: Row(children: [
                _methodTile('Cash',       Icons.payments_outlined, S.cash),
                const SizedBox(width: 10),
                _methodTile('Electronic', Icons.credit_card,       S.electronic),
              ])),

              // ── Electronic info banner ────────────────────────────
              if (_paymentMethod == 'Electronic') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFF0FDE8),
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: _lime, width: 1.5),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 16, color: _navy),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        S.electronicNote,
                        style: const TextStyle(fontSize: 12, color: _navy),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 32),

              // ── Confirm button ────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _placing ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:         _navy,
                    foregroundColor:         _lime,
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _placing
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _paymentMethod == 'Electronic'
                              ? S.enterCardDetails
                              : S.confirmCashOrder,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodTile(String value, IconData icon, String label) {
    final sel = _paymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:        sel ? _navy : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? Colors.white : Colors.black45),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                  color:      sel ? Colors.white : _navy,
                  fontWeight: FontWeight.w600,
                )),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.bold,
          color: Colors.black45, letterSpacing: 0.5,
        ),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _successScreen() => Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:    const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              ),
              const SizedBox(height: 24),
              Text(S.orderPlaced,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _navy)),
              const SizedBox(height: 8),
              Text(S.orderPlacedMsg,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: _lime,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(S.backToCart,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
}
