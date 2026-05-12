import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/auth_service.dart';
import '../../l10n/app_strings.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  final _storage     = const FlutterSecureStorage();
  final _authService = AuthService();

  List<dynamic>  _orders       = [];
  bool           _loading      = true;
  String?        _error;
  String?        _expandedId;
  String         _filterStatus = 'all';

  // ── Selection state ───────────────────────────────────────────────
  bool           _selectMode   = false;
  final Set<String> _selected  = {};
  bool           _generating   = false;
  bool           _isDark       = false;

  // ── Palette ───────────────────────────────────────────────────────
  static const _bg       = Color(0xFFF5F0E8);
  static const _navy     = Color(0xFF0D1B2A);
  static const _lime     = Color(0xFFD6F36A);
  static const _textDark = Color(0xFF1A1A2E);
  static const _textGrey = Color(0xFF8A8A9A);

  // Status labels are now provided by S.statusLabel(key)
  static const _statusColor = {
    'completed': Color(0xFF4CAF50),
    'pending':   Color(0xFFFFA726),
    'cancelled': Color(0xFFEF5350),
    'refunded':  Color(0xFF9E9E9E),
  };
  static const _statusBg = {
    'completed': Color(0xFFE8F5E9),
    'pending':   Color(0xFFFFF3E0),
    'cancelled': Color(0xFFFFEBEE),
    'refunded':  Color(0xFFF5F5F5),
  };

  static IconData _payIcon(String? method) {
    switch (method) {
      case 'CIB':     return Icons.credit_card_rounded;
      case 'Dahabia': return Icons.account_balance_wallet_outlined;
      default:        return Icons.payments_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // ── Data loading ──────────────────────────────────────────────────

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        if (mounted) setState(() { _error = S.notLoggedIn; _loading = false; });
        return;
      }
      final res = await _authService.getOrderHistory(token);
      if (!mounted) return;
      if (res['statusCode'] == 200) {
        setState(() {
          _orders  = (res['body']['orders'] as List?) ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error   = res['body']['message'] ?? S.failedLoadOrders;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Connection error'; _loading = false; });
    }
  }

  // ── Selection helpers ─────────────────────────────────────────────

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selected.clear();
      _expandedId = null;
    });
  }

  void _toggleOrder(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final allIds =
          _filteredOrders.map((o) => o['_id']?.toString() ?? '').toSet();
      if (_selected.containsAll(allIds)) {
        _selected.clear();
      } else {
        _selected.addAll(allIds);
      }
    });
  }

  // ── PDF generation ────────────────────────────────────────────────

  Future<void> _downloadSelected() async {
    if (_selected.isEmpty || _generating) return;
    setState(() => _generating = true);

    try {
      final orders = _orders
          .where((o) => _selected.contains(o['_id']?.toString()))
          .toList();

      final bytes = await _buildPdf(orders);
      final label = orders.length == 1
          ? orders.first['_id'].toString().substring(
              (orders.first['_id'].toString().length - 8)
                  .clamp(0, orders.first['_id'].toString().length))
              .toUpperCase()
          : '${orders.length}_orders';

      final filename = 'NovaShop_Receipt_$label.pdf';

      String savedPath;
      if (Platform.isAndroid) {
        // Derive the public Downloads folder from the external storage path
        final ext = await getExternalStorageDirectory();
        final downloadsDir = ext != null
            ? Directory('${ext.path.split('/Android')[0]}/Download')
            : null;

        Directory dir;
        if (downloadsDir != null && await downloadsDir.exists()) {
          dir = downloadsDir;
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        savedPath = file.path;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        savedPath = file.path;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.pdfSaved}: $savedPath'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text('${S.pdfSaveError}: $e'),
            backgroundColor: Colors.red,
            behavior:        SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Uint8List> _buildPdf(List<dynamic> orders) async {
    final pdf = pw.Document();

    // ── PDF colour palette ────────────────────────────────────────
    const navyPdf  = PdfColor.fromInt(0xFF0D1B2A);
    const limePdf  = PdfColor.fromInt(0xFFD6F36A);
    const greyPdf  = PdfColor.fromInt(0xFF8A8A9A);
    const lightPdf = PdfColor.fromInt(0xFFF5F0E8);
    const whitePdf = PdfColors.white;
    const linePdf  = PdfColor.fromInt(0xFFE8E8E8);

    // ── One page per order ────────────────────────────────────────
    for (final order in orders) {
      final id       = order['_id']?.toString() ?? '';
      final shortId  = id.length >= 8
          ? id.substring(id.length - 8).toUpperCase()
          : id.toUpperCase();
      final customer = order['customer']?.toString() ?? '';
      final date     = order['date']?.toString() ??
          (order['createdAt']?.toString().substring(0, 10) ?? '');
      final total    = (order['total'] as num?) ?? 0;
      final payment  = order['paymentMethod']?.toString() ?? 'Cash';
      final status   = order['status']?.toString() ?? 'completed';
      final items    = (order['items'] as List?) ?? [];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin:     const pw.EdgeInsets.all(40),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // ── Header ───────────────────────────────────────────
              pw.Container(
                width:   double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 24, vertical: 18),
                decoration: const pw.BoxDecoration(
                  color:        navyPdf,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('NovaShop',
                            style: pw.TextStyle(
                              color:      limePdf,
                              fontSize:   22,
                              fontWeight: pw.FontWeight.bold,
                            )),
                        pw.SizedBox(height: 2),
                        pw.Text(S.purchaseReceipt,
                            style: const pw.TextStyle(
                                color: whitePdf, fontSize: 11)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('#$shortId',
                            style: pw.TextStyle(
                              color:      limePdf,
                              fontSize:   14,
                              fontWeight: pw.FontWeight.bold,
                              font:       pw.Font.courier(),
                            )),
                        pw.SizedBox(height: 2),
                        pw.Text(date,
                            style: const pw.TextStyle(
                                color: whitePdf, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // ── Customer / payment / status ───────────────────────
              pw.Row(
                children: [
                  _pdfInfoBox(S.customerLabel, customer, navyPdf, lightPdf),
                  pw.SizedBox(width: 12),
                  _pdfInfoBox(S.paymentMethod, payment, navyPdf, lightPdf),
                  pw.SizedBox(width: 12),
                  _pdfInfoBox(S.statusPdfLabel, S.statusLabel(status),
                      navyPdf, lightPdf),
                ],
              ),

              pw.SizedBox(height: 28),

              // ── Items table ───────────────────────────────────────
              pw.Text(S.orderItemsLabel,
                  style: pw.TextStyle(
                    color:         greyPdf,
                    fontSize:      9,
                    fontWeight:    pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  )),
              pw.SizedBox(height: 8),

              pw.Container(
                decoration: pw.BoxDecoration(
                  border:       pw.Border.all(color: linePdf),
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    // Header row
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: const pw.BoxDecoration(
                        color: navyPdf,
                        borderRadius: pw.BorderRadius.only(
                          topLeft:  pw.Radius.circular(8),
                          topRight: pw.Radius.circular(8),
                        ),
                      ),
                      child: pw.Row(children: [
                        pw.Expanded(flex: 4,
                            child: pw.Text(S.itemLabel,
                                style: pw.TextStyle(color: whitePdf,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.SizedBox(width: 50,
                            child: pw.Text(S.qtyLabel,
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(color: whitePdf,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.SizedBox(width: 70,
                            child: pw.Text(S.unitPriceLabel,
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(color: whitePdf,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.SizedBox(width: 80,
                            child: pw.Text(S.subtotal,
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(color: whitePdf,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold))),
                      ]),
                    ),

                    // Item rows
                    ...List.generate(items.length, (i) {
                      final item     = items[i];
                      final name     = item['name']?.toString() ?? '';
                      final qty      = (item['quantity'] as num?) ?? 1;
                      final price    = (item['price']    as num?) ?? 0;
                      final subtotal = qty * price;
                      final rowBg    = i.isEven ? whitePdf
                          : const PdfColor.fromInt(0xFFF9F9F9);
                      return pw.Container(
                        color:   rowBg,
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: pw.Row(children: [
                          pw.Expanded(flex: 4,
                              child: pw.Text(name,
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.SizedBox(width: 50,
                              child: pw.Text('×$qty',
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(
                                      fontSize: 10, color: greyPdf))),
                          pw.SizedBox(width: 70,
                              child: pw.Text(
                                  '${price.toStringAsFixed(0)} DA',
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.SizedBox(width: 80,
                              child: pw.Text(
                                  '${subtotal.toStringAsFixed(0)} DA',
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(fontSize: 10,
                                      fontWeight: pw.FontWeight.bold))),
                        ]),
                      );
                    }),

                    // Total row
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const pw.BoxDecoration(
                        color: lightPdf,
                        borderRadius: pw.BorderRadius.only(
                          bottomLeft:  pw.Radius.circular(8),
                          bottomRight: pw.Radius.circular(8),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('TOTAL',
                              style: pw.TextStyle(
                                color:         greyPdf,
                                fontSize:      9,
                                fontWeight:    pw.FontWeight.bold,
                                letterSpacing: 1,
                              )),
                          pw.SizedBox(width: 16),
                          pw.Text('${total.toStringAsFixed(0)} DA',
                              style: pw.TextStyle(
                                color:      navyPdf,
                                fontSize:   16,
                                fontWeight: pw.FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ── Footer ────────────────────────────────────────────
              pw.Divider(color: linePdf),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(S.thankYouMsg,
                      style: const pw.TextStyle(
                          color: greyPdf, fontSize: 9)),
                  pw.Text(
                    S.generatedOn(DateTime.now().toLocal().toString().substring(0, 16)),
                    style: const pw.TextStyle(
                        color: greyPdf, fontSize: 9),
                  ),
                ],
              ),

              // Page indicator for multi-order PDFs
              if (orders.length > 1) ...[
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    S.receiptOf(orders.indexOf(order) + 1, orders.length),
                    style: const pw.TextStyle(
                        color: greyPdf, fontSize: 8),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Uint8List.fromList(await pdf.save());
  }

  pw.Widget _pdfInfoBox(
      String label, String value, PdfColor accent, PdfColor bg) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color:        bg,
          border:       pw.Border.all(
              color: const PdfColor.fromInt(0xFFE0E0E0)),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(),
                style: pw.TextStyle(
                  color:         const PdfColor.fromInt(0xFF8A8A9A),
                  fontSize:      7,
                  fontWeight:    pw.FontWeight.bold,
                  letterSpacing: 0.8,
                )),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                  color:      accent,
                  fontSize:   11,
                  fontWeight: pw.FontWeight.bold,
                )),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  List<dynamic> get _filteredOrders => _filterStatus == 'all'
      ? _orders
      : _orders.where((o) =>
          (o['status']?.toString() ?? 'completed') == _filterStatus).toList();

  String _formatDA(num amount) => '${amount.toStringAsFixed(0)} DA';

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final w    = MediaQuery.of(context).size.width;
    final hPad = w * 0.05;
    final allIds = _filteredOrders
        .map((o) => o['_id']?.toString() ?? '').toSet();
    final allSelected = allIds.isNotEmpty && _selected.containsAll(allIds);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(hPad, allSelected),
            // ── Status filter tabs ────────────────────────────────
            if (!_loading && _error == null && _orders.isNotEmpty)
              _buildFilterTabs(hPad),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _navy))
                  : _error != null
                      ? _buildError()
                      : _filteredOrders.isEmpty
                          ? _buildEmpty()
                          : _buildContent(hPad),
            ),
            // Sticky download bar (shown in select mode)
            if (_selectMode && !_loading && _error == null)
              _buildDownloadBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(double hPad) {
    final filters = [
      ('all',       S.filterAll),
      ('pending',   S.filterPending),
      ('completed', S.filterCompleted),
      ('cancelled', S.filterCancelled),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 4),
        children: filters.map((f) {
          final isSel = _filterStatus == f.$1;
          final count = f.$1 == 'all'
              ? _orders.length
              : _orders
                  .where((o) =>
                      (o['status']?.toString() ?? 'completed') == f.$1)
                  .length;
          return GestureDetector(
            onTap: () => setState(() {
              _filterStatus = f.$1;
              _expandedId   = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:  const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSel ? _navy : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSel ? [] : [
                  BoxShadow(
                    color:      Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset:     const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(f.$2,
                      style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                          color:      isSel ? Colors.white : Colors.grey[700])),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSel
                            ? _lime
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                              fontSize:   10,
                              fontWeight: FontWeight.w700,
                              color: isSel ? _navy : Colors.grey[600])),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(double hPad, bool allSelected) {
    return Container(
      color:   _isDark ? const Color(0xFF1A1A1A) : _bg,
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 16),
      child: Row(
        children: [
          Container(
            padding:    const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        _navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: _lime, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.purchaseHistory,
                  style: TextStyle(
                      color:      _isDark ? Colors.white : _textDark,
                      fontSize:   20,
                      fontWeight: FontWeight.w800)),
              if (!_loading && _error == null)
                Text(
                  _selectMode
                      ? S.selectedCount(_selected.length)
                      : S.ordersCount(_orders.length),
                  style: TextStyle(
                    color:      _selectMode ? _navy : _textGrey,
                    fontSize:   12,
                    fontWeight: _selectMode
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
            ],
          ),
          const Spacer(),

          // Select-all (only in select mode)
          if (_selectMode) ...[
            GestureDetector(
              onTap: _selectAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color:        allSelected ? _navy : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: _navy, width: 1.5),
                ),
                child: Text(
                  allSelected ? S.deselectAll : S.selectAll,
                  style: TextStyle(
                    color:      allSelected ? Colors.white : _navy,
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Select / Cancel toggle
          GestureDetector(
            onTap: _selectMode ? _toggleSelectMode : _toggleSelectMode,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        _selectMode ? _navy : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset:     const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _selectMode
                    ? Icons.close_rounded
                    : Icons.checklist_rounded,
                color: _selectMode ? Colors.white : _navy,
                size:  20,
              ),
            ),
          ),

          if (!_selectMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loadOrders,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset:     const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: _navy, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sticky download bar ───────────────────────────────────────────

  Widget _buildDownloadBar() {
    final count   = _selected.length;
    final enabled = count > 0 && !_generating;

    return Container(
      color:   _bg,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: GestureDetector(
        onTap: enabled ? _downloadSelected : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width:    double.infinity,
          padding:  const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color:        enabled ? _navy : _navy.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color:      _navy.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset:     const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_generating)
                const SizedBox(
                  width:  16,
                  height: 16,
                  child:  CircularProgressIndicator(
                      strokeWidth: 2, color: _lime),
                )
              else
                const Icon(Icons.picture_as_pdf_rounded,
                    color: _lime, size: 20),
              const SizedBox(width: 10),
              Text(
                _generating
                    ? S.generatingPdf
                    : count == 0
                        ? S.selectToDownload
                        : S.downloadCount(count),
                style: TextStyle(
                  color:      count == 0 && !_generating
                      ? Colors.white60
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize:   14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────

  Widget _buildContent(double hPad) {
    return RefreshIndicator(
      color:     _navy,
      onRefresh: _loadOrders,
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
        children: [
          if (!_selectMode && _filterStatus == 'all') ...[
            _buildSummary(),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 8),
          ..._filteredOrders.map((o) => _buildOrderCard(o)),
        ],
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────────

  Widget _buildSummary() {
    final totalSpent = _orders
        .where((o) => (o['status']?.toString() ?? '') == 'completed')
        .fold<num>(0, (s, o) => s + ((o['total'] as num?) ?? 0));
    final completed  = _orders.where((o) =>
        (o['status']?.toString() ?? 'completed') == 'completed').length;

    return Row(
      children: [
        _summaryCard(S.ordersLabel, '${_orders.length}',
            Icons.shopping_bag_outlined, _navy, Colors.white),
        const SizedBox(width: 10),
        _summaryCard(S.doneLabel, '$completed',
            Icons.check_circle_outline_rounded, _lime, _navy),
        const SizedBox(width: 10),
        _summaryCard(S.spentLabel,
            '${totalSpent.toStringAsFixed(0)} DA',
            Icons.payments_outlined, _navy, Colors.white),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding:    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color:      fg,
                    fontSize:   16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color:      fg.withValues(alpha: 0.7),
                    fontSize:   10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Order card ────────────────────────────────────────────────────

  Widget _buildOrderCard(dynamic order) {
    final id       = order['_id']?.toString() ?? '';
    final status   = order['status']?.toString() ?? 'completed';
    final date     = order['date']?.toString() ??
        (order['createdAt']?.toString().substring(0, 10) ?? '');
    final total    = (order['total'] as num?) ?? 0;
    final payment  = order['paymentMethod']?.toString() ?? 'Cash';
    final items    = (order['items'] as List?) ?? [];
    final expanded = _expandedId == id && !_selectMode;
    final checked  = _selected.contains(id);

    return GestureDetector(
      onTap: () {
        if (_selectMode) {
          _toggleOrder(id);
        } else {
          setState(() => _expandedId = expanded ? null : id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color:        _isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: _selectMode && checked
              ? Border.all(color: _navy, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Checkbox (select mode) or status dot (normal mode)
                  if (_selectMode)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width:    22,
                      height:   22,
                      decoration: BoxDecoration(
                        color:        checked ? _navy : Colors.transparent,
                        border:       Border.all(
                          color: checked ? _navy : _textGrey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: checked
                          ? const Icon(Icons.check_rounded,
                              color: _lime, size: 14)
                          : null,
                    )
                  else
                    Container(
                      width:  8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _statusColor[status] ?? _textGrey,
                        shape: BoxShape.circle,
                      ),
                    ),

                  const SizedBox(width: 10),

                  // Order ID + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${id.length >= 8 ? id.substring(id.length - 8).toUpperCase() : id.toUpperCase()}',
                          style: const TextStyle(
                            color:      _textDark,
                            fontWeight: FontWeight.w700,
                            fontSize:   14,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(date,
                            style: const TextStyle(
                                color: _textGrey, fontSize: 11)),
                      ],
                    ),
                  ),

                  Icon(_payIcon(payment), color: _textGrey, size: 18),
                  const SizedBox(width: 8),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBg[status] ??
                          const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      S.statusLabel(status),
                      style: TextStyle(
                        color:      _statusColor[status] ?? _textGrey,
                        fontSize:   11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    _formatDA(total),
                    style: const TextStyle(
                      color:      _textDark,
                      fontWeight: FontWeight.w800,
                      fontSize:   14,
                    ),
                  ),

                  if (!_selectMode) ...[
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns:    expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child:    const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _textGrey,
                          size:  20),
                    ),
                  ],
                ],
              ),
            ),

            // ── Expanded items (normal mode only) ─────────────────
            if (expanded) ...[
              Divider(
                  height: 1,
                  color:  Colors.grey.withValues(alpha: 0.15)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.itemsLabel,
                        style: TextStyle(
                          color:         _textGrey,
                          fontSize:      11,
                          fontWeight:    FontWeight.w600,
                          letterSpacing: 0.5,
                        )),
                    const SizedBox(height: 8),
                    ...items.map<Widget>((item) {
                      final name  = item['name']?.toString() ?? '';
                      final qty   = (item['quantity'] as num?) ?? 1;
                      final price = (item['price']    as num?) ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width:  32,
                              height: 32,
                              decoration: BoxDecoration(
                                color:        const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 16, color: _textGrey),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                    color:      _textDark,
                                    fontSize:   13,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                            Text('×$qty',
                                style: const TextStyle(
                                    color:    _textGrey,
                                    fontSize: 12)),
                            const SizedBox(width: 12),
                            Text(
                              _formatDA(price * qty),
                              style: const TextStyle(
                                color:      _textDark,
                                fontWeight: FontWeight.w700,
                                fontSize:   13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(S.total,
                            style: const TextStyle(
                              color:      _textGrey,
                              fontSize:   12,
                              fontWeight: FontWeight.w600,
                            )),
                        Text(
                          _formatDA(total),
                          style: const TextStyle(
                            color:      _navy,
                            fontWeight: FontWeight.w800,
                            fontSize:   15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding:    const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 48, color: _navy),
          ),
          const SizedBox(height: 20),
          Text(S.noOrders,
              style: TextStyle(
                  color:      _textDark,
                  fontSize:   18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(S.noOrdersMsg,
              style: TextStyle(color: _textGrey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: _textGrey),
          const SizedBox(height: 16),
          Text(_error!,
              style: const TextStyle(color: _textGrey, fontSize: 14)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadOrders,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color:        _navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(S.retry,
                  style: TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
