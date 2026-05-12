// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';
import '../../l10n/app_strings.dart';
import '../../constants/preferences_data.dart';
import '../login/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage     = const FlutterSecureStorage();
  final _imagePicker = ImagePicker();

  // ── User data ──────────────────────────────────────────────────
  String  _name      = '';
  String  _email     = '';
  String  _phone     = '';
  String? _imagePath;

  // ── Preferences ────────────────────────────────────────────────
  List<String> _lifestyles         = [];
  List<String> _allergies          = [];
  List<String> _shoppingCategories = [];

  // ── Password ───────────────────────────────────────────────────
  bool _showPwd          = false;
  bool _isChangingPwd    = false;
  bool _obscureCurrent   = true;
  bool _obscureNew       = true;
  bool _obscureConfirm   = true;

  // ── Delete account loading state ───────────────────────────────
  bool _isDeletingAccount = false;

  final _pwdFormKey     = GlobalKey<FormState>();
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl     = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  // ── Palette ────────────────────────────────────────────────────
  static const _bg          = Color(0xFFF5F0E8);
  static const _navy        = Color(0xFF0D1B2A);
  static const _lime        = Color(0xFFD6F36A);
  static const _purple      = Color(0xFFC6B3FF);
  static const _lightPurple = Color(0xFFE8DFFF);
  static const _purpleText  = Color(0xFF9B7FE8);

  static const _localeOptions = [Locale('en'), Locale('fr'), Locale('ar')];

  static final _categoryOptions  = kCategoryTitles;
  static const _allergyOptions   = kAllergies;
  static const _lifestyleOptions = kLifestyles;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final name         = await _storage.read(key: 'user_name')                ?? '';
      final email        = await _storage.read(key: 'user_email')               ?? '';
      final phone        = await _storage.read(key: 'user_phone')               ?? '';
      final imagePath    = await _storage.read(key: 'user_profile_image');
      final lifestyleRaw = await _storage.read(key: 'user_lifestyles');
      final allergiesRaw = await _storage.read(key: 'user_allergies');
      final shoppingRaw  = await _storage.read(key: 'user_shopping_categories');
      if (!mounted) return;
      setState(() {
        _name      = name;
        _email     = email;
        _phone     = phone;
        _imagePath = (imagePath != null && File(imagePath).existsSync())
            ? imagePath : null;
        _lifestyles = lifestyleRaw != null
            ? List<String>.from(jsonDecode(lifestyleRaw)) : [];
        _allergies = allergiesRaw != null
            ? List<String>.from(jsonDecode(allergiesRaw)) : [];
        _shoppingCategories = shoppingRaw != null
            ? List<String>.from(jsonDecode(shoppingRaw)) : [];
      });
    } catch (_) {}
  }

  Future<void> _saveField(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<void> _saveList(String key, List<String> list) async {
    await _storage.write(key: key, value: jsonEncode(list));
  }

  Future<void> _syncProfileField({
    String? name,
    String? email,
    String? numberPhone,
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      final res = await AuthService().updateProfile(
        token:       token,
        name:        name,
        email:       email,
        numberPhone: numberPhone,
      );
      if (!mounted) return;
      if (res['statusCode'] != 200) {
        _snack(res['body']['message'] ?? S.error, Colors.red);
      } else {
        _snack(S.profileUpdated, Colors.green);
      }
    } catch (_) {}
  }

  Future<void> _syncPreferences(
    List<String> lifestyles,
    List<String> allergies,
    List<String> shoppingCategories,
  ) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      final res = await AuthService().updatePreferences(
        token:              token,
        lifestyles:         lifestyles,
        allergies:          allergies,
        shoppingCategories: shoppingCategories,
      );
      if (!mounted) return;
      if (res['statusCode'] != 200) {
        _snack(res['body']['message'] ?? S.error, Colors.red);
      } else {
        _snack(S.preferencesUpdated, Colors.green);
      }
    } catch (_) {}
  }

  // ── Edit dialog ────────────────────────────────────────────────
  void _showEditDialog({
    required String title,
    required String initialValue,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required Future<void> Function(String) onSave,
  }) {
    final ctrl = TextEditingController(text: initialValue);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, size: 20, color: _purpleText),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller:  ctrl,
          autofocus:   true,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText:   hint,
            filled:     true,
            fillColor:  _lightPurple,
            border:     OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: _purple, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel, style: const TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await onSave(ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              elevation:       0,
              shape:           RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(S.save,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Chip selector dialog (centered) ───────────────────────────
  void _showChipSelector({
    required String title,
    required List<String> options,
    required List<String> selected,
    required Future<void> Function(List<String>) onSave,
    String Function(String)? displayLabel,
    IconData Function(String)? icon,
  }) {
    final temp    = List<String>.from(selected);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final maxH    = MediaQuery.of(context).size.height * 0.7;

    showDialog<void>(
      context:           context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:    const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Container(
              decoration: BoxDecoration(
                color:        isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  ),
                  const SizedBox(height: 16),
                  // Scrollable chips
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: options.map((opt) {
                          final isSel = temp.contains(opt);
                          return GestureDetector(
                            onTap: () => setS(() {
                              if (isSel) temp.remove(opt);
                              else       temp.add(opt);
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color:        isSel ? _navy : const Color(0xFFF0EDE6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (icon != null) ...[
                                    Icon(icon(opt), size: 14,
                                        color: isSel ? Colors.white : Colors.black87),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(displayLabel != null ? displayLabel(opt) : opt,
                                      style: TextStyle(
                                        color:      isSel ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                        fontSize:   13,
                                      )),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // Save button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await onSave(temp);
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          elevation:       0,
                          shape:           RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(S.save,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Image picker ───────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final picked = await _imagePicker.pickImage(
          source: source, imageQuality: 80, maxWidth: 600);
      if (picked == null) return;
      await _storage.write(key: 'user_profile_image', value: picked.path);
      if (!mounted) return;
      setState(() => _imagePath = picked.path);
    } catch (_) {}
  }

  void _showPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E) : _bg,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(S.profilePhoto,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pickerOpt(Icons.camera_alt_outlined, S.camera, _purple,
                    () => _pickImage(ImageSource.camera)),
                _pickerOpt(Icons.photo_library_outlined, S.gallery, _lime,
                    () => _pickImage(ImageSource.gallery)),
                if (_imagePath != null)
                  _pickerOpt(Icons.delete_outline_rounded, S.remove,
                      const Color(0xFFFFCDD2), () async {
                    Navigator.pop(context);
                    await _storage.delete(key: 'user_profile_image');
                    setState(() => _imagePath = null);
                  }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _pickerOpt(IconData icon, String label, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding:    const EdgeInsets.all(16),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child:      Icon(icon, size: 26, color: _navy),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
        ],
      ),
    );
  }

  // ── Password change ────────────────────────────────────────────
  Future<void> _changePassword() async {
    if (!_pwdFormKey.currentState!.validate()) return;
    setState(() => _isChangingPwd = true);
    try {
      final loginInput = _email.isNotEmpty ? _email : _phone;
      final res = await AuthService().resetPassword(
        loginInput:  loginInput,
        newPassword: _newPwdCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isChangingPwd = false);
      if (res['statusCode'] == 200) {
        _currentPwdCtrl.clear();
        _newPwdCtrl.clear();
        _confirmPwdCtrl.clear();
        setState(() => _showPwd = false);
        _snack(S.passwordUpdated, Colors.green);
      } else {
        _snack(res['body']['message'] ?? S.failedChangePwd, Colors.red);
      }
    } catch (_) {
      if (mounted) setState(() => _isChangingPwd = false);
    }
  }

  // ── Delete account ─────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        await AuthService().deleteAccount(token: token);
      }
      await _storage.deleteAll();
      if (!mounted) return;
      _snack(S.accountDeleted, Colors.green);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    } catch (_) {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  void _showDeleteAccountDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  size: 20, color: Colors.red),
            ),
            const SizedBox(width: 10),
            Text(S.deleteAccountTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16,
                    color: Colors.red)),
          ],
        ),
        content: Text(S.deleteAccountMsg,
            style: TextStyle(
                fontSize: 13, color: Colors.grey[600], height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel,
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation:       0,
              shape:           RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(S.deleteAccountBtn,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
    ));
  }

  Future<void> _logout() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  String get _initials {
    final parts = _name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _name.isNotEmpty ? _name[0].toUpperCase() : 'U';
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF121212) : _bg;
    final cardBg    = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : _navy;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Fixed hero header (never scrolls) ──────────────
              _buildHeroHeader(isDark, bgColor, textColor),

              // ── Scrollable content below ────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // ── Account Settings ───────────────────────────
                      _sectionHeader(S.accountSettings,
                          Icons.manage_accounts_outlined, textColor),
                      const SizedBox(height: 10),
                      _card(
                        cardBg: cardBg,
                        isDark: isDark,
                        child: Column(
                          children: [
                            _settingsTile(
                              icon:    Icons.person_outline_rounded,
                              title:   S.nameLabel,
                              value:   _name.isEmpty ? S.tapToSet : _name,
                              onTap:   () => _showEditDialog(
                                title:        S.editName,
                                initialValue: _name,
                                hint:         S.yourFullName,
                                icon:         Icons.person_outline_rounded,
                                onSave: (v) async {
                                  await _saveField('user_name', v);
                                  setState(() => _name = v);
                                  await _syncProfileField(name: v);
                                },
                              ),
                              textColor: textColor,
                            ),
                            _divider(),
                            _settingsTile(
                              icon:    Icons.email_outlined,
                              title:   S.emailLabel,
                              value:   _email.isEmpty ? S.tapToSet : _email,
                              onTap:   () => _showEditDialog(
                                title:        S.editEmail,
                                initialValue: _email,
                                hint:         S.yourEmail,
                                icon:         Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                onSave: (v) async {
                                  await _saveField('user_email', v);
                                  setState(() => _email = v);
                                  await _syncProfileField(email: v);
                                },
                              ),
                              textColor: textColor,
                            ),
                            _divider(),
                            _settingsTile(
                              icon:    Icons.phone_outlined,
                              title:   S.phoneLabel,
                              value:   _phone.isEmpty ? S.tapToSet : _phone,
                              onTap:   () => _showEditDialog(
                                title:        S.editPhone,
                                initialValue: _phone,
                                hint:         S.yourPhone,
                                icon:         Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                onSave: (v) async {
                                  await _saveField('user_phone', v);
                                  setState(() => _phone = v);
                                  await _syncProfileField(numberPhone: v);
                                },
                              ),
                              textColor: textColor,
                            ),
                            _divider(),
                            _buildPasswordTile(cardBg, textColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── Preferences ────────────────────────────────
                      _sectionHeader(S.shoppingPrefs,
                          Icons.shopping_bag_outlined, textColor),
                      const SizedBox(height: 10),
                      _card(
                        cardBg: cardBg,
                        isDark: isDark,
                        child: Column(
                          children: [
                            _preferencesTile(
                              icon:    Icons.category_outlined,
                              title:   S.categoriesLabel,
                              items:   _shoppingCategories,
                              color:   _lightPurple,
                              onTap:   () => _showChipSelector(
                                title:    S.shoppingCatTitle,
                                options:  _categoryOptions,
                                selected: _shoppingCategories,
                                displayLabel: S.categoryName,
                                icon:     categoryIcon,
                                onSave: (list) async {
                                  await _saveList('user_shopping_categories', list);
                                  setState(() => _shoppingCategories = list);
                                  await _syncPreferences(_lifestyles, _allergies, list);
                                },
                              ),
                              textColor:    textColor,
                              displayLabel: S.categoryName,
                            ),
                            _divider(),
                            _preferencesTile(
                              icon:    Icons.health_and_safety_outlined,
                              title:   S.allergiesLabel,
                              items:   _allergies,
                              color:   const Color(0xFFFFCDD2),
                              onTap:   () => _showChipSelector(
                                title:    S.allergiesTitle,
                                options:  _allergyOptions,
                                selected: _allergies,
                                displayLabel: S.allergyOption,
                                onSave: (list) async {
                                  await _saveList('user_allergies', list);
                                  setState(() => _allergies = list);
                                  await _syncPreferences(_lifestyles, list, _shoppingCategories);
                                },
                              ),
                              textColor:    textColor,
                              displayLabel: S.allergyOption,
                            ),
                            _divider(),
                            _preferencesTile(
                              icon:    Icons.eco_outlined,
                              title:   S.lifestyleLabel,
                              items:   _lifestyles,
                              color:   const Color(0xFFB8F0E6),
                              onTap:   () => _showChipSelector(
                                title:    S.lifestyleTitle,
                                options:  _lifestyleOptions,
                                selected: _lifestyles,
                                displayLabel: S.lifestyleOption,
                                onSave: (list) async {
                                  await _saveList('user_lifestyles', list);
                                  setState(() => _lifestyles = list);
                                  await _syncPreferences(list, _allergies, _shoppingCategories);
                                },
                              ),
                              textColor:    textColor,
                              displayLabel: S.lifestyleOption,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── App Settings ───────────────────────────────
                      _sectionHeader(S.appSettings, Icons.settings_outlined,
                          textColor),
                      const SizedBox(height: 10),
                      _card(
                        cardBg: cardBg,
                        isDark: isDark,
                        child: Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap:        _showLanguageSheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    _iconBox(_lightPurple,
                                        Icons.language_rounded, _purpleText),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(S.languageLabel,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize:   14,
                                              color:      textColor)),
                                    ),
                                    Text(S.displayName(
                                            LocaleService.instance.languageCode),
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[500])),
                                    const SizedBox(width: 6),
                                    Icon(Icons.chevron_right_rounded,
                                        color: Colors.grey[400], size: 18),
                                  ],
                                ),
                              ),
                            ),
                            _divider(),
                            ValueListenableBuilder<ThemeMode>(
                              valueListenable: ThemeService.instance,
                              builder: (_, mode, _) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    _iconBox(
                                      mode == ThemeMode.dark
                                          ? const Color(0xFF2D2D2D)
                                          : const Color(0xFFFFEE93),
                                      mode == ThemeMode.dark
                                          ? Icons.dark_mode_rounded
                                          : Icons.light_mode_rounded,
                                      mode == ThemeMode.dark
                                          ? Colors.white70
                                          : const Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(S.darkMode,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize:   14,
                                              color:      textColor)),
                                    ),
                                    Switch(
                                      value:    mode == ThemeMode.dark,
                                      onChanged: (v) =>
                                          ThemeService.instance.setDark(v),
                                      activeThumbColor:   _navy,
                                      activeTrackColor:   _lime,
                                      inactiveThumbColor: Colors.grey[400],
                                      inactiveTrackColor: Colors.grey[300],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Log Out ────────────────────────────────────
                      SizedBox(
                        width:  double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => _showLogoutDialog(context),
                          icon:  Icon(Icons.logout_rounded,
                              color: Colors.red[400], size: 20),
                          label: Text(S.logOut,
                              style: TextStyle(
                                  fontSize:      14,
                                  fontWeight:    FontWeight.w700,
                                  color:         Colors.red[400],
                                  letterSpacing: 0.5)),
                          style: OutlinedButton.styleFrom(
                            side:  BorderSide(color: Colors.red[300]!, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Danger Zone ────────────────────────────────
                      _buildDangerZone(isDark, textColor),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Full-screen overlay while deleting
          if (_isDeletingAccount)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────
  Widget _buildHeroHeader(bool isDark, Color bgColor, Color textColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color:      _navy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative lime circle top-right
          Positioned(
            top: -30, right: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: _lime.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 20, right: 60,
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: _lime.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: _showPickerSheet,
                    child: Stack(
                      children: [
                        Container(
                          width: 96, height: 96,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_lime, _purple],
                              begin: Alignment.topLeft,
                              end:   Alignment.bottomRight,
                            ),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _navy,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _imagePath != null
                                ? Image.file(File(_imagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _initialsWidget(light: true))
                                : _initialsWidget(light: true),
                          ),
                        ),
                        Positioned(
                          bottom: 2, right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:  _lime,
                              shape:  BoxShape.circle,
                              border: Border.all(color: _navy, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 13, color: _navy),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(_name.isEmpty ? S.userLabel : _name,
                      style: const TextStyle(
                          fontSize:   22,
                          fontWeight: FontWeight.w800,
                          color:      Colors.white)),
                  const SizedBox(height: 4),
                  if (_email.isNotEmpty)
                    Text(_email,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  if (_phone.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(_phone,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Danger Zone section ────────────────────────────────────────
  Widget _buildDangerZone(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.red),
            const SizedBox(width: 6),
            Text(S.dangerZone,
                style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      Colors.red,
                    letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.red.withValues(alpha: 0.08)
                : Colors.red.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.red.withValues(alpha: 0.25), width: 1.2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _showDeleteAccountDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color:        Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_forever_rounded,
                        size: 18, color: Colors.red),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.deleteAccount,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize:   14,
                                color:      Colors.red)),
                        const SizedBox(height: 2),
                        Text(S.deleteAccountMsg.split('.').first + '.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.withValues(alpha: 0.65)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.red.withValues(alpha: 0.5), size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Password tile (expandable) ─────────────────────────────────
  Widget _buildPasswordTile(Color cardBg, Color textColor) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _showPwd = !_showPwd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _iconBox(_lightPurple, Icons.lock_outline_rounded, _purpleText),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(S.changePassword,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   14,
                          color:      textColor)),
                ),
                AnimatedRotation(
                  turns:    _showPwd ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child:    Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[400], size: 20),
                ),
              ],
            ),
          ),
        ),
        if (_showPwd) ...[
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Form(
              key: _pwdFormKey,
              child: Column(
                children: [
                  _pwdField(_currentPwdCtrl, S.currentPassword,
                      _obscureCurrent,
                      () => setState(() => _obscureCurrent = !_obscureCurrent),
                      (v) => (v == null || v.isEmpty) ? S.required : null),
                  const SizedBox(height: 12),
                  _pwdField(_newPwdCtrl, S.newPassword, _obscureNew,
                      () => setState(() => _obscureNew = !_obscureNew),
                      (v) {
                    if (v == null || v.isEmpty) return S.required;
                    if (v.length < 6)           return S.min6Chars;
                    return null;
                  }),
                  const SizedBox(height: 12),
                  _pwdField(_confirmPwdCtrl, S.confirmNewPassword,
                      _obscureConfirm,
                      () => setState(() => _obscureConfirm = !_obscureConfirm),
                      (v) {
                    if (v == null || v.isEmpty)     return S.required;
                    if (v != _newPwdCtrl.text)      return S.passwordMismatch;
                    return null;
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: _isChangingPwd ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.black,
                        elevation:       0,
                        shape:           RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isChangingPwd
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2.5))
                          : Text(S.updatePassword,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Language dialog (centered) ─────────────────────────────────
  void _showLanguageSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context:           context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:    const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color:        isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(S.selectLanguage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
              ),
              ..._localeOptions.map((locale) {
                final code  = locale.languageCode;
                final isSel = LocaleService.instance.languageCode == code;
                return ListTile(
                  leading: Text(_langFlag(code),
                      style: const TextStyle(fontSize: 22)),
                  title: Text(S.displayName(code),
                      style: TextStyle(
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.normal)),
                  trailing: isSel
                      ? const Icon(Icons.check_rounded, color: _navy, size: 18)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await LocaleService.instance.setLocale(locale);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _langFlag(String code) {
    switch (code) {
      case 'ar': return '🇩🇿';
      case 'fr': return '🇫🇷';
      default:   return '🇬🇧';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────
  Widget _card({
    required Color cardBg,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset:     const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _iconBox(Color bg, IconData icon, Color iconColor) {
    return Container(
      padding:    const EdgeInsets.all(8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child:      Icon(icon, size: 18, color: iconColor),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _purpleText),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color:      textColor,
                letterSpacing: 0.3)),
      ],
    );
  }

  Widget _settingsTile({
    required IconData    icon,
    required String      title,
    required String      value,
    required VoidCallback onTap,
    required Color       textColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap:        onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _iconBox(_lightPurple, icon, _purpleText),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   14,
                          color:      textColor)),
                  Text(value,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _preferencesTile({
    required IconData     icon,
    required String       title,
    required List<String> items,
    required Color        color,
    required VoidCallback onTap,
    required Color        textColor,
    String Function(String)? displayLabel,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap:        onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _iconBox(_lightPurple, icon, _purpleText),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   14,
                          color:      textColor)),
                  if (items.isEmpty)
                    Text(S.tapToSelect,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]))
                  else
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: items.take(3).map((item) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                            displayLabel != null ? displayLabel(item) : item,
                            style: const TextStyle(
                                fontSize:   10,
                                fontWeight: FontWeight.w600,
                                color:      _navy)),
                      )).toList()
                        ..addAll(items.length > 3
                            ? [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:        color,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('+${items.length - 3}',
                                      style: const TextStyle(
                                          fontSize:   10,
                                          fontWeight: FontWeight.w700,
                                          color:      _navy)),
                                )
                              ]
                            : []),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
      height: 1,
      color: Colors.black.withValues(alpha: 0.06),
      indent: 16,
      endIndent: 16);

  Widget _initialsWidget({bool light = false}) {
    return Center(
      child: Text(_initials,
          style: TextStyle(
              fontSize:   36,
              fontWeight: FontWeight.w800,
              color:      light ? Colors.white : _navy)),
    );
  }

  Widget _pwdField(
    TextEditingController ctrl,
    String label,
    bool obscure,
    VoidCallback onToggle,
    String? Function(String?) validator,
  ) {
    return TextFormField(
      controller:  ctrl,
      obscureText: obscure,
      validator:   validator,
      style:       const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
        filled:     true,
        fillColor:  _lightPurple,
        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.black45),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18, color: Colors.black38,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: _purple, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: Colors.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: Colors.red, width: 1.5)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E) : _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.logOutTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, color: _navy)),
        content: Text(S.logOutMsg,
            style: const TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.cancel,
                style: const TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _logout(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              elevation:       0,
              shape:           RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(S.logOutTitle,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
