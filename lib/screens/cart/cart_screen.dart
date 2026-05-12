import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/cart_service.dart';
import '../../services/iot_service.dart';
import '../../l10n/app_strings.dart';
import '../scanner/scanner_screen.dart';
import 'checkout_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg        = Color(0xFFFAF3EE);
const _kDark      = Color(0xFF0D1B2A);
const _kLime      = Color(0xFFD6F36A);
const _kGrey      = Color(0xFF8A8A9A);
const _kRed       = Color(0xFFEF4444);
const _kHighlight = Color(0x33C6B3FF);
const _kGreen     = Color(0xFF4CAF50);

const _localImages = [
  'images/extracted_iphone.jpg',
  'images/extracted_headphones.jpg',
  'images/extracted_headphones2.jpg',
  'images/extracted_redlamp.jpg',
  'images/extracted_centila.jpg',
  'images/rouge.jpg',
];

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart      = CartService.instance;
  final _iot       = IotService.instance;
  final _promoCtrl = TextEditingController();
  String? _appliedPromo;
  double  _discount        = 0;
  bool    _checkoutEnabled = false;

  @override
  void initState() {
    super.initState();
    _iot.addListener(_onIotChanged);
    // If checkout was requested before this screen mounted, handle it now
    if (_iot.checkoutRequested) {
      _iot.clearCheckoutRequest();
      _checkoutEnabled = true;
    }
  }

  void _onIotChanged() {
    if (!mounted) return;
    if (_iot.checkoutRequested) {
      _iot.clearCheckoutRequest();
      setState(() => _checkoutEnabled = true);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    _iot.removeListener(_onIotChanged);
    super.dispose();
  }

  String _fmt(num price) =>
      '${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} DA';

  Future<void> _confirmDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.disconnectTitle,
            style: const TextStyle(color: _kDark, fontWeight: FontWeight.w800)),
        content: Text(S.disconnectMsg,
            style: const TextStyle(color: _kGrey, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel,
                style: const TextStyle(color: _kGrey, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.disconnect,
                style: const TextStyle(color: _kRed, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true) _iot.disconnect();
  }

  void _applyPromo() {
    final code = _promoCtrl.text.trim().toUpperCase();
    setState(() {
      if (code == 'DAIRY30') {
        _appliedPromo = code;
        _discount     = _cart.totalPrice * 0.30;
      } else if (code.isNotEmpty) {
        _appliedPromo = null;
        _discount     = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.invalidPromoCode)),
        );
      }
    });
  }

  Widget _productImage(CartItem item, int index) {
    final url = item.imageUrl;
    if (url.isNotEmpty) {
      if (url.startsWith('http')) {
        return Image.network(url, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackImg(index));
      }
      if (url.endsWith('.svg')) {
        return SvgPicture.asset(url, fit: BoxFit.contain);
      }
      return Image.asset(url, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackImg(index));
    }
    return _fallbackImg(index);
  }

  Widget _fallbackImg(int index) {
    final asset = _localImages[index % _localImages.length];
    if (asset.endsWith('.svg')) return SvgPicture.asset(asset, fit: BoxFit.contain);
    return Image.asset(asset, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    final hPad = w * 0.05;

    return ColoredBox(
      color: _kBg,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _cart,
          builder: (_, _) {
            final items    = _cart.items;
            final subtotal = _cart.totalPrice;
            final total    = (subtotal - _discount).clamp(0, double.infinity);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ───────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _iot.connected
                                  ? S.cartIotTitle(_iot.wagonId ?? '')
                                  : S.myCart,
                              style: TextStyle(
                                fontSize:      w * 0.062,
                                fontWeight:    FontWeight.w900,
                                color:         _kDark,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _iot.connected
                                  ? S.itemsConnected(items.length, _iot.serverIp ?? '')
                                  : S.itemsInCart(items.length),
                              style: TextStyle(
                                fontSize:   w * 0.03,
                                fontWeight: FontWeight.w500,
                                color:      _kGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Item count badge
                      if (items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color:        _kLime,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${items.length}',
                            style: TextStyle(
                              color:      _kDark,
                              fontSize:   w * 0.038,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── IoT connection banner ────────────────────────────
                if (_iot.connected) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFEBFAEE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _kGreen.withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color:  _kGreen,
                              shape:  BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:      _kGreen.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              S.scanningLive(_iot.serverIp ?? ''),
                              style: TextStyle(
                                fontSize:   w * 0.028,
                                fontWeight: FontWeight.w600,
                                color:      const Color(0xFF1A7A35),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _confirmDisconnect,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:        _kDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                S.disconnect,
                                style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   w * 0.027,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Empty state ──────────────────────────────────────
                if (items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(w * 0.07),
                            decoration: BoxDecoration(
                              color:        _kHighlight,
                              shape:        BoxShape.circle,
                            ),
                            child: Icon(Icons.shopping_bag_outlined,
                                size: w * 0.11, color: _kGrey),
                          ),
                          SizedBox(height: w * 0.05),
                          Text(
                            S.cartEmpty,
                            style: TextStyle(
                              color:      _kDark,
                              fontSize:   w * 0.045,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: w * 0.02),
                          Text(
                            _iot.connected
                                ? S.scanningLive(_iot.serverIp ?? '')
                                : S.scanCartQrHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:    _kGrey,
                              fontSize: w * 0.031,
                              height:   1.5,
                            ),
                          ),
                          if (!_iot.connected) ...[
                            SizedBox(height: w * 0.07),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ScannerScreen()),
                              ),
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: w * 0.12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 18),
                                decoration: BoxDecoration(
                                  color:        _kDark,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color:      _kDark.withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      offset:     const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.qr_code_scanner_rounded,
                                        color: _kLime, size: 22),
                                    const SizedBox(width: 12),
                                    Text(
                                      S.scanCartQr,
                                      style: TextStyle(
                                        color:      Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize:   w * 0.038,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else ...[

                  // ── Items list ─────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 4),
                      itemCount:        items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item     = items[i];
                        final isNewest = i == items.length - 1;
                        return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                            decoration: BoxDecoration(
                              color: isNewest ? _kHighlight : Colors.white,
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                color: isNewest
                                    ? const Color(0x55C6B3FF)
                                    : Colors.transparent,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isNewest ? 0.06 : 0.04),
                                  blurRadius: isNewest ? 12 : 8,
                                  offset:     const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [

                                // Product image
                                Container(
                                  width:  64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color:        const Color(0xFFF5F0FB),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _productImage(item, i),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Name + price per unit
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.brand.isNotEmpty
                                            ? item.brand
                                            : item.name,
                                        style: TextStyle(
                                          fontSize:   w * 0.038,
                                          fontWeight: FontWeight.w800,
                                          color:      _kDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: w * 0.029,
                                          color:    _kGrey,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${_fmt(item.price)} ${S.perUnit}',
                                        style: TextStyle(
                                          fontSize:   w * 0.027,
                                          color:      _kGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Qty controls + line total
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (_iot.connected)
                                      // Read-only qty when tablet controls quantity
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color:        _kHighlight,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '× ${item.quantity}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize:   w * 0.038,
                                            color:      _kDark,
                                          ),
                                        ),
                                      )
                                    else
                                      Row(
                                        children: [
                                          _qtyBtn(
                                            Icons.remove,
                                            () => _cart.decrement(item.id),
                                            isDark: isNewest,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              '${item.quantity}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize:   w * 0.042,
                                                color:      _kDark,
                                              ),
                                            ),
                                          ),
                                          _qtyBtn(
                                            Icons.add,
                                            () => _cart.increment(item.id),
                                            isDark: isNewest,
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      S.itemTotal(_fmt(item.price * item.quantity)),
                                      style: TextStyle(
                                        fontSize:   w * 0.028,
                                        fontWeight: FontWeight.w700,
                                        color:      _kDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        );
                      },
                    ),
                  ),

                  // ── Footer ────────────────────────────────────────
                  Container(
                    padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 20),
                    decoration: const BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black12,
                          blurRadius: 14,
                          offset:     Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [

                        // ── Promo code ─────────────────────────────
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color:  const Color(0xFFF3FCE4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kLime, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _promoCtrl,
                                  style: TextStyle(
                                      fontSize: w * 0.034, color: _kDark),
                                  decoration: InputDecoration(
                                    hintText:  S.promoHint,
                                    hintStyle: TextStyle(
                                        color: _kGrey, fontSize: w * 0.032),
                                    border:         InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _applyPromo,
                                child: Container(
                                  margin:  const EdgeInsets.all(6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:        _kDark,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    S.apply,
                                    style: TextStyle(
                                      color:      Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize:   w * 0.033,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Order summary ──────────────────────────
                        Container(
                          constraints: const BoxConstraints(minHeight: 118),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          decoration: BoxDecoration(
                            color:        _kBg,
                            borderRadius: BorderRadius.circular(15),
                            border: const Border(
                              bottom: BorderSide(
                                  color: Colors.black12, width: 1),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _summaryRow(S.subtotal, _fmt(subtotal), false),
                              if (_appliedPromo != null) ...[
                                const SizedBox(height: 6),
                                _summaryRow(
                                  S.discountWith(_appliedPromo!),
                                  '-${_fmt(_discount)}',
                                  false,
                                  valueColor: _kRed,
                                ),
                              ],
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Divider(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    height: 1),
                              ),
                              _summaryRow(S.total, _fmt(total), true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Checkout / waiting button ──────────────
                        if (!_iot.connected || _checkoutEnabled)
                          SizedBox(
                            width: double.infinity,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _checkoutEnabled = false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutScreen(
                                      discountedTotal: _discount > 0
                                          ? total as double
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 17),
                                decoration: BoxDecoration(
                                  color:        _kLime,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:      _kLime.withValues(alpha: 0.45),
                                      blurRadius: _checkoutEnabled ? 22 : 16,
                                      spreadRadius: _checkoutEnabled ? 2 : 0,
                                      offset:     const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_checkoutEnabled) ...[
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: _kDark,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        S.proceedCheckout,
                                        style: TextStyle(
                                          color:         _kDark,
                                          fontWeight:    FontWeight.w900,
                                          fontSize:      w * 0.04,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width:   double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            decoration: BoxDecoration(
                              color:        Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 7, height: 7,
                                  decoration: const BoxDecoration(
                                    color: _kGreen, shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Waiting for "Terminer la course"…',
                                  style: TextStyle(
                                    color:      _kGrey,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   w * 0.034,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isBold,
      {Color? valueColor}) {
    final w = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize:   w * 0.034,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color:      _kDark,
            )),
        Text(value,
            style: TextStyle(
              fontSize:   isBold ? w * 0.042 : w * 0.034,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              color:      valueColor ?? (isBold ? _kDark : _kGrey),
            )),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {bool isDark = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? _kDark.withValues(alpha: 0.10)
              : _kHighlight,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? _kDark.withValues(alpha: 0.15)
                : const Color(0x22C6B3FF),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 16, color: _kDark),
      ),
    );
  }
}
