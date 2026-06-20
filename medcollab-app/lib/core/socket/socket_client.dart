import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
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
          // Polling first helps Flutter web when websocket handshake is flaky.
          .setTransports(['polling', 'websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(
            AppConstants.socketReconnectDelay.inMilliseconds,
          )
          .setReconnectionAttempts(AppConstants.socketMaxReconnectAttempts)
          .setAuth({'token': accessToken})
          .build(),
    );

    _registerLifecycleHandlers();
    _bindTrackedEvents();
    _socket!.connect();
  }

  Future<void> disconnect() async {
    _joinedChannels.clear();
    _socket?.dispose();
    _socket = null;
    _accessToken = null;
    _connectionController.add(false);
  }

  Future<void> reconnect(String newAccessToken) async {
    await connect(newAccessToken);
  }

  void joinChannel(String channelId) {
    _joinedChannels.add(channelId);
    _emit(SocketEvents.joinChannel, {'channelId': channelId});
  }

  void leaveChannel(String channelId) {
    _joinedChannels.remove(channelId);
    _emit(SocketEvents.leaveChannel, {'channelId': channelId});
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
    _connectionController.add(true);
    _rejoinChannels();
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

    if (data is Map) {
      controller.add(deepJsonMap(data));
    }
  }

  void _registerLifecycleHandlers() {
    final socket = _socket!;

    socket.onConnect((_) => _onSocketReady());

    socket.onReconnect((_) => _onSocketReady());

    socket.onDisconnect((_) => _connectionController.add(false));

    socket.onConnectError((_) => _connectionController.add(false));

    socket.onError((_) => _connectionController.add(false));

    socket.on(SocketEvents.authenticated, (_) => _onSocketReady());

    socket.on(SocketEvents.authError, (_) => _connectionController.add(false));
  }
}
