import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';

class SignUpController {
  final TextEditingController nameController    = TextEditingController();
  final TextEditingController phoneController   = TextEditingController();
  final TextEditingController emailController   = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController  = TextEditingController();

  String? emailError;
  String? phoneError;
  String? passwordError;
  String? confirmError;
  bool isLoading = false;

  final AuthService _authService = AuthService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    isLoading = true;
    try {
      final res = await _authService.googleSignIn(idToken);

      if (res['statusCode'] == 200 || res['statusCode'] == 201) {
        final data = res['body'];
        final user = data['user'];

        await _storage.write(key: 'jwt_token',  value: data['token']);
        await _storage.write(key: 'user_id',    value: user['id']?.toString() ?? '');
        await _storage.write(key: 'user_name',  value: user['name']  ?? '');
        await _storage.write(key: 'user_email', value: user['email'] ?? '');
        await _storage.write(key: 'user_phone', value: user['phone'] ?? '');

        final apiCompleted = user['categoriesCompleted'] == true;
        await _storage.write(
          key: 'categories_completed',
          value: apiCompleted ? 'true' : 'false',
        );

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

  Future<Map<String, dynamic>> signup() async {
    final name     = nameController.text.trim();
    final phone    = phoneController.text.trim();
    final email    = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm  = confirmController.text.trim();

    if (password != confirm) {
      confirmError = "Passwords do not match";
      return {"statusCode": 400, "body": {"message": confirmError}};
    }

    emailError    = null;
    phoneError    = null;
    passwordError = null;
    confirmError  = null;
    isLoading     = true;

    try {
      final res = await _authService.signup(
        name:     name,
        phone:    phone,
        email:    email,
        password: password,
      );

      if (res['statusCode'] == 201) {
        // Marquer l'onboarding catégories comme non complété (nouveau client)
        await _storage.write(key: 'categories_completed', value: 'false');
        // Sauvegarder les infos de base pour l'écran Home
        await _storage.write(key: 'user_name',  value: name);
        await _storage.write(key: 'user_email', value: email);
        await _storage.write(key: 'user_phone', value: phone);
        // Sauvegarder le token si l'API en renvoie un
        final token = res['body']['token'];
        if (token != null) {
          await _storage.write(key: 'jwt_token', value: token as String);
        }
      }

      return res;
    } catch (e) {
      return {"statusCode": 500, "body": {"message": e.toString()}};
    } finally {
      isLoading = false;
    }
  }
}
