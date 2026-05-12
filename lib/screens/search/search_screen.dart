import 'dart:async';
import 'dart:math' show pi, Random;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';
import '../../services/favorites_service.dart';
import '../../l10n/app_strings.dart';
import '../home/product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _searchCtrl  = TextEditingController();
  final _favorites   = FavoritesService.instance;
  final _storage     = const FlutterSecureStorage();
  final _catScrollCtrl = ScrollController();

  late final AnimationController _shineCtrl;
  late final Animation<Color?>    _shineAnim;

  Timer?        _debounce;

  String?       _token;
  String        _selectedCategory = 'All';
  String        _sortBy           = 'name';
  List<dynamic> _products         = [];
  bool          _loading          = false;
  String?       _error;
  bool          _isDark           = false;

  // User profile for client-side warning computation
  Set<String>   _userAllergies  = {};
  Set<String>   _userLifestyles = {}; // already normalize_tag'd

  // ── Same food categories as backend safety.py ─────────────────────────────
  static const _foodCategories = {
    'groceries', 'beverages', 'dairy', 'meat', 'bakery',
  };

  // ── Same rule table as backend safety.py LIFESTYLE_RULES ──────────────────
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

  // Human-readable labels for lifestyle keys
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

  static const _bg   = Color(0xFFF5F0E8);
  static const _navy = Color(0xFF0D1B2A);
  static const _lime = Color(0xFFD6F36A);

  static const List<_Cat> _categories = [
    _Cat('All',         Icons.grid_view_rounded),
    _Cat('Groceries',   Icons.local_grocery_store_outlined),
    _Cat('Dairy',       Icons.egg_outlined),
    _Cat('Bakery',      Icons.breakfast_dining_outlined),
    _Cat('Beverages',   Icons.local_drink_outlined),
    _Cat('Meat',        Icons.set_meal_outlined),
    _Cat('Beauty',      Icons.spa_outlined),
    _Cat('Electronics', Icons.devices_outlined),
    _Cat('Clothing',    Icons.checkroom_outlined),
    _Cat('Sports',      Icons.sports_soccer_outlined),
    _Cat('Home',        Icons.home_outlined),
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
    _loadToken();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _shineCtrl.dispose();
    _searchCtrl.dispose();
    _catScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    _token = await _storage.read(key: 'jwt_token');
    if (_token != null) {
      final res = await _authService.getProfile(_token!);
      if (res['statusCode'] == 200) {
        final user = res['body']['user'] as Map<String, dynamic>? ?? {};
        final allergies  = (user['allergies']  as List?)?.map((e) => e.toString().toLowerCase().trim()).toSet() ?? {};
        final lifestyles = (user['lifestyles'] as List?)
            ?.map((e) => _normalizeTag(e.toString()))
            .where((t) => t.isNotEmpty && t != 'none')
            .toSet() ?? {};
        if (mounted) setState(() { _userAllergies = allergies; _userLifestyles = lifestyles; });
      }
    }
  }

  Future<void> _search() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _authService.getProducts(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        search:   _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['statusCode'] == 200) {
        var list = List<dynamic>.from((res['body']['products'] as List?) ?? []);
        list = _sort(list);
        setState(() { _products = list; _loading = false; });
      } else {
        setState(() {
          _error   = res['body']['message'] ?? 'Failed to load products';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  List<dynamic> _sort(List<dynamic> list) {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      final starts = list.where((p) =>
          (p['name'] as String? ?? '').toLowerCase().startsWith(query)).toList();
      final rest = list.where((p) =>
          !(p['name'] as String? ?? '').toLowerCase().startsWith(query)).toList();
      _sortGroup(starts);
      _sortGroup(rest);
      return [...starts, ...rest];
    }
    _sortGroup(list);
    return list;
  }

  void _sortGroup(List<dynamic> list) {
    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) =>
            ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0));
      case 'price_desc':
        list.sort((a, b) =>
            ((b['price'] as num?) ?? 0).compareTo((a['price'] as num?) ?? 0));
      default:
        list.sort((a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
    }
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(S.sortBy,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: _isDark ? Colors.white : _navy)),
            ),
            ...[
              ('name',       S.sortName,      Icons.sort_by_alpha_rounded),
              ('price_asc',  S.sortPriceAsc,  Icons.trending_up_rounded),
              ('price_desc', S.sortPriceDesc, Icons.trending_down_rounded),
            ].map((t) {
              final selected = _sortBy == t.$1;
              return ListTile(
                leading: Icon(t.$3,
                    color: selected ? _navy : Colors.grey, size: 20),
                title: Text(t.$2,
                    style: TextStyle(
                        color: selected
                            ? (_isDark ? Colors.white : _navy)
                            : Colors.black87,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal)),
                trailing: selected
                    ? Icon(Icons.check_rounded,
                        color: _isDark ? _lime : _navy, size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _sortBy = t.$1);
                  _search();
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _cardColor(String? category) =>
      _catColors[category ?? ''] ?? const Color(0xFFE8E8E8);

  IconData _cardIcon(String? category) =>
      _catIcons[category ?? ''] ?? Icons.inventory_2_outlined;

  // ── Helpers mirroring backend safety.py logic ─────────────────────────────

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

  /// Normalized set of a product's structured keywords list.
  static Set<String> _productKeywords(dynamic p) {
    final raw = p['keywords'];
    if (raw is! List) return {};
    return raw.map((e) => e.toString().toLowerCase().trim()).toSet();
  }

  /// Returns the list of allergens in the product that match the user's allergies.
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

  /// Returns full health warning messages for each lifestyle conflict, e.g.:
  /// "This product contains: sugar — against your diabetic lifestyle"
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

      // Match via free-text substring
      final matchedText = ruleKw.where((k) => text.contains(k)).toList();
      // Match via product.keywords list (exact, case-insensitive)
      final matchedKw   = ruleKw.where((k) => kwSet.contains(k)).toList();

      final matched = {...matchedText, ...matchedKw}.toList();
      if (matched.isEmpty) continue;

      final label = _lifestyleLabels[lifestyle] ??
          lifestyle.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ');
      messages.add('This product contains: ${matched.join(', ')} — against your $label lifestyle');
    }
    return messages;
  }

  Widget _warningBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.82),
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
                  color: Colors.white,
                  fontSize: 10,
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
      child: Center(child: Icon(icon, size: (w * 0.1).clamp(32.0, 52.0), color: Colors.black26)),
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
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 9),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final hPad = (w * 0.045).clamp(14.0, 24.0);

    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF121212) : _bg,
      body: Stack(
        children: [
          const _FloatingIconsBg(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ─────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, h * 0.025, hPad, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.search,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: (w * 0.055).clamp(18.0, 28.0),
                              color: _isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                            ),
                          ),
                          Text(
                            S.searchSubtitle,
                            style: TextStyle(
                              fontSize: (w * 0.032).clamp(11.0, 15.0),
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      // Sort button
                      GestureDetector(
                        onTap: _showSortSheet,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isDark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: _isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                border: Border.all(
                                  color: _sortBy != 'name'
                                      ? _lime
                                      : (_isDark
                                          ? Colors.white12
                                          : Colors.black
                                              .withValues(alpha: 0.07)),
                                  width: _sortBy != 'name' ? 1.8 : 1,
                                ),
                              ),
                              child: Icon(Icons.tune_rounded,
                                  size: 20,
                                  color: _isDark
                                      ? Colors.white
                                      : _navy),
                            ),
                            if (_sortBy != 'name')
                              Positioned(
                                top: 2, right: 2,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: _lime,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Search bar ─────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, h * 0.018, hPad, 0),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                      border: Border.all(
                        color: _searchCtrl.text.isNotEmpty
                            ? _lime
                            : (_isDark
                                ? Colors.white12
                                : Colors.black.withValues(alpha: 0.07)),
                        width: _searchCtrl.text.isNotEmpty ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(Icons.search_rounded,
                            size: 20,
                            color: _searchCtrl.text.isNotEmpty
                                ? _navy
                                : Colors.grey[400]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onSubmitted: (_) {
                              _debounce?.cancel();
                              _search();
                            },
                            onChanged: (v) {
                              setState(() {});
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 380),
                                _search,
                              );
                            },
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                            ),
                            decoration: InputDecoration(
                              hintText: S.searchHint,
                              hintStyle: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _debounce?.cancel();
                              _search();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: Colors.grey[500], size: 14),
                            ),
                          )
                        else
                          const SizedBox(width: 14),
                      ],
                    ),
                  ),
                ),

                // ── Category chips ─────────────────────────────────
                Padding(
                  padding: EdgeInsets.only(top: h * 0.016),
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      controller: _catScrollCtrl,
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat        = _categories[i];
                        final isSelected = _selectedCategory == cat.name;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat.name);
                            _search();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _lime
                                  : (_isDark
                                      ? const Color(0xFF2A2A2A)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? _lime
                                    : (_isDark
                                        ? Colors.white12
                                        : Colors.black.withValues(alpha: 0.08)),
                                width: 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: _lime.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat.icon,
                                    size: 16,
                                    color: isSelected
                                        ? _navy
                                        : Colors.grey[500]),
                                const SizedBox(width: 6),
                                Text(
                                  S.categoryName(cat.name),
                                  style: TextStyle(
                                    fontSize: (w * 0.033).clamp(12.0, 15.0),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? _navy
                                        : (_isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Results strip ───────────────────────────────────
                if (!_loading && _error == null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, h * 0.014, hPad, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _products.isEmpty
                                ? S.noResults
                                : S.productsFound(_products.length),
                            style: TextStyle(
                              fontSize: (w * 0.042).clamp(14.0, 20.0),
                              fontWeight: FontWeight.w700,
                              color: _isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _lime,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_rounded,
                                    size: 12, color: _navy),
                                const SizedBox(width: 4),
                                Text(
                                  '"${_searchCtrl.text}"',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // ── Product grid ───────────────────────────────────
                Expanded(
                  child: _loading
                      ? _buildSkeletonGrid(w, h, hPad)
                      : _error != null
                          ? _buildError()
                          : _products.isEmpty
                              ? _buildEmpty()
                              : GridView.builder(
                                  physics:
                                      const BouncingScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                      hPad, 0, hPad, h * 0.02),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: w > 900 ? 4 : 2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 163 / 232,
                                  ),
                                  itemCount: _products.length,
                                  itemBuilder: (_, i) =>
                                      _buildCard(_products[i], w, h),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic p, double w, double h) {
    final cat           = p['category'] as String? ?? '';
    final bgColor       = _cardColor(cat);
    final iconData      = _cardIcon(cat);
    final id            = p['_id']       as String? ?? '';
    final name          = p['name']      as String? ?? '';
    final brand         = p['brand']     as String? ?? '';
    final desc          = p['description'] as String? ?? '';
    final price         = (p['price']    as num?)?.toInt() ?? 0;
    final unit          = p['unit']      as String? ?? '';
    final imageUrl      = p['imageUrl']  as String? ?? '';
    final aisle         = p['aisle']     as String? ?? '';
    final expiry        = p['expiry']    as String? ?? '';
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
                  // ── Full image background ────────────────────────
                  _productImage(imageUrl, bgColor, iconData, w),

                  // ── Dark gradient ────────────────────────────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.62),
                          ],
                          stops: const [0.38, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ── Heart button top-right ───────────────────────
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => _favorites.toggle(FavoriteItem(
                        asset: id, name: name, price: price,
                        category: cat, brand: brand, description: desc,
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
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Warning badges top-left ──────────────────────
                  if (warnAllergy || warnHealth)
                    Positioned(
                      top: 8, left: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (warnAllergy)
                            _warningBadge(
                              icon: Icons.warning_amber_rounded,
                              label: allergens.join(', '),
                              color: const Color(0xFFFFC107),
                            ),
                          if (warnAllergy && warnHealth)
                            const SizedBox(height: 4),
                          if (warnHealth)
                            _warningBadge(
                              icon: Icons.health_and_safety_rounded,
                              label: healthMessages.first,
                              color: const Color(0xFFFF5252),
                            ),
                        ],
                      ),
                    ),

                  // ── Glass info bar bottom ────────────────────────
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // name + unit
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
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
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // aisle + expiry chips
                              if (aisle.isNotEmpty || expiry.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (aisle.isNotEmpty)
                                      _infoBadge(Icons.store_mall_directory_outlined, 'Aisle $aisle'),
                                    if (aisle.isNotEmpty && expiry.isNotEmpty)
                                      const SizedBox(width: 4),
                                    if (expiry.isNotEmpty)
                                      _infoBadge(Icons.event_outlined, expiry),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              // price
                              Text(
                                '$price DA',
                                style: const TextStyle(
                                  color: _lime,
                                  fontSize: 17,
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

  Widget _buildSkeletonGrid(double w, double h, double hPad) {
    final bg   = _isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fill = _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, h * 0.02),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: w > 900 ? 4 : 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 163 / 232,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: bg,
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(5))),
                    Container(
                        height: 9,
                        width: 50,
                        decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(5))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0x33C6B3FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0x1AC6B3FF), width: 1),
                ),
                child: const Icon(Icons.search_off_rounded,
                    size: 48, color: _navy),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(S.noProductsFound,
              style: const TextStyle(
                  color: _navy, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(S.tryDifferent,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(_error!,
              style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _search,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x33C6B3FF),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: const Color(0x1AC6B3FF), width: 1),
                  ),
                  child: Text(S.retry,
                      style: const TextStyle(
                          color: _navy, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cat {
  final String   name;
  final IconData icon;
  const _Cat(this.name, this.icon);
}

// ── Floating background icons ────────────────────────────────────────────────

class _FloatingIconsBg extends StatefulWidget {
  const _FloatingIconsBg();
  @override
  State<_FloatingIconsBg> createState() => _FloatingIconsBgState();
}

class _FloatingIconsBgState extends State<_FloatingIconsBg>
    with TickerProviderStateMixin {
  static const _icons = [
    Icons.search_rounded,
    Icons.local_grocery_store_rounded,
    Icons.devices_rounded,
    Icons.spa_rounded,
    Icons.coffee_rounded,
    Icons.checkroom_rounded,
    Icons.sports_soccer_rounded,
    Icons.home_rounded,
    Icons.cake_rounded,
    Icons.local_drink_rounded,
  ];

  static const _colorA = Color(0xFFC6B3FF);
  static const _colorB = Color(0xFFE6F494);

  late final List<AnimationController> _floatCtrls;
  late final List<AnimationController> _spinCtrls;
  late final List<double> _left;
  late final List<double> _startY;
  late final List<double> _size;

  @override
  void initState() {
    super.initState();
    final rng = Random(99);
    _left   = List.generate(_icons.length, (_) => 0.04 + rng.nextDouble() * 0.84);
    _startY = List.generate(_icons.length, (_) => 0.45 + rng.nextDouble() * 0.50);
    _size   = List.generate(_icons.length, (_) => 36 + rng.nextDouble() * 18);

    _floatCtrls = List.generate(_icons.length, (i) =>
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 4200 + i * 350),
        value: (i / _icons.length),
      )..repeat(),
    );

    _spinCtrls = List.generate(_icons.length, (i) =>
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1800 + i * 200),
      )..repeat(),
    );
  }

  @override
  void dispose() {
    for (final c in _floatCtrls) c.dispose();
    for (final c in _spinCtrls)  c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: List.generate(_icons.length, (i) {
            final color = i.isOdd ? _colorA : _colorB;
            final sz    = _size[i];
            final icon  = _icons[i];
            return AnimatedBuilder(
              animation: Listenable.merge([_floatCtrls[i], _spinCtrls[i]]),
              builder: (_, _) {
                final t    = _floatCtrls[i].value;
                final spin = _spinCtrls[i].value * 2 * pi;
                final y    = _startY[i] * h * (1 - t) - sz * t;

                final double opacity = t < 0.10
                    ? (t / 0.10) * 0.22
                    : t < 0.78
                        ? 0.22
                        : 0.22 * (1.0 - (t - 0.78) / 0.22);

                final popScale = t > 0.82
                    ? 1.0 + (t - 0.82) / 0.18 * 0.65
                    : 1.0;

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
                              size: sz * 0.54, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
