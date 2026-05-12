import 'package:flutter/material.dart';

// ── Lifestyles ─────────────────────────────────────────────────────────────────
// Complete list used in both onboarding chip selector and profile chip selector.
const List<String> kLifestyles = [
  'Vegan',
  'Vegetarian',
  'Pescatarian',
  'Keto',
  'Low-Carb',
  'Paleo',
  'Diabetic',
  'High Protein',
  'Organic',
  'Halal',
  'Kosher',
  'Low Sugar',
  'Low Sodium',
  'Gluten-Free',
];

// Subset with local image assets — used only in the onboarding image-card grid.
const List<Map<String, String>> kLifestyleCards = [
  {"title": "Vegan",        "image": "images/VEGAN.jpeg"},
  {"title": "Vegetarian",   "image": "images/vegetarien.jpeg"},
  {"title": "Pescatarian",  "image": "images/pescatarian.jpeg"},
  {"title": "Keto",         "image": "images/keto.jpeg"},
  {"title": "Low-Carb",     "image": "images/lowcarb.jpeg"},
  {"title": "Paleo",        "image": "images/paleo.jpeg"},
  {"title": "Diabetic",     "image": "images/diabetic.jpeg"},
  {"title": "High Protein", "image": "images/protein.jpeg"},
];

// ── Allergies ──────────────────────────────────────────────────────────────────
const List<String> kAllergies = [
  'None',
  'Tree Nuts',
  'Peanuts',
  'Gluten',
  'Dairy',
  'Seafood',
  'Soy',
  'Eggs',
  'Celery',
  'Lupin',
  'Sesame',
  'Sulfites',
  'Mustard',
  'Molluscs',
];

// ── Shopping Categories ────────────────────────────────────────────────────────
const List<Map<String, dynamic>> kCategories = [
  {"title": "Home Supplies",      "icon": Icons.home_outlined},
  {"title": "Electronics",        "icon": Icons.devices_outlined},
  {"title": "School Supplies",    "icon": Icons.school_outlined},
  {"title": "Groceries",          "icon": Icons.local_grocery_store_outlined},
  {"title": "Furniture",          "icon": Icons.chair_outlined},
  {"title": "Gym",                "icon": Icons.fitness_center_outlined},
  {"title": "Outside Activities", "icon": Icons.park_outlined},
  {"title": "Makeup",             "icon": Icons.face_outlined},
  {"title": "Skincare",           "icon": Icons.spa_outlined},
  {"title": "Technology",         "icon": Icons.computer_outlined},
  {"title": "Gaming",             "icon": Icons.sports_esports_outlined},
  {"title": "Sports",             "icon": Icons.sports_basketball_outlined},
  {"title": "Haircare",           "icon": Icons.content_cut_outlined},
  {"title": "Jewelry",            "icon": Icons.diamond_outlined},
  {"title": "Clothes",            "icon": Icons.checkroom_outlined},
  {"title": "Books",              "icon": Icons.menu_book_outlined},
  {"title": "Pets",               "icon": Icons.pets_outlined},
];

List<String> get kCategoryTitles =>
    kCategories.map((c) => c['title'] as String).toList();

IconData categoryIcon(String title) {
  for (final c in kCategories) {
    if (c['title'] == title) return c['icon'] as IconData;
  }
  return Icons.shopping_bag_outlined;
}
