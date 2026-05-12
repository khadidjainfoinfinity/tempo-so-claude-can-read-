import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'cart_service.dart';

enum IotState { idle, linking, connected }

class IotService extends ChangeNotifier with WidgetsBindingObserver {
  static final IotService instance = IotService._();
  IotService._();

  io.Socket? _socket;
  IotState   _state             = IotState.idle;
  String?    _wagonId;
  String?    _serverIp;
  String?    lastError;
  bool       _checkoutRequested = false;
  bool       _observerAdded     = false;

  IotState get state              => _state;
  bool get connected              => _state == IotState.connected;
  bool get linking                => _state == IotState.linking;
  String? get wagonId             => _wagonId;
  String? get serverIp            => _serverIp;
  bool get checkoutRequested      => _checkoutRequested;

  void clearCheckoutRequest() {
    _checkoutRequested = false;
    notifyListeners();
  }

  // ── App lifecycle — reconnect when app comes back to foreground ───────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground: reconnect if we have a pending session
      if (_wagonId != null && _serverIp != null &&
          _socket != null && !_socket!.connected) {
        _socket!.connect();
      }
    }
  }

  // ── UDP auto-discovery ────────────────────────────────────────────────────
  static Future<String?> discoverServer({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 5005,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      final completer = Completer<String?>();

      final sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket!.receive();
          if (datagram == null) return;
          try {
            final json = jsonDecode(utf8.decode(datagram.data))
                as Map<String, dynamic>;
            if (json['service'] == 'novashop-iot' && !completer.isCompleted) {
              completer.complete(json['ip'] as String);
            }
          } catch (_) {}
        }
      });

      Future.delayed(timeout, () {
        if (!completer.isCompleted) completer.complete(null);
      });

      final ip = await completer.future;
      await sub.cancel();
      socket.close();
      return ip;
    } catch (_) {
      socket?.close();
      return null;
    }
  }

  // Scan the tablet QR → extract wagonId → POST /api/caddie/link → join socket room
  Future<bool> linkToWagon({
    required String serverIp,
    required String wagonId,
    required String userId,
    required String userName,
    List<String> allergies  = const [],
    List<String> lifestyles = const [],
  }) async {
    // Register lifecycle observer once so we can reconnect on app resume
    if (!_observerAdded) {
      WidgetsBinding.instance.addObserver(this);
      _observerAdded = true;
    }

    _serverIp = serverIp;
    _state    = IotState.linking;
    notifyListeners();

    final url = Uri.parse('http://$serverIp:5004/api/caddie/link');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'wagonId':   wagonId,
          'userId':    userId,
          'userName':  userName,
          'allergies':  allergies,
          'lifestyles': lifestyles,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        lastError = null;
        _wagonId  = wagonId;
        _connectSocket(wagonId);
        return true;
      }
      lastError = 'Server returned ${response.statusCode}';
      _state    = IotState.idle;
      notifyListeners();
      return false;
    } on SocketException catch (e) {
      lastError = 'Cannot reach $serverIp:5004 — check WiFi & firewall (${e.message})';
      _state    = IotState.idle;
      notifyListeners();
      return false;
    } on TimeoutException {
      lastError = 'Connection timed out — server may be blocked by firewall';
      _state    = IotState.idle;
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      _state    = IotState.idle;
      notifyListeners();
      return false;
    }
  }

  void _connectSocket(String wagonId) {
    _socket = io.io(
      'http://$_serverIp:5004',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          // Keep retrying forever if the connection drops
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)       // 1 s between attempts
          .setReconnectionDelayMax(10000)   // cap at 10 s
          .setTimeout(20000)                // longer handshake timeout
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('join_wagon_room', wagonId);
      _state = IotState.connected;
      notifyListeners();
    });

    // Re-join the wagon room automatically after every reconnect
    _socket!.onReconnect((_) {
      _socket!.emit('join_wagon_room', wagonId);
      _state = IotState.connected;
      notifyListeners();
    });

    _socket!.off('product_added_to_cart');
    _socket!.off('product_confirmed');
    _socket!.off('cart_sync');
    _socket!.on('cart_sync', (data) {
      final raw = data is List ? data : (data != null ? [data] : <dynamic>[]);
      if (raw.isEmpty) return;
      CartService.instance.replaceAll(
        raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    });
    _socket!.on('product_confirmed', (data) {
      final raw = (data is List && data.isNotEmpty) ? data.first : data;
      if (raw is! Map) return;
      final map = Map<String, dynamic>.from(raw);
      if (map.containsKey('_sync_qty')) {
        final productId = map['_id'] as String? ?? '';
        final syncQty   = (map['_sync_qty'] as num?)?.toInt() ?? 0;
        if (productId.isNotEmpty) CartService.instance.setQuantity(productId, syncQty);
      } else {
        CartService.instance.add(map);
      }
    });

    _socket!.on('checkout_requested', (_) {
      _checkoutRequested = true;
      notifyListeners();
    });

    _socket!.on('quantity_updated', (data) {
      final raw = (data is List && data.isNotEmpty) ? data.first : data;
      if (raw is! Map) return;
      final productId = raw['productId'] as String? ?? '';
      final quantity  = (raw['quantity']  as num?)?.toInt() ?? 0;
      if (productId.isEmpty) return;
      if (quantity <= 0) {
        CartService.instance.remove(productId);
      } else {
        CartService.instance.setQuantity(productId, quantity);
      }
    });

    _socket!.onDisconnect((_) {
      // Only update UI state — do NOT clear _wagonId/_serverIp so that
      // auto-reconnect and the lifecycle observer can bring us back.
      if (_state == IotState.connected) {
        _state = IotState.idle;
        notifyListeners();
      }
    });

    _socket!.onConnectError((_) {
      // Keep _wagonId and _serverIp intact so Socket.IO can keep retrying.
      if (_state != IotState.idle) {
        _state = IotState.idle;
        notifyListeners();
      }
    });
  }

  /// Sends a product barcode to the IoT cart server so it registers the scan.
  Future<bool> addProductToCart(String barcode) async {
    if (_serverIp == null || _wagonId == null || _state != IotState.connected) {
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('http://$_serverIp:5004/api/caddie/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'barcode': barcode, 'wagonId': _wagonId}),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void disconnect() {
    if (_observerAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAdded = false;
    }
    _releaseWagon();
    _socket?.disconnect();
    _socket?.dispose();
    _socket   = null;
    _wagonId  = null;
    _serverIp = null;
    _state    = IotState.idle;
    CartService.instance.clear();
    notifyListeners();
  }

  void _releaseWagon() {
    if (_serverIp == null || _wagonId == null) return;
    http.post(
      Uri.parse('http://$_serverIp:5004/api/caddie/release'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'wagonId': _wagonId}),
    ).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 0));
  }
}
