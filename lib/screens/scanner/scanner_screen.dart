import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/iot_service.dart';
import '../../services/cart_service.dart';
import '../../l10n/app_strings.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFFFAF3EE);
const _kDark  = Color(0xFF0D1B2A);
const _kLav   = Color(0xFFB4A8F5);
const _kLavBg = Color(0xFFF0ECFB);
const _kLime  = Color(0xFFD6F36A);
const _kGrey  = Color(0xFF8A8A9A);
const _kGreen = Color(0xFF4CAF50);

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  final IotService  _iot  = IotService.instance;
  final CartService _cart = CartService.instance;

  bool _cameraOpen = false;

  // Pulse animation for linking state
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // Progress bar animation
  late AnimationController _progressCtrl;
  late Animation<double>   _progressAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(_progressCtrl);

    _iot.addListener(_onIotChanged);
  }

  @override
  void dispose() {
    // Stop first, then dispose — avoids leaving the camera resource held
    _scanner.stop()
        .catchError((_) {})
        .whenComplete(_scanner.dispose);
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _iot.removeListener(_onIotChanged);
    super.dispose();
  }

  void _onIotChanged() {
    if (!mounted) return;
    if (_iot.connected) {
      _progressCtrl.stop();
      // Return to cart screen — it already handles the connected state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
      return;
    }
    setState(() {});
  }

  Future<void> _openCamera() async {
    if (_cameraOpen) return; // already open — prevent double-start
    // Ensure clean state before starting
    try { await _scanner.stop(); } catch (_) {}
    setState(() => _cameraOpen = true);
    try { await _scanner.start(); } catch (_) {}
  }

  // Called when mobile_scanner detects a QR code on the tablet.
  // QR format: novashop://<ip>:5004/<wagonId>
  Future<void> _onQrDetected(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || _iot.linking || _iot.connected) return;
    try { await _scanner.stop(); } catch (_) {}
    setState(() => _cameraOpen = false);

    String? ip;
    String  wagonId;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'novashop' && uri.host.isNotEmpty) {
      ip      = uri.host;
      wagonId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    } else {
      wagonId = raw.contains('/') ? raw.split('/').last : raw;
    }

    if (ip == null || ip.isEmpty || wagonId.isEmpty) {
      _showSnack(S.invalidQr);
      return;
    }

    // Read real user identity + health profile stored at login
    const storage = FlutterSecureStorage();
    final userId        = await storage.read(key: 'user_id')        ?? 'guest';
    final userName      = await storage.read(key: 'user_name')      ?? 'Customer';
    final allergiesRaw  = await storage.read(key: 'user_allergies')  ?? '[]';
    final lifestylesRaw = await storage.read(key: 'user_lifestyles') ?? '[]';

    List<String> parseList(String raw) {
      try { return List<String>.from(jsonDecode(raw)); } catch (_) { return []; }
    }

    _progressCtrl.forward(from: 0);

    final ok = await _iot.linkToWagon(
      serverIp:   ip,
      wagonId:    wagonId,
      userId:     userId,
      userName:   userName,
      allergies:  parseList(allergiesRaw),
      lifestyles: parseList(lifestylesRaw),
    );

    if (!ok && mounted) {
      _showSnack(_iot.lastError ?? S.couldNotConnect);
      _progressCtrl.reset();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    if (_iot.linking || _iot.connected) return _buildLinkingPage(w, h);
    return _buildScanPage(w, h);
  }

  // ── PAGE 1: CONNECT CART ─────────────────────────────────────────────────

  Widget _buildScanPage(double w, double h) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: h * 0.05),

              Text(
                S.connectCart,
                style: TextStyle(
                  fontSize: w * 0.065,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: h * 0.03),

              // ── WiFi hint ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.08),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kLavBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_rounded, color: _kLav, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          S.wifiHint,
                          style: TextStyle(
                              color: _kDark,
                              fontSize: w * 0.03,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: h * 0.025),

              // ── QR viewfinder ───────────────────────────────────────────
              SizedBox(
                height: w * 0.72,
                child: Center(
                  child: _cameraOpen
                      ? _buildCameraView(w)
                      : _buildQrPlaceholder(w),
                ),
              ),
              SizedBox(height: h * 0.03),

              // Instructions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.1),
                child: Column(
                  children: [
                    _step(S.step1),
                    SizedBox(height: h * 0.01),
                    _step(S.step2),
                    SizedBox(height: h * 0.01),
                    _step(S.step3),
                    SizedBox(height: h * 0.01),
                    _step(S.step4),
                  ],
                ),
              ),
              SizedBox(height: h * 0.035),

              // Open Camera button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.08),
                child: GestureDetector(
                  onTap: _openCamera,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: _kLavBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        S.openCamera,
                        style: TextStyle(
                          color: _kDark,
                          fontWeight: FontWeight.w900,
                          fontSize: w * 0.042,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: h * 0.04),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrPlaceholder(double w) {
    final size = w * 0.62;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kLav, width: 2),
      ),
      child: Stack(
        children: [
          ..._corners(size, _kLav),
          Center(
            child: Icon(Icons.qr_code_2_rounded,
                size: size * 0.55, color: _kLav.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView(double w) {
    final size = w * 0.72;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            MobileScanner(
              controller: _scanner,
              onDetect: _onQrDetected,
            ),
            CustomPaint(
              size: Size(size, size),
              painter: _BracketPainter(_kLav),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
      );

  // ── PAGE 2: LINKING (connecting animation) ───────────────────────────────

  Widget _buildLinkingPage(double w, double h) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, _) => SizedBox(
                width: w * 0.55,
                height: w * 0.55,
                child: CustomPaint(
                  painter: _PulseRingsPainter(
                    _pulseAnim.value,
                    _kLav.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Container(
                      width: w * 0.18,
                      height: w * 0.18,
                      decoration: const BoxDecoration(
                        color: _kLavBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shopping_cart_outlined,
                          size: w * 0.08, color: _kGrey),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: h * 0.04),

            Text(
              S.linkingToCart,
              style: TextStyle(
                fontSize: w * 0.055,
                fontWeight: FontWeight.w900,
                color: _kDark,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: h * 0.012),

            Text(
              _iot.serverIp != null
                  ? S.connectingTo(_iot.serverIp!)
                  : S.establishingConn,
              style: TextStyle(fontSize: w * 0.032, color: _kGrey),
            ),
            SizedBox(height: h * 0.022),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06),
              child: AnimatedBuilder(
                animation: _progressAnim,
                builder: (_, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progressAnim.value,
                    minHeight: 12,
                    backgroundColor: _kDark,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progressAnim.value < 0.5 ? _kLav : _kLime,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── (connected state is handled by cart_screen.dart) ─────────────────────

  Widget _buildConnectedPage(double w, double h) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _cart,
          builder: (_, _) {
            final items = _cart.items;
            return Column(
              children: [
                // Connected banner
                Padding(
                  padding: EdgeInsets.fromLTRB(w * 0.05, h * 0.022, w * 0.05, h * 0.018),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: _kLavBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: const BoxDecoration(
                            color: _kLav, shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.cartConnected(_iot.wagonId ?? ''),
                                style: TextStyle(
                                  fontSize: w * 0.036,
                                  fontWeight: FontWeight.w800,
                                  color: _kDark,
                                ),
                              ),
                              Text(
                                S.scanningLive(_iot.serverIp ?? ''),
                                style: TextStyle(fontSize: w * 0.027, color: _kGrey),
                              ),
                            ],
                          ),
                        ),
                        // Disconnect
                        GestureDetector(
                          onTap: _iot.disconnect,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Disconnect',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (items.isEmpty)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: h * 0.28,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              _floatingIcon(Icons.room_service_outlined,
                                  Offset(-w * 0.22, -h * 0.04)),
                              _floatingIcon(Icons.coffee_outlined,
                                  Offset(-w * 0.08, -h * 0.1)),
                              _floatingIcon(Icons.dry_cleaning_outlined,
                                  Offset(w * 0.02, -h * 0.03)),
                              _floatingIcon(Icons.sports_basketball_outlined,
                                  Offset(w * 0.14, -h * 0.08)),
                              _floatingIcon(Icons.chair_outlined,
                                  Offset(w * 0.06, -h * 0.155)),
                              _floatingIcon(Icons.blender_outlined,
                                  Offset(-w * 0.15, -h * 0.17)),
                              Icon(Icons.shopping_cart_outlined,
                                  size: w * 0.28,
                                  color: _kGrey.withValues(alpha: 0.35)),
                            ],
                          ),
                        ),
                        SizedBox(height: h * 0.025),
                        Text(
                          'Your cart is empty',
                          style: TextStyle(
                            fontSize: w * 0.045,
                            fontWeight: FontWeight.w800,
                            color: _kDark,
                          ),
                        ),
                        SizedBox(height: h * 0.01),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.1),
                          child: Text(
                            "The tablet will scan products automatically.\nThey'll appear here instantly.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: w * 0.031, color: _kGrey, height: 1.5),
                          ),
                        ),
                        SizedBox(height: h * 0.03),

                        // Live indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: _kGreen, shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Listening for scans…',
                              style: TextStyle(
                                  fontSize: w * 0.03,
                                  color: _kGreen,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                          horizontal: w * 0.05, vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(
                                  color: _kLavBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: item.imageUrl.startsWith('http')
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(item.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Icon(
                                                Icons.inventory_2_outlined,
                                                color: _kGrey, size: 22)),
                                      )
                                    : Icon(Icons.inventory_2_outlined,
                                        color: _kGrey, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.brand.isNotEmpty ? item.brand : item.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: w * 0.035,
                                        color: _kDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                          fontSize: w * 0.028, color: _kGrey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${item.price.toStringAsFixed(0)} DA / unit',
                                      style: TextStyle(
                                          fontSize: w * 0.026, color: _kGrey),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _qtyBtn(Icons.remove,
                                      () => _cart.decrement(item.id)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Text('${item.quantity}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _kDark,
                                          fontSize: w * 0.04,
                                        )),
                                  ),
                                  _qtyBtn(Icons.add,
                                      () => _cart.increment(item.id)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _floatingIcon(IconData icon, Offset offset) => Transform.translate(
        offset: offset,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: _kGrey.withValues(alpha: 0.6)),
        ),
      );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(
            color: _kLavBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: _kDark),
        ),
      );

  List<Widget> _corners(double size, Color color) {
    const len = 24.0;
    const t   = 2.5;
    return [
      _cornerLine(left: 12, top: 12, width: len, height: t, color: color),
      _cornerLine(left: 12, top: 12, width: t, height: len, color: color),
      _cornerLine(right: 12, top: 12, width: len, height: t, color: color),
      _cornerLine(right: 12, top: 12, width: t, height: len, color: color),
      _cornerLine(left: 12, bottom: 12, width: len, height: t, color: color),
      _cornerLine(left: 12, bottom: 12, width: t, height: len, color: color),
      _cornerLine(right: 12, bottom: 12, width: len, height: t, color: color),
      _cornerLine(right: 12, bottom: 12, width: t, height: len, color: color),
    ];
  }

  Widget _cornerLine({
    double? left, double? right, double? top, double? bottom,
    required double width, required double height, required Color color,
  }) =>
      Positioned(
        left: left, right: right, top: top, bottom: bottom,
        child: Container(
          width: width, height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

// ── Pulse rings painter ──────────────────────────────────────────────────────
class _PulseRingsPainter extends CustomPainter {
  final double pulse;
  final Color  color;
  const _PulseRingsPainter(this.pulse, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR   = size.width / 2;
    final paint  = Paint()..style = PaintingStyle.fill;
    for (int i = 3; i >= 1; i--) {
      final r = maxR * (i / 3.0) * pulse;
      paint.color = color.withValues(alpha: 0.12 * i);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingsPainter old) => old.pulse != pulse;
}

// ── Bracket overlay painter ───────────────────────────────────────────────────
class _BracketPainter extends CustomPainter {
  final Color color;
  const _BracketPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = 3.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    const len = 28.0;
    final l = 8.0, t = 8.0;
    final r = size.width - 8, b = size.height - 8;
    canvas.drawLine(Offset(l, t + len), Offset(l, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l + len, t), paint);
    canvas.drawLine(Offset(r - len, t), Offset(r, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + len), paint);
    canvas.drawLine(Offset(l, b - len), Offset(l, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l + len, b), paint);
    canvas.drawLine(Offset(r - len, b), Offset(r, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r, b - len), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}
