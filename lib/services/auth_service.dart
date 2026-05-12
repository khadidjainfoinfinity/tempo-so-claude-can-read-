import 'dart:async';
import 'dart:convert'; // to convert between JSON and Dart
import 'dart:io'; // for SocketException and HttpException
import 'package:http/http.dart' as http; // for making HTTP requests

class AuthService {
  // Production (Render) : https://pro1-q1zg.onrender.com/api
  static const String _prodUrl = "https://pro1-q1zg.onrender.com/api";
  // Local development :  run `npm start`
  //   Android emulator : http://10.0.2.2:5000/api
  //   iOS simulator    : http://localhost:5000/api
  static const String _localUrl = "http://10.0.2.2:5000/api";

  // FastAPI recommender — runs on port 8000 (separate from Node.js)
  //   Android emulator : http://10.0.2.2:8000
  //   iOS simulator    : http://localhost:8000
  static const String _localFastApiUrl =
      "http://10.0.2.2:8000"; // hada local ki ndirou bel PC brk
  static const String _prodFastApiUrl =
      "https://recommender-api-xsm5.onrender.com"; // hada l APi T3 render ki ndirou b render brk

  // Set to true to use the local backend instead of Render
  static const bool _useLocal =
      false; // false ida rana nkhdmou b render ( backend w SR fizouj) sinon true nkhdmou locally brk bel pc

  static const String baseUrl = _useLocal ? _localUrl : _prodUrl;
  static const String fastApiUrl = _useLocal
      ? _localFastApiUrl
      : _prodFastApiUrl;
  static const Duration _timeout = Duration(
    seconds: 60,
  ); // Render free tier cold-start can take 30-50s
  static const Duration _productTimeout = Duration(seconds: 90);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl$path"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final decoded = jsonDecode(response.body);
      return {"statusCode": response.statusCode, "body": decoded};
    } on SocketException {
      return {
        "statusCode": 503,
        "body": {"message": "No internet connection"},
      };
    } on HttpException {
      return {
        "statusCode": 503,
        "body": {"message": "Server unreachable"},
      };
    } on TimeoutException {
      return {
        "statusCode": 504,
        "body": {
          "message": "Server is taking too long to respond. Please try again.",
        },
      };
    } catch (e) {
      return {
        "statusCode": 500,
        "body": {"message": "Unexpected error: $e"},
      };
    }
  }

  Future<Map<String, dynamic>> loginWithEmailOrPhone(
    Map<String, String> payload,
  ) async {
    return _post("/login", payload);
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    return _post("/signup", {
      "name": name,
      "numberPhone": phone,
      "email": email,
      "password": password,
    });
  }

  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    return _post("/google-signin", {"idToken": idToken});
  }

  Future<Map<String, dynamic>> forgotPassword(
    String loginInput, {
    String method = 'whatsapp',
  }) async {
    return _post("/forgot-password", {
      "loginInput": loginInput,
      "method": method,
    });
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String loginInput,
    required String otp,
  }) async {
    return _post("/verify-otp", {"loginInput": loginInput, "otp": otp});
  }

  Future<Map<String, dynamic>> resetPassword({
    required String loginInput,
    required String newPassword,
  }) async {
    return _post("/reset-password", {
      "loginInput": loginInput,
      "newPassword": newPassword,
    });
  }

  Future<Map<String, dynamic>> getProductByBarcode(String barcode) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/products',
      ).replace(queryParameters: {'barcode': barcode});
      final response = await http.get(uri).timeout(_productTimeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } on TimeoutException {
      return {
        'statusCode': 504,
        'body': {'message': 'Request timed out'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> getProducts({
    String? category,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (category != null && category != 'All') params['category'] = category;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse(
        '$baseUrl/products',
      ).replace(queryParameters: params.isEmpty ? null : params);
      final response = await http.get(uri).timeout(_productTimeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } on TimeoutException {
      return {
        'statusCode': 504,
        'body': {'message': 'Server is waking up, please retry'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> getRecommendations(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/recommendations'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_productTimeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } on TimeoutException {
      return {
        'statusCode': 504,
        'body': {'message': 'Request timed out'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  /// Calls FastAPI recommender directly (bypasses Node.js proxy).
  /// Returns the same shape: { statusCode, body: { recommendations: [...] } }
  Future<Map<String, dynamic>> getRecommendationsDirect(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$fastApiUrl/recommend/$userId'))
          .timeout(_productTimeout);
      final decoded = jsonDecode(response.body);
      // FastAPI returns { user_id, name, recommendations: [...] }
      // Normalise to the same shape the app expects
      return {
        'statusCode': response.statusCode,
        'body': {'recommendations': decoded['recommendations'] ?? []},
      };
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } on TimeoutException {
      return {
        'statusCode': 504,
        'body': {'message': 'Request timed out'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<void> recordPurchase(String token, String productId) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/recommendations/purchase'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'productId': productId}),
          )
          .timeout(_timeout);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> placeOrder({
    required String token,
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMethod,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/place-order'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'items': items,
              'total': total,
              'paymentMethod': paymentMethod,
            }),
          )
          .timeout(_timeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } on TimeoutException {
      return {
        'statusCode': 504,
        'body': {'message': 'Request timed out'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> getOrderHistory(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/my-orders'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } on TimeoutException {
      return {
        'statusCode': 504,
        'body': {'message': 'Request timed out'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? name,
    String? email,
    String? numberPhone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (numberPhone != null) body['numberPhone'] = numberPhone;

    try {
      final response = await http
          .put(
            Uri.parse("$baseUrl/update-profile"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final decoded = jsonDecode(response.body);
      return {"statusCode": response.statusCode, "body": decoded};
    } on SocketException {
      return {
        "statusCode": 503,
        "body": {"message": "No internet connection"},
      };
    } catch (e) {
      return {
        "statusCode": 500,
        "body": {"message": "Unexpected error: $e"},
      };
    }
  }

  Future<Map<String, dynamic>> getFeedback(String productId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/feedback/$productId'))
          .timeout(_timeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> submitFeedback({
    required String token,
    required String productId,
    required int rating,
    required String text,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/feedback/$productId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'rating': rating, 'text': text}),
          )
          .timeout(_timeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> deleteFeedback({
    required String token,
    required String feedbackId,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/feedback/$feedbackId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> deleteAccount({
    required String token,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/delete-account'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {
        'statusCode': 503,
        'body': {'message': 'No internet connection'},
      };
    } on TimeoutException {
      return {
        'statusCode': 504,
        'body': {'message': 'Server is taking too long to respond. Please try again.'},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Unexpected error: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> getPromotions() async {
    try {
      final uri = Uri.parse('$baseUrl/products')
          .replace(queryParameters: {'discount': 'true'});
      final response = await http.get(uri).timeout(_productTimeout);
      final decoded = jsonDecode(response.body);
      return {'statusCode': response.statusCode, 'body': decoded};
    } on SocketException {
      return {'statusCode': 503, 'body': {'message': 'No internet connection'}};
    } on TimeoutException {
      return {'statusCode': 504, 'body': {'message': 'Server is waking up, please retry'}};
    } catch (e) {
      return {'statusCode': 500, 'body': {'message': 'Unexpected error: $e'}};
    }
  }

  Future<Map<String, dynamic>> updatePreferences({
    required String token,
    required List<String> lifestyles,
    required List<String> allergies,
    required List<String> shoppingCategories,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/update-preferences"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode({
              "lifestyles": lifestyles,
              "allergies": allergies,
              "shoppingCategories": shoppingCategories,
            }),
          )
          .timeout(_timeout);

      final decoded = jsonDecode(response.body);
      return {"statusCode": response.statusCode, "body": decoded};
    } on SocketException {
      return {
        "statusCode": 503,
        "body": {"message": "No internet connection"},
      };
    } catch (e) {
      return {
        "statusCode": 500,
        "body": {"message": "Unexpected error: $e"},
      };
    }
  }
}
