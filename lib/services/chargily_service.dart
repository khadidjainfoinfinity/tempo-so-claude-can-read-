import 'package:dio/dio.dart';

class ChargilyService {
  // Chargily secret key — test_sk_... for sandbox, sk_... for production
  static const String _secretKey =
      'test_sk_j3ZMlyYFLENk87OdI6Eeotzp61ZgN3zvXZ1yr7ak';
  static const String _baseUrl = 'https://pay.chargily.com.dz/api/v2';

  // Public backend URL that Chargily calls after each payment event.
  // Must be reachable from the internet (not localhost).
  static const String _webhookUrl =
      'https://pro1-q1zg.onrender.com/api/webhook/chargily';

  late final Dio _dio;

  ChargilyService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(milliseconds: 15000),
      receiveTimeout: const Duration(milliseconds: 15000),
    ));
  }

  /// Creates a Chargily Pay V2 checkout session and returns the [checkout_url].
  ///
  /// [orderId]       — MongoDB _id from POST /api/place-order.
  ///                   Chargily echoes it back in the webhook so the backend
  ///                   knows which order to mark as completed.
  /// [paymentMethod] — 'edahabia' or 'cib'.
  Future<String?> createCheckout({
    required double amount,
    required String customerName,
    required String customerEmail,
    required String orderId,
    String paymentMethod = 'edahabia',
  }) async {
    final response = await _dio.post('/checkouts', data: {
      'amount':           amount,
      'currency':         'dzd',
      'payment_method':   paymentMethod,
      'success_url':      'https://novashop.app/payment/success',
      'failure_url':      'https://novashop.app/payment/failure',
      'webhook_endpoint': _webhookUrl,
      'locale':           'ar',
      'metadata': {
        'order_id':       orderId,        // ← echoed back in webhook payload
        'customer_name':  customerName,
        'customer_email': customerEmail,
      },
    });

    final data = response.data as Map<String, dynamic>;
    return data['checkout_url'] as String?;
  }
}
