import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';

class LoginController {
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  String? emailError;
  String? passwordError;
  bool isLoading = false;

  final AuthService _authService = AuthService();

  /// Login avec email ou numéro de téléphone.
  /// Retourne la réponse + [needsOnboarding] = true si le client
  /// n'a jamais complété la sélection des catégories.
  Future<Map<String, dynamic>> login() async {
    final input    = emailController.text.trim();
    final password = passwordController.text.trim();

    emailError    = null;
    passwordError = null;
    isLoading     = true;

    if (input.isEmpty) {
      emailError = "Email or phone is required";
      isLoading  = false;
      return {"statusCode": 400, "body": {"message": emailError}};
    }

    if (password.isEmpty) {
      passwordError = "Password is required";
      isLoading     = false;
      return {"statusCode": 400, "body": {"message": passwordError}};
    }

    try {
      final res = await _authService.loginWithEmailOrPhone({
        "loginInput": input,
        "password":   password,
      });

      if (res['statusCode'] == 200) {
        final data = res['body'];
        final user = data['user'];

        // Sauvegarder le token et les infos utilisateur
        await storage.write(key: 'jwt_token',   value: data['token']);
        await storage.write(key: 'user_id',     value: user['id']?.toString() ?? '');
        await storage.write(key: 'user_name',   value: user['name']  ?? '');
        await storage.write(key: 'user_email',  value: user['email'] ?? '');
        await storage.write(key: 'user_phone',  value: user['phone'] ?? '');

        // Synchroniser le flag onboarding depuis la réponse API
        // (priorité sur le storage local — source de vérité = backend)
        final apiCompleted = user['categoriesCompleted'] == true;
        await storage.write(
          key: 'categories_completed',
          value: apiCompleted ? 'true' : 'false',
        );

        // Sauvegarder les préférences retournées par l'API
        if (user['lifestyles'] != null) {
          await storage.write(
            key: 'user_lifestyles',
            value: (user['lifestyles'] as List).isNotEmpty
                ? '[${(user['lifestyles'] as List).map((e) => '"$e"').join(',')}]'
                : '[]',
          );
        }
        if (user['allergies'] != null) {
          await storage.write(
            key: 'user_allergies',
            value: (user['allergies'] as List).isNotEmpty
                ? '[${(user['allergies'] as List).map((e) => '"$e"').join(',')}]'
                : '[]',
          );
        }
        if (user['shoppingCategories'] != null) {
          await storage.write(
            key: 'user_shopping_categories',
            value: (user['shoppingCategories'] as List).isNotEmpty
                ? '[${(user['shoppingCategories'] as List).map((e) => '"$e"').join(',')}]'
                : '[]',
          );
        }

        return {
          ...res,
          'needsOnboarding': !apiCompleted,
          'userName': user['name'] ?? '',
        };
      }

      return res;
    } catch (e) {
      return {
        "statusCode": 500,
        "body": {"message": "Login error: ${e.toString()}"}
      };
    } finally {
      isLoading = false;
    }
  }

  /// Google Sign-In — receives an idToken from Google, sends to backend,
  /// stores the JWT and user data exactly like [login].
  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    isLoading = true;
    try {
      final res = await _authService.googleSignIn(idToken);

      if (res['statusCode'] == 200) {
        final data = res['body'];
        final user = data['user'];

        await storage.write(key: 'jwt_token',  value: data['token']);
        await storage.write(key: 'user_id',    value: user['id']?.toString() ?? '');
        await storage.write(key: 'user_name',  value: user['name']  ?? '');
        await storage.write(key: 'user_email', value: user['email'] ?? '');
        await storage.write(key: 'user_phone', value: user['phone'] ?? '');

        final apiCompleted = user['categoriesCompleted'] == true;
        await storage.write(
          key: 'categories_completed',
          value: apiCompleted ? 'true' : 'false',
        );

        if (user['lifestyles'] != null) {
          await storage.write(
            key: 'user_lifestyles',
            value: (user['lifestyles'] as List).isNotEmpty
                ? '[${(user['lifestyles'] as List).map((e) => '"$e"').join(',')}]'
                : '[]',
          );
        }
        if (user['allergies'] != null) {
          await storage.write(
            key: 'user_allergies',
            value: (user['allergies'] as List).isNotEmpty
                ? '[${(user['allergies'] as List).map((e) => '"$e"').join(',')}]'
                : '[]',
          );
        }
        if (user['shoppingCategories'] != null) {
          await storage.write(
            key: 'user_shopping_categories',
            value: (user['shoppingCategories'] as List).isNotEmpty
                ? '[${(user['shoppingCategories'] as List).map((e) => '"$e"').join(',')}]'
                : '[]',
          );
        }

        return {
          ...res,
          'needsOnboarding': !apiCompleted,
          'userName': user['name'] ?? '',
        };
      }

      return res;
    } catch (e) {
      return {
        "statusCode": 500,
        "body": {"message": "Google sign-in error: ${e.toString()}"}
      };
    } finally {
      isLoading = false;
    }
  }

  void clear() {
    emailController.clear();
    passwordController.clear();
    emailError    = null;
    passwordError = null;
  }
}
