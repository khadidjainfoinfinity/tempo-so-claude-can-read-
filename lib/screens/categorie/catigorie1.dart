import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'catigorie2.dart';
import '../../l10n/app_strings.dart';
import '../../constants/preferences_data.dart';

class LifestyleSelectionPage extends StatefulWidget {
  final String name;
  const LifestyleSelectionPage({super.key, required this.name});

  @override
  State<LifestyleSelectionPage> createState() =>
      _LifestyleSelectionPageState();
}

class _LifestyleSelectionPageState extends State<LifestyleSelectionPage> {
  final Set<int> selectedIndexes = {};
  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20;
      if (atBottom && _showScrollHint) {
        setState(() => _showScrollHint = false);
      } else if (!atBottom && !_showScrollHint) {
        setState(() => _showScrollHint = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> lifestyles = kLifestyleCards;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final double horizontalPadding = width > 900
        ? width * 0.04
        : width > 600
            ? width * 0.03
            : 12.0;

    final double titleFontSize = width > 600 ? 26.0 : 20.0;
    final double subtitleFontSize = width > 600 ? 15.0 : 13.0;
    final double btnFont = (width * 0.044).clamp(14.0, 20.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8ED),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // ── Scrollable content ──
                  ScrollbarTheme(
                    data: ScrollbarThemeData(
                      thumbColor: WidgetStateProperty.all(const Color(0xFFBDD837)),
                      thickness: WidgetStateProperty.all(8),
                      minThumbLength: 30,
                      radius: const Radius.circular(8),
                    ),
                    child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(8),
                    child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ── Progress bar + Skip ──
                        Row(
                          children: [
                            Expanded(
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: 1 / 3,
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFBDD837),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: 1 / 3,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: 2 / 3,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AllergiesSelectionPage(name: widget.name),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  S.skip,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Title ──
                        Text(
                          S.lifestyleDietTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Subtitle ──
                        Text(
                          S.lifestyleDietSub,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Grid ──
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lifestyles.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.9,
                          ),
                          itemBuilder: (context, index) {
                            final item = lifestyles[index];
                            final isSelected = selectedIndexes.contains(index);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedIndexes.remove(index);
                                  } else {
                                    selectedIndexes.add(index);
                                  }
                                });
                              },
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFBDD837)
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.07),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          item["image"]!,
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFFBDD837)
                                                  : Colors.white.withValues(alpha: 0.85),
                                            ),
                                            child: Text(
                                              item["title"]!,
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: btnFont,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black87,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
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

                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                  ),
                  ),

                ],
              ),
            ),

            // ── Continue Button ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 8, horizontalPadding, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final selected = selectedIndexes
                        .map((i) => lifestyles[i]['title']!)
                        .toList();
                    await const FlutterSecureStorage().write(
                      key: 'user_lifestyles',
                      value: jsonEncode(selected),
                    );
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AllergiesSelectionPage(name: widget.name),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC6B3FF),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    S.continueBtn,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: btnFont,
                      letterSpacing: 2,
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
}
