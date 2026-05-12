import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/favorites_service.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_strings.dart';

class _Review {
  final String   id;
  final String   author;
  final int      rating;
  final String   comment;
  final DateTime date;
  const _Review({required this.id, required this.author, required this.rating,
                 required this.comment, required this.date});
}

// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _pageCtrl;
  int _currentPage  = 0;
  int _userRating   = 0;
  bool _isSubmitting = false;

  final _commentCtrl  = TextEditingController();
  final _storage      = const FlutterSecureStorage();
  final _authService  = AuthService();

  String?         _token;
  String          _userName        = '';
  List<_Review>   _reviews         = [];
  bool            _reviewsLoaded   = false;

  // ── Derived fields ──────────────────────────────────────────────────────────

  String get _id =>
      widget.product['localId'] as String? ??
      widget.product['_id']     as String? ??
      (widget.product['name']   as String? ?? '');

  List<Map<String, dynamic>> get _variants {
    final v = widget.product['variants'];
    if (v is List && v.isNotEmpty) {
      return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final local = widget.product['localImage'] as String? ?? '';
    final net   = widget.product['imageUrl']   as String? ?? '';
    return [{'image': local.isNotEmpty ? local : net, 'label': ''}];
  }

  double get _avgRating {
    if (_reviews.isNotEmpty) {
      return _reviews.map((e) => e.rating).reduce((a, b) => a + b) / _reviews.length;
    }
    // Fall back to server-aggregated value until local list is loaded
    final v = widget.product['avgRating'];
    return v != null ? (v as num).toDouble() : 0.0;
  }

  int get _ratingsCount {
    if (_reviewsLoaded) return _reviews.length;
    return (widget.product['ratingsCount'] as num?)?.toInt() ?? 0;
  }

  // ── Life-cycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _commentCtrl.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    _token    = await _storage.read(key: 'jwt_token');
    _userName = await _storage.read(key: 'user_name') ?? S.anonymous;
    await _loadReviews();
  }

  Future<void> _loadReviews() async {
    final productId = widget.product['_id'] as String?;
    if (productId == null || productId.isEmpty) return;

    final result = await _authService.getFeedback(productId);
    if (!mounted) return;
    if (result['statusCode'] == 200) {
      final list = (result['body']['feedback'] as List?) ?? [];
      setState(() {
        _reviews = list.map((e) {
          final map = e as Map<String, dynamic>;
          return _Review(
            id:      map['_id']     as String? ?? '',
            author:  map['userName'] as String? ?? S.anonymous,
            rating:  (map['rating'] as num).toInt(),
            comment: map['text']    as String? ?? '',
            date:    DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
          );
        }).toList();
        _reviewsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _submitReview() async {
    final text = _commentCtrl.text.trim();
    if (_userRating == 0 || text.isEmpty) return;

    final productId = widget.product['_id'] as String?;
    if (productId == null || productId.isEmpty) return;

    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.loginToReview)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _authService.submitFeedback(
      token:     _token!,
      productId: productId,
      rating:    _userRating,
      text:      text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['statusCode'] == 201) {
      final rating = _userRating;
      setState(() {
        final newId = (result['body']['feedback']?['_id'] as String?) ?? '';
        _reviews = [
          _Review(id: newId, author: _userName, rating: rating, comment: text, date: DateTime.now()),
          ..._reviews.where((r) => r.author != _userName || r.comment != text),
        ];
        _reviewsLoaded = true;
        _userRating = 0;
        _commentCtrl.clear();
      });
    } else {
      final msg = result['body']['message'] as String? ?? S.submissionError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ── Image helper ─────────────────────────────────────────────────────────────

  Widget _img(String src) {
    if (src.isEmpty)            return _placeholder();
    if (src.startsWith('http')) return Image.network(src, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder());
    if (src.endsWith('.svg'))   return SvgPicture.asset(src, fit: BoxFit.cover);
    return Image.asset(src, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder());
  }

  Widget _warningBanner({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
                const SizedBox(height: 3),
                Text(message,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 12,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    const colors = {
      'Electronics': Color(0xFFAED6FF),
      'Home':        Color(0xFFFFEE93),
      'Beauty':      Color(0xFFE8CAFF),
    };
    final cat = widget.product['category'] as String? ?? '';
    return Container(color: colors[cat] ?? const Color(0xFFE0E0E0));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final h     = MediaQuery.of(context).size.height;
    final pad   = MediaQuery.of(context).padding;
    final fav   = FavoritesService.instance;

    final name     = widget.product['name']        as String? ?? '';
    final brand    = widget.product['brand']       as String? ?? '';
    final price    = widget.product['price'];
    final desc     = widget.product['description'] as String?
                     ?? S.defaultProductDesc;
    final cat      = widget.product['category']    as String? ?? '';
    final localImg = widget.product['localImage']  as String?;
    final asset    = localImg ?? _id;

    final priceStr = price != null ? '${(price as num).toStringAsFixed(0)} DA' : '';
    final variants = _variants;
    final images   = variants.map((v) => v['image'] as String? ?? '').toList();
    final canSubmit = _userRating > 0 && _commentCtrl.text.trim().isNotEmpty && !_isSubmitting;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Image gallery (SliverAppBar) ──────────────────────────────────
          SliverAppBar(
            expandedHeight: h * 0.52,
            pinned: false,
            stretch: true,
            backgroundColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: _glassBtn(Icons.arrow_back_ios_new_rounded),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: ListenableBuilder(
                  listenable: fav,
                  builder: (_, _) {
                    final isFav = fav.contains(asset);
                    return GestureDetector(
                      onTap: () => fav.toggle(FavoriteItem(
                        asset:       asset,
                        name:        name,
                        price:       price != null ? (price as num).toInt() : 0,
                        category:    cat,
                        brand:       brand,
                        description: desc,
                      )),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: isFav
                                  ? Colors.red.withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isFav
                                    ? Colors.red.withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFav ? Colors.red : Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // PageView — swipe entre variantes
                  PageView.builder(
                    controller: _pageCtrl,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) => _img(images[i]),
                  ),

                  // Gradient bottom → dark background
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: 100,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xFF0D1B2A)],
                        ),
                      ),
                    ),
                  ),

                  // Dot indicators
                  if (images.length > 1)
                    Positioned(
                      bottom: 18,
                      left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (i) =>
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width:  _currentPage == i ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == i
                                  ? const Color(0xFFD6F36A)
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Product info + reviews ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Category chip
                  if (cat.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x22D6F36A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x55D6F36A)),
                      ),
                      child: Text(
                        cat.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFD6F36A),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                  // ── Recommendation warnings ───────────────────
                  Builder(builder: (_) {
                    final warnAllergy = widget.product['warning_allergy'] as bool? ?? false;
                    final warnHealth  = widget.product['warning_health']  as bool? ?? false;
                    if (!warnAllergy && !warnHealth) return const SizedBox.shrink();

                    final rawAllergens = widget.product['matched_allergens'];
                    final allergenList = rawAllergens is List
                        ? rawAllergens.map((e) => e.toString()).toList()
                        : <String>[];
                    final allergenText = allergenList.isNotEmpty
                        ? allergenList.map((a) => a[0].toUpperCase() + a.substring(1)).join(', ')
                        : null;

                    final rawReasons = widget.product['health_reasons'];
                    final reasonList = rawReasons is List
                        ? rawReasons.map((e) => e.toString()
                            .replaceAll('⚠', '').replaceAll('ℹ', '').trim()).toList()
                        : <String>[];
                    final healthMsg = reasonList.isNotEmpty
                        ? reasonList.first
                        : S.healthWarningMsg;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (warnAllergy)
                          _warningBanner(
                            icon: Icons.warning_amber_rounded,
                            title: S.allergenDetected,
                            message: allergenText != null
                                ? S.allergenContains(allergenText)
                                : S.allergenWarningMsg,
                            color: const Color(0xFFFFC107),
                          ),
                        if (warnAllergy && warnHealth) const SizedBox(height: 8),
                        if (warnHealth)
                          _warningBanner(
                            icon: Icons.health_and_safety_rounded,
                            title: S.healthWarningTitle,
                            message: healthMsg,
                            color: const Color(0xFFFF5252),
                          ),
                        const SizedBox(height: 20),
                      ],
                    );
                  }),

                  // Name + Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          )),
                      ),
                      if (priceStr.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(priceStr,
                          style: const TextStyle(
                            color: Color(0xFFD6F36A),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          )),
                      ],
                    ],
                  ),

                  if (brand.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(brand,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      )),
                  ],

                  // ── Aisle & Expiry chips ──────────────────────────────
                  Builder(builder: (_) {
                    final aisle  = widget.product['aisle']  as String? ?? '';
                    final expiry = widget.product['expiry'] as String? ?? '';
                    if (aisle.isEmpty && expiry.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (aisle.isNotEmpty)
                            _infoChip(
                              icon: Icons.store_mall_directory_outlined,
                              label: 'Aisle  $aisle',
                            ),
                          if (expiry.isNotEmpty)
                            _infoChip(
                              icon: Icons.event_outlined,
                              label: 'Exp  $expiry',
                              warn: _isExpiringSoon(expiry),
                            ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // ── Average stars ────────────────────────────────────
                  _buildAverageStars(),

                  const SizedBox(height: 20),
                  _divider(),
                  const SizedBox(height: 20),

                  // ── Variants (si plusieurs) ──────────────────────────
                  if (variants.length > 1) ...[
                    _buildVariants(variants),
                    const SizedBox(height: 20),
                    _divider(),
                    const SizedBox(height: 20),
                  ],

                  // ── Description ──────────────────────────────────────
                  Text(S.descriptionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
                  const SizedBox(height: 8),
                  Text(desc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13.5,
                      height: 1.65,
                    )),


                  const SizedBox(height: 36),
                  _divider(),
                  const SizedBox(height: 28),

                  // ── Reviews section ──────────────────────────────────
                  _buildReviewsSection(canSubmit),

                  SizedBox(height: pad.bottom + 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _glassBtn(IconData icon) => ClipOval(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color:  Colors.white.withValues(alpha: 0.18),
          shape:  BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    ),
  );

  Widget _divider() => Divider(color: Colors.white.withValues(alpha: 0.1), height: 1);

  /// Returns true when the expiry date is within 30 days or already past.
  bool _isExpiringSoon(String expiry) {
    final date = DateTime.tryParse(expiry);
    if (date == null) return false;
    return date.difference(DateTime.now()).inDays <= 30;
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    bool warn = false,
  }) {
    final color = warn ? const Color(0xFFFF5252) : const Color(0xFFD6F36A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageStars() {
    final avg   = _avgRating;
    final count = _ratingsCount;
    return Row(
      children: [
        ...List.generate(5, (i) => Icon(
          i < avg.round() ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFFFD700),
          size: 22,
        )),
        const SizedBox(width: 10),
        Text(
          count > 0
              ? S.ratingCount(avg.toStringAsFixed(1), count)
              : S.noReviewsYet,
          style: TextStyle(
            color:    Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildVariants(List<Map<String, dynamic>> variants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.variantsLabel,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: List.generate(variants.length, (i) {
            final v       = variants[i];
            final label   = v['label'] as String?  ?? v['color'] as String? ?? S.optionN(i + 1);
            final hexColor = v['colorHex'] as String?;
            final isSelected = _currentPage == i;

            Color? chipColor;
            if (hexColor != null) {
              try {
                chipColor = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
              } catch (_) {}
            }

            return GestureDetector(
              onTap: () {
                _pageCtrl.animateToPage(i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut);
                setState(() => _currentPage = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFD6F36A)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFD6F36A)
                        : Colors.white.withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chipColor != null) ...[
                      Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: chipColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(label,
                      style: TextStyle(
                        color:      isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize:   13,
                      )),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(bool canSubmit) {
    final reviews = List<_Review>.from(_reviews)
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.customerReviews,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          )),
        const SizedBox(height: 20),

        // ── Write review ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.leaveReview,
                style: TextStyle(
                  color:      Colors.white.withValues(alpha: 0.85),
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                )),
              const SizedBox(height: 14),

              // Star selector
              Row(
                children: [
                  Text(S.ratingLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    )),
                  const SizedBox(width: 4),
                  ...List.generate(5, (i) => GestureDetector(
                    onTap: () => setState(() => _userRating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        i < _userRating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFFFD700),
                        size: 30,
                      ),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 10),

              // Comment
              _inputField(_commentCtrl, S.writeComment, maxLines: 3),
              const SizedBox(height: 14),

              // Submit
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: canSubmit ? _submitReview : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 46,
                    decoration: BoxDecoration(
                      color: canSubmit
                          ? const Color(0xFFD6F36A)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : Text(
                            S.publishReview,
                            style: TextStyle(
                              color:      canSubmit ? Colors.black : Colors.white30,
                              fontWeight: FontWeight.w700,
                              fontSize:   14,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Reviews list ──────────────────────────────────────
        if (reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              S.beFirstToReview,
              style: TextStyle(
                color:    Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
          )
        else
          ...reviews.map(_buildReviewCard),
      ],
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
    TextField(
      controller: ctrl,
      maxLines:   maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
        filled:    true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: Color(0xFFD6F36A)),
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 14, vertical: maxLines > 1 ? 12 : 10),
        isDense: true,
      ),
    );

  Widget _buildReviewCard(_Review r) {
    final isOwner = r.author == _userName;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r.author,
                style: const TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize:   14,
                )),
              Row(
                children: [
                  ...List.generate(5, (i) => Icon(
                    i < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFD700),
                    size: 15,
                  )),
                  if (isOwner) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _editReview(r),
                      child: Icon(Icons.edit_outlined,
                          size: 17, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _deleteReview(r),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 17, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.comment,
            style: TextStyle(
              color:  Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.5,
            )),
          const SizedBox(height: 8),
          Text(_fmtDate(r.date),
            style: TextStyle(
              color:    Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            )),
        ],
      ),
    );
  }

  Future<void> _editReview(_Review r) async {
    final productId = widget.product['_id'] as String?;
    if (productId == null || productId.isEmpty || _token == null) return;

    final editCommentCtrl = TextEditingController(text: r.comment);
    int editRating = r.rating;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1A2A3A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit review',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Star selector
              Row(
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setDlg(() => editRating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      i < editRating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFD700),
                      size: 28,
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: editCommentCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Your comment',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD6F36A)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save', style: TextStyle(color: Color(0xFFD6F36A), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    editCommentCtrl.dispose();
    if (confirmed != true || !mounted) return;

    final newText   = editCommentCtrl.text.trim();
    if (newText.isEmpty || editRating == 0) return;

    final result = await _authService.submitFeedback(
      token:     _token!,
      productId: productId,
      rating:    editRating,
      text:      newText,
    );

    if (!mounted) return;
    if (result['statusCode'] == 201) {
      setState(() {
        final idx = _reviews.indexWhere((e) => e.id == r.id);
        if (idx != -1) {
          _reviews[idx] = _Review(
            id:      r.id,
            author:  r.author,
            rating:  editRating,
            comment: newText,
            date:    DateTime.now(),
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['body']['message'] as String? ?? S.submissionError)),
      );
    }
  }

  Future<void> _deleteReview(_Review r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete review',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Remove your review permanently?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF5252))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (r.id.isNotEmpty && _token != null) {
      await _authService.deleteFeedback(token: _token!, feedbackId: r.id);
    }
    setState(() => _reviews.removeWhere((e) => e.id == r.id && e.author == r.author));
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
