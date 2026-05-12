import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'catigorie3.dart';
import '../../l10n/app_strings.dart';
import '../../constants/preferences_data.dart';

class AllergiesSelectionPage extends StatefulWidget {
  final String name;
  const AllergiesSelectionPage({super.key, required this.name});

  @override
  State<AllergiesSelectionPage> createState() => _AllergiesSelectionPageState();
}

class _AllergiesSelectionPageState extends State<AllergiesSelectionPage>
    with TickerProviderStateMixin {
  final Set<int> selectedIndexes = {};
  int? _pressedIndex;

  late final AnimationController _pageController;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;

  late final AnimationController _chipsController;

  final List<String> allergies = kAllergies;

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pageFade = CurvedAnimation(parent: _pageController, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageController, curve: Curves.easeOut));

    _chipsController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + allergies.length * 60),
    );

    _pageController.forward().then((_) => _chipsController.forward());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chipsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final double horizontalPadding = width > 900
        ? width * 0.04
        : width > 600
            ? width * 0.03
            : 12.0;

    final double titleFontSize = (width * 0.065).clamp(20.0, 32.0);
    final double subtitleFontSize = (width * 0.042).clamp(13.0, 18.0);
    final double btnFont = (width * 0.044).clamp(14.0, 20.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE6),
      body: SafeArea(
        child: FadeTransition(
          opacity: _pageFade,
          child: SlideTransition(
            position: _pageSlide,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Progress bar + Skip
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
                                    widthFactor: 2 / 3,
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD9F99D),
                                        borderRadius: BorderRadius.circular(20),
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ShoppingCategoriesPage(name: widget.name),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
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

                        Center(
                          child: Text(
                            S.allergiesOnboardTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Center(
                          child: Text(
                            S.lifestyleDietSub,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              color: Colors.black54,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Allergy chips avec animation en cascade
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: List.generate(allergies.length, (index) {
                            final start = (index / allergies.length) * 0.6;
                            final end = start + 0.4;
                            final chipAnim = CurvedAnimation(
                              parent: _chipsController,
                              curve: Interval(start, end, curve: Curves.easeOut),
                            );
                            final isSelected = selectedIndexes.contains(index);
                            final isPressed = _pressedIndex == index;
                            return FadeTransition(
                              opacity: chipAnim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.3),
                                  end: Offset.zero,
                                ).animate(chipAnim),
                                child: GestureDetector(
                                  onTapDown: (_) => setState(() => _pressedIndex = index),
                                  onTapUp: (_) => setState(() => _pressedIndex = null),
                                  onTapCancel: () => setState(() => _pressedIndex = null),
                                  onTap: () {
                                    setState(() {
                                      if (selectedIndexes.contains(index)) {
                                        selectedIndexes.remove(index);
                                      } else {
                                        selectedIndexes.add(index);
                                      }
                                    });
                                  },
                                  child: AnimatedScale(
                                    scale: isPressed ? 1.15 : isSelected ? 1.1 : 1.0,
                                    duration: const Duration(milliseconds: 120),
                                    curve: Curves.easeOut,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: width > 600 ? 36 : 22,
                                        vertical: width > 600 ? 22 : 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFC6B3FF)
                                            : const Color(0xFFEDE9FD),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: Text(
                                        allergies[index],
                                        style: TextStyle(
                                          fontSize: btnFont,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Continue Button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 0, horizontalPadding, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        final selected = selectedIndexes
                            .map((i) => allergies[i])
                            .toList();
                        await const FlutterSecureStorage().write(
                          key: 'user_allergies',
                          value: jsonEncode(selected),
                        );
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShoppingCategoriesPage(name: widget.name),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC6B3FF),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(
                        S.continueBtn,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: btnFont,
                          letterSpacing: 1.5,
                        ),
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
  }
}
