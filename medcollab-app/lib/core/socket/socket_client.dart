import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';

/// Real-time client for MedCollab Socket.io server.
///
/// Backend auth: JWT in `handshake.auth.token`.
/// Messages are persisted via REST; socket is for broadcast + presence.
class SocketClient {
  SocketClient();

  io.Socket? _socket;
  String? _accessToken;
  final _connectionController = StreamController<bool>.broadcast();

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

    _socket = io.io(
      EnvConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(
              AppConstants.socketReconnectDelay.inMilliseconds,)
          .setReconnectionAttempts(AppConstants.socketMaxReconnectAttempts)
          .setAuth({'token': accessToken})
          .build(),
    );

    _registerLifecycleHandlers();
    _socket!.connect();
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    _accessToken = null;
    _connectionController.add(false);
  }

  /// Reconnect after silent token refresh.
  Future<void> reconnect(String newAccessToken) async {
    await connect(newAccessToken);
  }

  // ── Channel rooms ───────────────────────────────────────────────────────────

  void joinChannel(String channelId) {
    _emit(SocketEvents.joinChannel, {'channelId': channelId});
  }

  void leaveChannel(String channelId) {
    _emit(SocketEvents.leaveChannel, {'channelId': channelId});
  }

  // ── Typing indicators ─────────────────────────────────────────────────────

  void emitTypingStart(String channelId) {
    _emit(SocketEvents.typingStart, {'channelId': channelId});
  }

  void emitTypingStop(String channelId) {
    _emit(SocketEvents.typingStop, {'channelId': channelId});
  }

  // ── Presence ──────────────────────────────────────────────────────────────

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

  // ── Event subscriptions ─────────────────────────────────────────────────────

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

  Stream<Map<String, dynamic>> onMapEvent(String event) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    void listener(dynamic data) {
      if (data is Map<String, dynamic>) {
        controller.add(data);
      } else if (data is Map) {
        controller.add(Map<String, dynamic>.from(data));
      }
    }

    _socket?.on(event, listener);
    controller.onCancel = () => _socket?.off(event, listener);
    return controller.stream;
  }

  void dispose() {
    disconnect();
    _connectionController.close();
  }

  void _emit(String event, Map<String, dynamic> payload) {
    if (!isConnected) return;
    _socket!.emit(event, payload);
  }

  void _registerLifecycleHandlers() {
    final socket = _socket!;

    socket.onConnect((_) => _connectionController.add(true));
    socket.onDisconnect((_) => _connectionController.add(false));
    socket.onConnectError((_) => _connectionController.add(false));
    socket.onError((_) => _connectionController.add(false));

    socket.on(SocketEvents.authenticated, (_) {
      _connectionController.add(true);
    });

    socket.on(SocketEvents.authError, (_) {
      _connectionController.add(false);
    });
  }
}
