import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/favorites_service.dart';
import '../../l10n/app_strings.dart';
import '../home/product_detail_screen.dart';

const _kDark = Color(0xFF0D1B2A);
const _kRed  = Color(0xFFEF4444);
const _kGrey = Color(0xFF9E9E9E);

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w   = MediaQuery.of(context).size.width;
    final h   = MediaQuery.of(context).size.height;
    final fav = FavoritesService.instance;
    final hPad = w * 0.05;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 16),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: _kRed, size: 26),
                const SizedBox(width: 10),
                Text(
                  S.favorites,
                  style: TextStyle(
                    fontFamily:  'Unbounded',
                    fontWeight:  FontWeight.w700,
                    fontSize:    (w * 0.052).clamp(18.0, 24.0),
                    color:       _kDark,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          // ── Grid ────────────────────────────────────────────
          Expanded(
            child: ListenableBuilder(
              listenable: fav,
              builder: (_, _) {
                final items = fav.items;

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border_rounded,
                            size: w * 0.18, color: _kGrey),
                        const SizedBox(height: 14),
                        Text(S.noFavorites,
                            style: TextStyle(
                                fontFamily: 'Unbounded',
                                color: _kGrey,
                                fontSize: (w * 0.038).clamp(13.0, 16.0))),
                        const SizedBox(height: 6),
                        Text(
                          S.noFavoritesHint,
                          style: TextStyle(
                            color: _kGrey.withValues(alpha: 0.7),
                            fontSize: (w * 0.032).clamp(11.0, 14.0),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(hPad, 4, hPad, hPad),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:   2,
                    mainAxisSpacing:  10,
                    crossAxisSpacing: 8,
                    childAspectRatio: ((w - hPad * 2 - 8) / 2) / 232,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _buildCard(items[i], fav, h, ctx),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      FavoriteItem item, FavoritesService fav, double h, BuildContext ctx) {
    final isNetwork = item.asset.startsWith('http');
    final productMap = <String, dynamic>{
      'name':        item.name,
      'price':       item.price,
      'category':    item.category,
      'brand':       item.brand,
      'description': item.description,
      if (isNetwork) 'imageUrl':   item.asset
      else           'localImage': item.asset,
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: productMap),
        ),
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        children: [
          // ── Background image ───────────────────────────────
          Positioned.fill(
            child: item.asset.startsWith('http')
                ? Image.network(item.asset, fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) =>
                        Container(color: const Color(0xFF1E1E1E)))
                : item.asset.endsWith('.svg')
                    ? SvgPicture.asset(item.asset, fit: BoxFit.cover)
                    : Image.asset(item.asset, fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) =>
                            Container(color: const Color(0xFF1E1E1E))),
          ),

          // ── Glass bottom overlay ───────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily:    'Unbounded',
                          fontWeight:    FontWeight.w500,
                          fontSize:      14,
                          color:         Colors.white,
                          letterSpacing: 0.6,
                          height:        1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.price} DA',
                        style: TextStyle(
                          fontFamily:    'Unbounded',
                          fontWeight:    FontWeight.w500,
                          fontSize:      12,
                          color:         Colors.white.withValues(alpha: 0.82),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Red heart button — tap to remove ──────────────
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => fav.remove(item.asset),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width:  34,
                    height: 34,
                    decoration: BoxDecoration(
                      color:  _kRed.withValues(alpha: 0.25),
                      shape:  BoxShape.circle,
                      border: Border.all(
                        color: _kRed.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: _kRed,
                      size:  16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),   // ClipRRect
  );     // GestureDetector
  }
}

