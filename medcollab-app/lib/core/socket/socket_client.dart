import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/network/auth_interceptor.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';

/// Real-time client for MedCollab Socket.io server.
///
/// Backend auth: JWT in `handshake.auth.token`.
/// Messages are persisted via REST; socket is for broadcast + presence.
class SocketClient {
  SocketClient();

  io.Socket? _socket;
  String? _accessToken;
  final _connectionController = StreamController<bool>.broadcast();
  final _joinedChannels = <String>{};
  final _eventControllers = <String, StreamController<Map<String, dynamic>>>{};

  /// Called when the socket drops — refresh JWT and reconnect.
  TokenRefreshCallback? onTokenRefreshNeeded;

  bool _isReplacingSocket = false;
  bool _recoverInFlight = false;
  Timer? _recoverDebounce;

  bool get isConnected => _socket?.connected ?? false;

  Stream<bool> get connectionStream => _connectionController.stream;

  io.Socket? get rawSocket => _socket;

  /// Connect with a valid access token.
  Future<void> connect(String accessToken) async {
    if (_socket?.connected == true && _accessToken == accessToken) {
      return;
    }

    await disconnect();
    _accessToken = accessToken;

    _socket = _createSocket(accessToken);
    _registerLifecycleHandlers();
    _bindTrackedEvents();
    await _connectAndWait();
  }

  io.Socket _createSocket(String accessToken) {
    return io.io(
      EnvConfig.socketUrl,
      io.OptionBuilder()
          // Polling first helps Flutter web when websocket handshake is flaky.
          .setTransports(['polling', 'websocket'])
          .disableAutoConnect()
          // Reconnect is managed manually so we always handshake with a fresh JWT.
          .setAuth({'token': accessToken})
          .build(),
    );
  }

  Future<void> _connectAndWait() async {
    final socket = _socket;
    if (socket == null) return;

    if (socket.connected) {
      _onSocketReady();
      return;
    }

    final completer = Completer<void>();
    void onConnect(dynamic _) {
      socket.off('connect', onConnect);
      if (!completer.isCompleted) completer.complete();
    }

    socket.on('connect', onConnect);
    socket.connect();

    try {
      await completer.future.timeout(AppConstants.connectTimeout);
    } on TimeoutException {
      // Connection may still complete in the background.
    }
  }

  Future<void> disconnect() async {
    _recoverDebounce?.cancel();
    _joinedChannels.clear();
    _socket?.dispose();
    _socket = null;
    _accessToken = null;
    _connectionController.add(false);
  }

  Future<void> reconnect(String newAccessToken) async {
    await updateAccessToken(newAccessToken);
  }

  /// Refresh JWT by recreating the socket so handshake auth uses the new token.
  Future<void> updateAccessToken(String accessToken) async {
    if (_accessToken == accessToken && isConnected) return;

    _accessToken = accessToken;
    final socket = _socket;
    if (socket == null) {
      await connect(accessToken);
      return;
    }

    _isReplacingSocket = true;
    try {
      socket.dispose();
      _socket = null;
      _connectionController.add(false);

      _socket = _createSocket(accessToken);
      _registerLifecycleHandlers();
      _bindTrackedEvents();
      await _connectAndWait();
    } finally {
      _isReplacingSocket = false;
    }
  }

  void joinChannel(String channelId) {
    if (channelId.isEmpty) return;
    _joinedChannels.add(channelId);
    _emit(SocketEvents.joinChannel, {'channelId': channelId});
  }

  void leaveChannel(String channelId) {
    if (channelId.isEmpty) return;
    _joinedChannels.remove(channelId);
    _emit(SocketEvents.leaveChannel, {'channelId': channelId});
  }

  /// Re-join all space rooms from server membership (after create/join space).
  void syncSpaceRooms() {
    _emit(SocketEvents.syncSpaceRooms, {});
  }

  void emitTypingStart(String channelId) {
    _emit(SocketEvents.typingStart, {'channelId': channelId});
  }

  void emitTypingStop(String channelId) {
    _emit(SocketEvents.typingStop, {'channelId': channelId});
  }

  void updateAvailability({
    required String status,
    String? until,
    String? note,
  }) {
    _emit(SocketEvents.updateAvailability, {
      'status': status,
      if (until != null) 'until': until,
      if (note != null) 'note': note,
    });
  }

  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic data)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
      _socket?.off(event);
    }
  }

  /// Subscribe to a socket event as a typed map stream.
  /// Survives reconnects — listeners stay on this client, not the raw socket.
  Stream<Map<String, dynamic>> onMapEvent(String event) {
    final controller = _eventControllers.putIfAbsent(
      event,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );
    _bindTrackedEvents();
    return controller.stream;
  }

  void dispose() {
    _recoverDebounce?.cancel();
    disconnect();
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
    _connectionController.close();
  }

  void _emit(String event, Map<String, dynamic> payload) {
    if (!isConnected) return;
    _socket!.emit(event, payload);
  }

  void _rejoinChannels() {
    for (final channelId in _joinedChannels) {
      _emit(SocketEvents.joinChannel, {'channelId': channelId});
    }
  }

  void _onSocketReady() {
    _bindTrackedEvents();
    _connectionController.add(true);
    _rejoinChannels();
    syncSpaceRooms();
  }

  void _scheduleRecover() {
    _recoverDebounce?.cancel();
    _recoverDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_recoverConnection());
    });
  }

  Future<void> _recoverConnection() async {
    if (_recoverInFlight || _isReplacingSocket) return;
    _recoverInFlight = true;
    try {
      var token = _accessToken;
      final refresh = onTokenRefreshNeeded;
      if (refresh != null) {
        token = await refresh() ?? token;
      }
      if (token == null || token.isEmpty) return;
      await updateAccessToken(token);
    } finally {
      _recoverInFlight = false;
    }
  }

  void _bindTrackedEvents() {
    final socket = _socket;
    if (socket == null) return;

    for (final event in _eventControllers.keys) {
      socket.off(event);
      socket.on(event, (data) => _dispatchEvent(event, data));
    }
  }

  void _dispatchEvent(String event, dynamic data) {
    final controller = _eventControllers[event];
    if (controller == null || controller.isClosed) return;

    final map = _normalizePayload(data);
    if (map != null) {
      controller.add(map);
    }
  }

  Map<String, dynamic>? _normalizePayload(dynamic data) {
    var value = data;
    if (value is List && value.isNotEmpty) {
      value = value.first;
    }
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    if (value is Map) {
      return deepJsonMap(value);
    }
    return null;
  }

  void _registerLifecycleHandlers() {
    final socket = _socket!;

    socket.onConnect((_) => _onSocketReady());

    socket.onDisconnect((reason) {
      _connectionController.add(false);
      if (_isReplacingSocket) return;
      if (reason == 'io client disconnect') return;
      _scheduleRecover();
    });

    socket.onConnectError((_) {
      _connectionController.add(false);
      _scheduleRecover();
    });

    socket.onError((_) {
      _connectionController.add(false);
      _scheduleRecover();
    });

    socket.on(SocketEvents.authenticated, (_) => _onSocketReady());

    socket.on(SocketEvents.authError, (_) {
      _connectionController.add(false);
      _scheduleRecover();
    });
  }
}
