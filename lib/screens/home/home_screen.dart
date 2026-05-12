import 'dart:async';
import 'dart:math' show pi, Random;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/favorites_service.dart';
import '../../services/iot_service.dart';
import '../../l10n/app_strings.dart';
import '../profile/profile_screen.dart';
import '../purchase_history/purchase_history_screen.dart';
import '../cart/cart_screen.dart';
import '../search/search_screen.dart';
import '../favorites/favorites_screen.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _storage          = const FlutterSecureStorage();
  final _searchCtrl       = TextEditingController();
  final _authService      = AuthService();
  final _cart             = CartService.instance;
  final _favorites        = FavoritesService.instance;
  final _iot              = IotService.instance;
  final _catScrollCtrl    = ScrollController();
  final _promosScrollCtrl = ScrollController();
  final _recsScrollCtrl   = ScrollController();

  late final AnimationController _shineCtrl;
  late final Animation<Color?>    _shineAnim;

  String  _userName = '';
  String  _userId   = '';
  int _currentIndex = 0;
  String _selectedCategory = 'All';
  Timer? _debounce;
  bool _searchActive = false;

  List<dynamic> _products = [];
  List<dynamic> _recommendations = [];
  List<dynamic> _promotions = [];
  bool _productsLoading = false;
  bool _promosLoading = false;
  bool _recsLoading = false;
  bool _isDark = false;
  int  _notifBadge = 0;

  Set<String> _userAllergies  = {};
  Set<String> _userLifestyles = {};

  static const _foodCategories = <String>{
    'groceries', 'beverages', 'dairy', 'meat', 'bakery',
  };

  static const _lifestyleRules = <String, List<String>>{
    'vegan':        ['milk','cheese','egg','butter','honey','cream','whey','casein','lactose','gelatin','beef','chicken','pork','fish','shrimp','meat'],
    'vegetarian':   ['beef','chicken','pork','fish','shrimp','lamb','meat','gelatin','lard'],
    'keto':         ['sugar','flour','starch','bread','rice','oat','corn','potato','wheat','carb','pasta','cereal'],
    'diabetic':     ['sugar','glucose','fructose','syrup','sweetener','dextrose','maltose','corn syrup','honey','molasses'],
    'glutenfree':   ['wheat','gluten','barley','rye','flour','bread','pasta','oat','semolina','spelt'],
    'halal':        ['alcohol','ethanol','gelatin','lard','pork','wine','beer','rum','bacon','ham'],
    'lowsalt':      ['salt','sodium','soy sauce','brine','msg','monosodium','pickle'],
    'lowfat':       ['fat','oil','butter','cream','lard','margarine','shortening','grease'],
    'lactosfree':   ['milk','lactose','cheese','butter','cream','whey','casein','yogurt'],
    'hearthealthy': ['sodium','salt','saturated fat','trans fat','cholesterol','lard','butter','palm oil'],
    'lowsugar':     ['sugar','glucose','fructose','syrup','dextrose','maltose','sweetener','candy','chocolate'],
  };

  static const _lifestyleLabels = <String, String>{
    'vegan':        'vegan',
    'vegetarian':   'vegetarian',
    'keto':         'keto',
    'diabetic':     'diabetic',
    'glutenfree':   'gluten-free',
    'halal':        'halal',
    'lowsalt':      'low-salt',
    'lowfat':       'low-fat',
    'lactosfree':   'lactose-free',
    'hearthealthy': 'heart-healthy',
    'lowsugar':     'low-sugar',
  };

  static String _normalizeTag(String tag) =>
      tag.toLowerCase().replaceAll('-', '').replaceAll(' ', '').replaceAll('_', '');

  static String _productText(dynamic p) => [
    p['name']             ?? '',
    p['description']      ?? '',
    p['category']         ?? '',
    p['ingredients_text'] ?? '',
    ...((p['ingredients'] as List?) ?? []),
    ...((p['tags']        as List?) ?? []),
  ].join(' ').toLowerCase();

  static Set<String> _productKeywords(dynamic p) {
    final raw = p['keywords'];
    if (raw is! List) return {};
    return raw.map((e) => e.toString().toLowerCase().trim()).toSet();
  }

  List<String> _matchedAllergens(dynamic p) {
    if (_userAllergies.isEmpty) return [];
    final raw = p['allergens'];
    if (raw is! List) return [];
    final productAllergens = raw.map((e) => e.toString().toLowerCase().trim()).toSet();
    return _userAllergies.intersection(productAllergens)
        .map((a) => a[0].toUpperCase() + a.substring(1))
        .toList()
      ..sort();
  }

  List<String> _healthMessages(dynamic p) {
    if (_userLifestyles.isEmpty) return [];
    final cat = (p['category'] as String? ?? '').toLowerCase();
    if (!_foodCategories.contains(cat)) return [];

    final text     = _productText(p);
    final kwSet    = _productKeywords(p);
    final messages = <String>[];

    for (final lifestyle in _userLifestyles) {
      final ruleKw = _lifestyleRules[lifestyle];
      if (ruleKw == null) continue;

      final matchedText = ruleKw.where((k) => text.contains(k)).toList();
      final matchedKw   = ruleKw.where((k) => kwSet.contains(k)).toList();
      final matched     = {...matchedText, ...matchedKw}.toList();
      if (matched.isEmpty) continue;

      final label = _lifestyleLabels[lifestyle] ?? lifestyle;
      messages.add('This product contains: ${matched.join(', ')} — against your $label lifestyle');
    }
    return messages;
  }

  // ── Local products ─────────────────────────────────────────────────────────
  static const List<_Category> _categories = [
    _Category('All',         Icons.grid_view_rounded),
    _Category('Groceries',   Icons.local_grocery_store_outlined),
    _Category('Dairy',       Icons.egg_outlined),
    _Category('Bakery',      Icons.breakfast_dining_outlined),
    _Category('Beverages',   Icons.local_drink_outlined),
    _Category('Meat',        Icons.set_meal_outlined),
    _Category('Beauty',      Icons.spa_outlined),
    _Category('Electronics', Icons.devices_outlined),
    _Category('Clothing',    Icons.checkroom_outlined),
    _Category('Sports',      Icons.sports_soccer_outlined),
    _Category('Home',        Icons.home_outlined),
  ];

  static const Map<String, Color> _catColors = {
    'Groceries':   Color(0xFFD6F36A),
    'Dairy':       Color(0xFFBBE1FA),
    'Bakery':      Color(0xFFFFDBA4),
    'Beverages':   Color(0xFFB8F0E6),
    'Meat':        Color(0xFFFFBDBD),
    'Beauty':      Color(0xFFE8CAFF),
    'Electronics': Color(0xFFAED6FF),
    'Clothing':    Color(0xFFFFCFD4),
    'Sports':      Color(0xFFFFE0B2),
    'Home':        Color(0xFFFFEE93),
    'Other':       Color(0xFFE0E0E0),
  };

  static const Map<String, IconData> _catIcons = {
    'Groceries':   Icons.local_grocery_store_outlined,
    'Dairy':       Icons.egg_outlined,
    'Bakery':      Icons.breakfast_dining_outlined,
    'Beverages':   Icons.local_drink_outlined,
    'Meat':        Icons.set_meal_outlined,
    'Beauty':      Icons.spa_outlined,
    'Electronics': Icons.devices_outlined,
    'Clothing':    Icons.checkroom_outlined,
    'Sports':      Icons.sports_soccer_outlined,
    'Home':        Icons.home_outlined,
    'Other':       Icons.inventory_2_outlined,
  };

  @override
  void initState() {
    super.initState();
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shineAnim = ColorTween(
      begin: const Color(0xFFE6F494),
      end:   const Color(0xFFC6B3FF),
    ).animate(CurvedAnimation(parent: _shineCtrl, curve: Curves.easeInOut));
    _iot.addListener(_onIotCheckout);
    _loadUserData();
    _fetchProducts();
    _fetchPromotions();
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() => _productsLoading = true);
    try {
      final res = await _authService.getProducts(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['statusCode'] == 200) {
        final list = List<dynamic>.from(
            (res['body']['products'] as List?) ?? []);
        setState(() { _products = _sortProducts(list); _productsLoading = false; });
      } else {
        setState(() => _productsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  Future<void> _fetchPromotions() async {
    if (!mounted) return;
    setState(() => _promosLoading = true);
    try {
      final res = await _authService.getPromotions();
      if (!mounted) return;
      if (res['statusCode'] == 200) {
        final list = List<dynamic>.from(
            (res['body']['products'] as List?) ?? []);
        final storedStr = await _storage.read(key: 'last_seen_promos_count');
        final stored    = int.tryParse(storedStr ?? '0') ?? 0;
        final badge     = (list.length - stored).clamp(0, 99);
        if (!mounted) return;
        setState(() {
          _promotions   = list;
          _promosLoading = false;
          _notifBadge   = badge;
        });
      } else {
        if (mounted) setState(() => _promosLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _promosLoading = false);
    }
  }

  List<dynamic> _sortProducts(List<dynamic> list) {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      final starts = list.where((p) =>
          (p['name'] as String? ?? '').toLowerCase().startsWith(query)).toList();
      final rest = list.where((p) =>
          !(p['name'] as String? ?? '').toLowerCase().startsWith(query)).toList();
      return [...starts, ...rest];
    }
    return list;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _iot.removeListener(_onIotCheckout);
    _shineCtrl.dispose();
    _searchCtrl.dispose();
    _catScrollCtrl.dispose();
    _promosScrollCtrl.dispose();
    _recsScrollCtrl.dispose();
    super.dispose();
  }

  void _onIotCheckout() {
    if (_iot.checkoutRequested && _currentIndex != 1) {
      setState(() => _currentIndex = 1);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final token  = await _storage.read(key: 'jwt_token');
      final name   = await _storage.read(key: 'user_name') ?? '';
      final userId = await _storage.read(key: 'user_id')   ?? '';
      if (!mounted) return;
      setState(() {
        _userName = name.split(' ').first;
        _userId   = userId;
        if (userId.isNotEmpty) _recsLoading = true;
      });
      if (userId.isNotEmpty) _fetchRecommendations(userId);

      if (token != null) {
        final res = await _authService.getProfile(token);
        if (res['statusCode'] == 200) {
          final user = res['body']['user'] as Map<String, dynamic>? ?? {};
          final allergies  = (user['allergies'] as List?)
              ?.map((e) => e.toString().toLowerCase().trim()).toSet() ?? <String>{};
          final lifestyles = (user['lifestyles'] as List?)
              ?.map((e) => _normalizeTag(e.toString()))
              .where((t) => t.isNotEmpty && t != 'none')
              .toSet() ?? <String>{};
          if (mounted) setState(() { _userAllergies = allergies; _userLifestyles = lifestyles; });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchRecommendations(String userId) async {
    if (!mounted) return;
    setState(() => _recsLoading = true);
    try {
      final res = await _authService.getRecommendationsDirect(userId);
      if (!mounted) return;
      if (res['statusCode'] == 200) {
        final list = List<dynamic>.from(
            (res['body']['recommendations'] as List?) ?? []);
        setState(() {
          _recommendations = list;
          _recsLoading     = false;
        });
      } else {
        setState(() => _recsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _recsLoading = false);
    }
  }

  void _onCategoryTap(String cat) {
    setState(() => _selectedCategory = cat);
    _fetchProducts();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      setState(() => _searchActive = v.trim().isNotEmpty);
      _fetchProducts();
    });
  }

  void _onSearchSubmit(String v) {
    _debounce?.cancel();
    setState(() => _searchActive = v.trim().isNotEmpty);
    _fetchProducts();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _searchActive = false);
    _fetchProducts();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _cardColor(String? category) =>
      _catColors[category ?? ''] ?? const Color(0xFFE8E8E8);

  IconData _cardIcon(String? category) =>
      _catIcons[category ?? ''] ?? Icons.inventory_2_outlined;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final double hPad     = (w * 0.045).clamp(14.0, 24.0);
    final double navPad   = (w * 0.03).clamp(10.0, 18.0);
    final double navH     = (h * 0.08).clamp(56.0, 80.0);
    final double navIconSz= (w * 0.06).clamp(20.0, 28.0);

    if (_currentIndex == 1) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const CartScreen(),
        bottomNavigationBar: _buildNavBar(navPad, navH, navIconSz),
      );
    }

    if (_currentIndex == 2) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SearchScreen(),
        bottomNavigationBar: _buildNavBar(navPad, navH, navIconSz),
      );
    }

    if (_currentIndex == 3) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const PurchaseHistoryScreen(),
        bottomNavigationBar: _buildNavBar(navPad, navH, navIconSz),
      );
    }

    if (_currentIndex == 4) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const FavoritesScreen(),
        bottomNavigationBar: _buildNavBar(navPad, navH, navIconSz),
      );
    }

    if (_currentIndex == 5) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const ProfileScreen(),
        bottomNavigationBar: _buildNavBar(navPad, navH, navIconSz),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: Stack(
        children: [
          const _FloatingIconsBg(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── Fixed: welcome header ─────────────────────────────────
                _buildHeader(w, h, hPad),
                // ── Fixed: search bar ─────────────────────────────────────
                _buildSearch(w, h, hPad),
                SizedBox(height: h * 0.008),
                // ── Scrollable content ────────────────────────────────────
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ── PROMOTIONS (horizontal scroll) ──────────────────
                      if (_promosLoading || _promotions.isNotEmpty) ...[
                        SliverToBoxAdapter(child: _buildSectionHeader(
                          Icons.local_fire_department_rounded, 'Promotions', hPad, w, h)),
                        SliverToBoxAdapter(child: _buildPromotionsRow(w, h, hPad)),
                      ],

                      SliverToBoxAdapter(child: SizedBox(height: h * 0.01)),

                      // ── RECOMMENDATIONS (2-column grid) ──────────────────
                      if (_userId.isNotEmpty) ...[
                        SliverToBoxAdapter(child: _buildSectionHeader(
                          Icons.auto_awesome_rounded, 'Recommandés pour vous', hPad, w, h)),
                        if (_recsLoading)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, h * 0.02),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (_, _) => _buildProductSkeleton(),
                                childCount: 4,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: w > 900 ? 4 : 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 163 / 232,
                              ),
                            ),
                          )
                        else if (_recommendations.isEmpty)
                          SliverToBoxAdapter(child: _buildRecsEmptyState(w, h, hPad))
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, h * 0.02),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildRecCard(_recommendations[i], w, h),
                                childCount: _recommendations.length,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: w > 900 ? 4 : 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 163 / 232,
                              ),
                            ),
                          ),
                      ],

                      SliverToBoxAdapter(child: SizedBox(height: h * 0.12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(navPad, navH, navIconSz),
    );
  }

  // ── Section builders ───────────────────────────────────────────────────────

  Widget _buildHeader(double w, double h, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, h * 0.02, hPad, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userName.isNotEmpty ? 'Welcome $_userName,' : 'Welcome,',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize:   (w * 0.055).clamp(18.0, 28.0),
                  color:      _isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
              Text(
                'check the new deals',
                style: TextStyle(
                  fontSize:   (w * 0.032).clamp(11.0, 15.0),
                  color:      Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _notifIconBtn(w, h, hPad),
              SizedBox(width: w * 0.025),
              _iconBtn(Icons.person_outline_rounded, () {
                setState(() => _currentIndex = 5);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(double w, double h, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, h * 0.012, hPad, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _searchActive
                ? const Color(0xFFD6F36A)
                : const Color(0xFFE0E0E0),
            width: _searchActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              color: _searchActive
                  ? const Color(0xFF0D1B2A)
                  : const Color(0xFF9E9E9E),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:  _searchCtrl,
                onChanged:   _onSearchChanged,
                onSubmitted: _onSearchSubmit,
                style: const TextStyle(
                  fontSize:   15,
                  color:      Color(0xFF0D1B2A),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText:  'Search by product, brand ...',
                  hintStyle: TextStyle(
                    fontSize:   15,
                    color:      Colors.grey[400],
                    fontWeight: FontWeight.w400,
                  ),
                  border:         InputBorder.none,
                  isDense:        true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchActive)
              GestureDetector(
                onTap: _clearSearch,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.black54, size: 13),
                  ),
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _warningBadge({
    required IconData icon,
    required String   label,
    required Color    color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 11),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productImage(String url, Color bg, IconData icon, double w) {
    final placeholder = Container(
      color: bg,
      child: Center(
          child: Icon(icon,
              size:  (w * 0.1).clamp(32.0, 52.0),
              color: Colors.black26)),
    );
    final isValidUrl = url.startsWith('http://') || url.startsWith('https://');
    if (!isValidUrl) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (_, _, _) => placeholder,
    );
  }

  Widget _infoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 9),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  color:      Colors.white70,
                  fontSize:   9,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Notification icon with badge ──────────────────────────────────────────
  Widget _notifIconBtn(double w, double h, double hPad) {
    return GestureDetector(
      onTap: () => _showNotificationsSheet(w, h, hPad),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:  const Color(0x33C6B3FF),
                  shape:  BoxShape.circle,
                  border: Border.all(color: const Color(0x1AC6B3FF), width: 1),
                ),
                child: Icon(
                  _notifBadge > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 22, color: Colors.black,
                ),
              ),
            ),
          ),
          if (_notifBadge > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Color(0xFFFF4D4D), shape: BoxShape.circle),
                child: Text(
                  _notifBadge > 9 ? '9+' : '$_notifBadge',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showNotificationsSheet(double w, double h, double hPad) async {
    await _storage.write(
        key: 'last_seen_promos_count', value: '${_promotions.length}');
    if (mounted) setState(() => _notifBadge = 0);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize:     0.4,
        maxChildSize:     0.92,
        expand:           false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: _isDark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF5F0E8),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _shineAnim,
                      builder: (_, _) => Icon(
                          Icons.local_fire_department_rounded,
                          size: 22, color: _shineAnim.value),
                    ),
                    const SizedBox(width: 10),
                    Text('Promotions',
                        style: TextStyle(
                            fontSize:   20,
                            fontWeight: FontWeight.w800,
                            color: _isDark
                                ? Colors.white
                                : const Color(0xFF0D1B2A))),
                    const Spacer(),
                    if (_promotions.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color:        const Color(0xFFFF4D4D),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('${_promotions.length} deals',
                            style: const TextStyle(
                                color:      Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize:   12)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _promotions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No active promotions',
                                style: TextStyle(
                                    color:    Colors.grey[500],
                                    fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: ctrl,
                        padding: EdgeInsets.fromLTRB(
                            hPad, 14, hPad, h * 0.06),
                        itemCount:        _promotions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            _buildPromoNotifTile(_promotions[i], w),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoNotifTile(dynamic p, double w) {
    final cat      = p['category']  as String? ?? '';
    final bgColor  = _cardColor(cat);
    final iconData = _cardIcon(cat);
    final name     = p['name']      as String? ?? '';
    final brand    = p['brand']     as String? ?? '';
    final price    = (p['price']    as num?)?.toDouble() ?? 0;
    final discount = (p['discount'] as num?)?.toInt() ?? 0;
    final imageUrl = p['imageUrl']  as String? ?? '';
    final discounted = price * (1 - discount / 100);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: Map<String, dynamic>.from(p as Map)),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isDark
              ? null
              : [
                  BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset:     const Offset(0, 2))
                ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                  width: 80, height: 80,
                  child: _productImage(imageUrl, bgColor, iconData, w)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize:   14,
                            color: _isDark ? Colors.white : const Color(0xFF0D1B2A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (brand.isNotEmpty)
                      Text(brand,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('${price.toInt()} DA',
                            style: TextStyle(
                                decoration:      TextDecoration.lineThrough,
                                decorationColor: Colors.grey[400],
                                color:           Colors.grey[400],
                                fontSize:        12)),
                        const SizedBox(width: 8),
                        Text('${discounted.toInt()} DA',
                            style: const TextStyle(
                                color:      Color(0xFF0D1B2A),
                                fontWeight: FontWeight.w800,
                                fontSize:   14)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color:        const Color(0xFFFF4D4D),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('-$discount%',
                    style: const TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize:   13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionsRow(double w, double h, double hPad) {
    final cardH = (h * 0.22).clamp(150.0, 210.0);

    if (_promosLoading) {
      return SizedBox(
        height: cardH,
        child: ListView.separated(
          primary:         false,
          scrollDirection: Axis.horizontal,
          physics:         const BouncingScrollPhysics(),
          padding:         EdgeInsets.fromLTRB(hPad, 0, hPad, h * 0.012),
          itemCount:       4,
          separatorBuilder: (_, _) => SizedBox(width: w * 0.03),
          itemBuilder: (_, _) => _buildRecSkeletonCard(w, h),
        ),
      );
    }

    if (_promotions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: cardH,
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: hPad * 0.5),
            child: _scrollBtn(true, _promosScrollCtrl),
          ),
          Expanded(
            child: ListView.separated(
              controller:       _promosScrollCtrl,
              primary:          false,
              scrollDirection:  Axis.horizontal,
              physics:          const BouncingScrollPhysics(),
              padding:          EdgeInsets.fromLTRB(8, 0, 8, h * 0.015),
              itemCount:        _promotions.length,
              separatorBuilder: (_, _) => SizedBox(width: w * 0.03),
              itemBuilder: (_, i) => _buildRecCard(_promotions[i], w, h),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: hPad * 0.5),
            child: _scrollBtn(false, _promosScrollCtrl),
          ),
        ],
      ),
    );
  }

  Widget _buildRecsEmptyState(double w, double h, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, h * 0.02),
      child: Container(
        height: (h * 0.12).clamp(70.0, 100.0),
        decoration: BoxDecoration(
          color:        _isDark ? const Color(0xFF1E1E1E) : const Color(0x1AC6B3FF),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: const Color(0x33C6B3FF), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_outlined,
                color: Color(0xFFC6B3FF), size: 22),
            const SizedBox(width: 10),
            Text(
              'Start shopping to get recommendations',
              style: TextStyle(
                color:    _isDark ? Colors.white54 : const Color(0xFF8A8A9A),
                fontSize: (w * 0.033).clamp(12.0, 15.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsRow(double w, double h, double hPad) {
    final cardH = (h * 0.22).clamp(150.0, 210.0);

    if (_recsLoading) {
      return SizedBox(
        height: cardH,
        child: ListView.separated(
          primary:         false,
          scrollDirection: Axis.horizontal,
          physics:         const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, h * 0.012),
          itemCount:       4,
          separatorBuilder: (_, _) => SizedBox(width: w * 0.03),
          itemBuilder: (_, _) => _buildRecSkeletonCard(w, h),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, h * 0.02),
        child: Container(
          height: cardH * 0.55,
          decoration: BoxDecoration(
            color:        _isDark
                ? const Color(0xFF1E1E1E)
                : const Color(0x1AC6B3FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x33C6B3FF), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_outlined,
                  color: Color(0xFFC6B3FF), size: 22),
              const SizedBox(width: 10),
              Text(
                'Start shopping to get recommendations',
                style: TextStyle(
                  color:    _isDark
                      ? Colors.white54
                      : const Color(0xFF8A8A9A),
                  fontSize: (w * 0.033).clamp(12.0, 15.0),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: cardH,
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: hPad * 0.5),
            child: _scrollBtn(true, _recsScrollCtrl),
          ),
          Expanded(
            child: ListView.separated(
              controller:       _recsScrollCtrl,
              primary:          false,
              scrollDirection:  Axis.horizontal,
              physics:          const BouncingScrollPhysics(),
              padding:          EdgeInsets.fromLTRB(8, 0, 8, h * 0.015),
              itemCount:        _recommendations.length,
              separatorBuilder: (_, _) => SizedBox(width: w * 0.03),
              itemBuilder: (_, i) =>
                  _buildRecCard(_recommendations[i], w, h),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: hPad * 0.5),
            child: _scrollBtn(false, _recsScrollCtrl),
          ),
        ],
      ),
    );
  }

  Widget _buildRecCard(dynamic p, double w, double h) {
    final cat         = p['category']    as String? ?? '';
    final bgColor     = _cardColor(cat);
    final iconData    = _cardIcon(cat);
    final id          = p['_id']         as String? ?? '';
    final name        = p['name']        as String? ?? '';
    final brand       = p['brand']       as String? ?? '';
    final desc        = p['description'] as String? ?? '';
    final price       = (p['price']      as num?)?.toInt() ?? 0;
    final unit        = p['unit']        as String? ?? '';
    final imageUrl    = p['imageUrl']    as String? ?? '';
    final aisle       = p['aisle']       as String? ?? '';
    final expiry      = p['expiry']      as String? ?? '';
    final allergens      = _matchedAllergens(p);
    final healthMessages = _healthMessages(p);
    final warnAllergy    = allergens.isNotEmpty;
    final warnHealth     = healthMessages.isNotEmpty;

    return ListenableBuilder(
      listenable: _favorites,
      builder: (_, _) {
        final isFav = _favorites.contains(id);
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                product: {
                  ...Map<String, dynamic>.from(p as Map),
                  'warning_allergy':   warnAllergy,
                  'warning_health':    warnHealth,
                  'matched_allergens': allergens,
                  'health_reasons':    healthMessages,
                },
              ),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: w * 0.42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: isFav ? Colors.red : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Full image background
                  _productImage(imageUrl, bgColor, iconData, w),

                  // Dark gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin:  Alignment.topCenter,
                          end:    Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.62),
                          ],
                          stops: const [0.38, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Heart button top-right
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => _favorites.toggle(FavoriteItem(
                        asset:       id,
                        name:        name,
                        price:       price,
                        category:    cat,
                        brand:       brand,
                        description: desc,
                      )),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: isFav
                                  ? Colors.red.withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFav ? Colors.red : Colors.white,
                              size:  15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Warning badges top-left
                  if (warnAllergy || warnHealth)
                    Positioned(
                      top: 8, left: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (warnAllergy)
                            _warningBadge(
                              icon:  Icons.warning_amber_rounded,
                              label: allergens.join(', '),
                              color: const Color(0xFFFFC107),
                            ),
                          if (warnAllergy && warnHealth)
                            const SizedBox(height: 4),
                          if (warnHealth)
                            _warningBadge(
                              icon:  Icons.health_and_safety_rounded,
                              label: healthMessages.first,
                              color: const Color(0xFFFF5252),
                            ),
                        ],
                      ),
                    ),

                  // Glass info bar bottom
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize:       MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color:      Colors.white,
                                        fontSize:   19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (unit.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        '/ $unit',
                                        style: TextStyle(
                                          fontSize:   12,
                                          color:      Colors.white.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (aisle.isNotEmpty || expiry.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (aisle.isNotEmpty)
                                      _infoBadge(Icons.store_mall_directory_outlined,
                                          'Aisle $aisle'),
                                    if (aisle.isNotEmpty && expiry.isNotEmpty)
                                      const SizedBox(width: 4),
                                    if (expiry.isNotEmpty)
                                      _infoBadge(Icons.event_outlined, expiry),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '$price DA',
                                style: const TextStyle(
                                  color:      Color(0xFFD6F36A),
                                  fontSize:   17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
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
      },
    );
  }

  Widget _buildRecSkeletonCard(double w, double h) {
    final skeletonBg   = _isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final skeletonFill = _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    return Container(
      width: w * 0.38,
      decoration: BoxDecoration(
        color:        skeletonBg,
        borderRadius: BorderRadius.circular(36),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(36)),
              child: Container(color: skeletonFill),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                      height: 10, width: double.infinity,
                      decoration: BoxDecoration(
                          color:        skeletonFill,
                          borderRadius: BorderRadius.circular(5))),
                  Container(
                      height: 9, width: 60,
                      decoration: BoxDecoration(
                          color:        skeletonFill,
                          borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      IconData icon, String title, double hPad, double w, double h) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, h * 0.022, hPad, h * 0.012),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _shineAnim,
            builder: (_, _) => Icon(icon, size: 22, color: _shineAnim.value),
          ),
          SizedBox(width: w * 0.02),
          Text(
            title,
            style: TextStyle(
              fontSize:   (w * 0.065).clamp(22.0, 30.0),
              fontWeight: FontWeight.w700,
              color:      _isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSkeleton() {
    final bg   = _isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fill = _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    return Container(
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(36),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(36)),
              child: Container(color: fill),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                      height: 10, width: double.infinity,
                      decoration: BoxDecoration(
                          color:        fill,
                          borderRadius: BorderRadius.circular(5))),
                  Container(
                      height: 9, width: 50,
                      decoration: BoxDecoration(
                          color:        fill,
                          borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollBtn(bool toLeft, ScrollController ctrl) {
    return GestureDetector(
      onTap: () {
        if (!ctrl.hasClients) return;
        final delta = toLeft ? -200.0 : 200.0;
        ctrl.animateTo(
          (ctrl.offset + delta).clamp(0.0, ctrl.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOut,
        );
      },
      child: Container(
        width:  30,
        height: 30,
        decoration: BoxDecoration(
          color:  const Color(0x1AC6B3FF),
          shape:  BoxShape.circle,
          border: Border.all(
              color: const Color(0x33C6B3FF), width: 1),
        ),
        child: Icon(
          toLeft
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          color: const Color(0xFFC6B3FF),
          size:  20,
        ),
      ),
    );
  }

  Widget _buildCategories(double w, double h, double hPad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            Icons.auto_awesome_rounded, S.categoriesLabel, hPad, w, h),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: hPad * 0.5),
                child: _scrollBtn(true, _catScrollCtrl),
              ),
              Expanded(
                child: ListView.separated(
                  controller:      _catScrollCtrl,
                  primary:         false,
                  scrollDirection: Axis.horizontal,
                  physics:         const BouncingScrollPhysics(),
                  padding:         const EdgeInsets.symmetric(horizontal: 8),
                  itemCount:       _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final cat      = _categories[i];
                    final isSelected = _selectedCategory == cat.name;
                    return GestureDetector(
                      onTap: () => _onCategoryTap(cat.name),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0D1B2A)
                                  : const Color(0x33C6B3FF),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : const Color(0x1AC6B3FF),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat.icon,
                                    size:  20,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black),
                                const SizedBox(width: 8),
                                Text(
                                  S.categoryName(cat.name),
                                  style: TextStyle(
                                    fontSize:   (w * 0.040).clamp(13.0, 17.0),
                                    fontWeight: FontWeight.w600,
                                    color:      isSelected
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: hPad * 0.5),
                child: _scrollBtn(false, _catScrollCtrl),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavBar(double navPad, double navH, double navIconSz) {
    final navItems = [
      _NavItem(Icons.home_rounded,          Icons.home_outlined,           S.navHome),
      _NavItem(Icons.shopping_bag_rounded,  Icons.shopping_bag_outlined,   S.navCart),
      _NavItem(Icons.search_rounded,        Icons.search_rounded,          S.navSearch),
      _NavItem(Icons.receipt_long_rounded,  Icons.receipt_long_outlined,   S.navOrders),
      _NavItem(Icons.favorite_rounded,      Icons.favorite_border_rounded, 'Favoris'),
      _NavItem(Icons.person_rounded,        Icons.person_outline_rounded,  S.navProfile),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(navPad, navPad * 0.5, navPad, navPad),
        child: Container(
          height: (navH * 0.95).clamp(62.0, 80.0),
          decoration: BoxDecoration(
            color:        const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.28),
                blurRadius: 20,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _cart,
            builder: (_, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (i) {
                final item  = navItems[i];
                final isSel = _currentIndex == i;
                final badge = i == 1 ? _cart.totalCount : 0;
                return _buildNavTile(
                  activeIcon:   item.activeIcon,
                  inactiveIcon: item.inactiveIcon,
                  label:        item.label,
                  index:        i,
                  isSelected:   isSel,
                  iconSz:       navIconSz,
                  badge:        badge,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String   label,
    required int      index,
    required bool     isSelected,
    required double   iconSz,
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:        isSelected
              ? const Color(0xFFD6F36A)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  size:  iconSz.clamp(20.0, 24.0),
                  color: isSelected ? Colors.black : Colors.white70,
                ),
                if (badge > 0)
                  Positioned(
                    top: -5, right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4D4D),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            // Label: always present for consistent height, visible only when selected
            AnimatedOpacity(
              opacity:  isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                label,
                style: TextStyle(
                  color:      isSelected ? Colors.black : Colors.transparent,
                  fontSize:   8,
                  fontWeight: FontWeight.w800,
                  height:     1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:  const Color(0x33C6B3FF),
              shape:  BoxShape.circle,
              border: Border.all(
                  color: const Color(0x1AC6B3FF), width: 1),
            ),
            child: Icon(icon, size: 22, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────────────────

class _Category {
  final String   name;
  final IconData icon;
  const _Category(this.name, this.icon);
}

class _NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String   label;
  const _NavItem(this.activeIcon, this.inactiveIcon, this.label);
}

// ── Floating background icons — optimized: 1 controller instead of 20 ─────────

class _FloatingIconsBg extends StatefulWidget {
  const _FloatingIconsBg();
  @override
  State<_FloatingIconsBg> createState() => _FloatingIconsBgState();
}

class _FloatingIconsBgState extends State<_FloatingIconsBg>
    with SingleTickerProviderStateMixin {

  static const _icons = [
    Icons.local_grocery_store_rounded,
    Icons.local_pizza_rounded,
    Icons.coffee_rounded,
    Icons.set_meal_rounded,
    Icons.cake_rounded,
    Icons.local_drink_rounded,
    Icons.shopping_basket_rounded,
    Icons.lunch_dining_rounded,
    Icons.spa_rounded,
    Icons.devices_rounded,
  ];

  static const _colorA = Color(0xFFC6B3FF);
  static const _colorB = Color(0xFFE6F494);

  late final AnimationController _masterCtrl;
  late final List<double> _left;
  late final List<double> _startY;
  late final List<double> _size;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _left   = List.generate(_icons.length, (_) => 0.04 + rng.nextDouble() * 0.84);
    _startY = List.generate(_icons.length, (_) => 0.45 + rng.nextDouble() * 0.50);
    _size   = List.generate(_icons.length, (_) => 36 + rng.nextDouble() * 18);

    // Single controller drives all icons via staggered offsets — replaces 20 controllers
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _masterCtrl,
      builder: (context, _) {
        final w = MediaQuery.of(context).size.width;
        final h = MediaQuery.of(context).size.height;

        return Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: List.generate(_icons.length, (i) {
                final color = i.isOdd ? _colorA : _colorB;
                final sz    = _size[i];
                final icon  = _icons[i];

                // Stagger float progress per icon using fractional offset
                final t = (_masterCtrl.value + i / _icons.length) % 1.0;
                // Stagger spin using a slower rate + per-icon offset
                final spin =
                    ((_masterCtrl.value * 0.42) + i * 0.09) % 1.0 * 2 * pi;

                final y = _startY[i] * h * (1 - t) - sz * t;

                final double opacity = t < 0.10
                    ? (t / 0.10) * 0.22
                    : t < 0.78
                        ? 0.22
                        : 0.22 * (1.0 - (t - 0.78) / 0.22);

                final popScale =
                    t > 0.82 ? 1.0 + (t - 0.82) / 0.18 * 0.65 : 1.0;

                final matrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(spin);

                return Positioned(
                  left: _left[i] * w,
                  top:  y,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: popScale,
                      child: Transform(
                        transform: matrix,
                        alignment: Alignment.center,
                        child: Container(
                          width:  sz,
                          height: sz,
                          decoration: BoxDecoration(
                            color:        color,
                            borderRadius: BorderRadius.circular(sz * 0.28),
                            boxShadow: [
                              BoxShadow(
                                color:      color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset:     const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon,
                              size:  sz * 0.54,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
