import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/camera_connection.dart';
import 'api_handler.dart';
import 'peer_connection_manager.dart';
import 'web_viewer_handler.dart';

class WebSocketServerManager extends ChangeNotifier {
  HttpServer? _server;
  final Map<String, CameraConnection> _connections = {};
  int _port = 8080; // Porta padrão
  String? _selectedCameraId;
  bool _audioEnabled = false;

  // Handlers especializados
  late ApiHandler _apiHandler;
  late WebViewerHandler _webViewerHandler;

  // Callbacks para integração com a nova UI
  Function(CameraConnection)? onCameraConnected;
  Function(String)? onCameraDisconnected;
  Function(CameraConnection)? onCameraUpdated;

  WebSocketServerManager() {
    _loadPort();
    _initializeHandlers();
  }

  // Getters
  int get port => _port;
  Map<String, CameraConnection> get connections => _connections;
  String? get selectedCameraId => _selectedCameraId;
  bool get audioEnabled => _audioEnabled;

  List<RTCVideoRenderer> get remoteRenderers =>
      _connections.values.map((c) => c.renderer).toList();

  List<RTCPeerConnection> get peerConnections =>
      _connections.values.map((c) => c.peerConnection).toList();

  // Setters
  set muteAudio(bool mute) {
    _audioEnabled = mute;
    _setAudioEnabled(mute);
  }

  set port(int newPort) {
    _port = newPort;
    _savePort();
    _restartServer();
  }

  /// Inicializa os handlers especializados
  void _initializeHandlers() {
    _apiHandler = ApiHandler(
      connections: _connections,
      port: _port,
    );
    _webViewerHandler = WebViewerHandler(
      connections: _connections,
      port: _port,
    );
  }

  /// Atualiza os handlers quando a porta muda
  void _updateHandlers() {
    _apiHandler = ApiHandler(
      connections: _connections,
      port: _port,
    );
    _webViewerHandler = WebViewerHandler(
      connections: _connections,
      port: _port,
    );
  }

  Future<void> _setAudioEnabled(bool mute) async {
    notifyListeners();
  }

  Future<void> restartServer() async {
    await _restartServer();
  }

  void selectCamera(String cameraId) {
    if (_connections.containsKey(cameraId)) {
      _selectedCameraId = cameraId;
      notifyListeners();
    }
  }

  CameraConnection? getSelectedCamera() {
    if (_selectedCameraId != null) {
      return _connections[_selectedCameraId];
    }
    return null;
  }

  Future<void> _loadPort() async {
    final prefs = await SharedPreferences.getInstance();
    _port = prefs.getInt('websocket_port') ?? 8080;
    _updateHandlers();
  }

  Future<void> _savePort() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('websocket_port', _port);
  }

  Future<void> _startServer() async {
    await stopServer();
    _server = await HttpServer.bind('0.0.0.0', _port, shared: true);
    print('WebSocket server is running on ws://localhost:$_port');

    _server?.listen((HttpRequest request) async {
      // Enable CORS for web clients
      ApiHandler.setCorsHeaders(request);

      if (request.method == 'OPTIONS') {
        ApiHandler.handleOptionsRequest(request);
        return;
      }

      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocket ws = await WebSocketTransformer.upgrade(request);

        // Verificar se é um viewer web ou uma câmera
        if (request.uri.path.startsWith('/ws/viewer/') ||
            request.uri.path.startsWith('/signaling/')) {
          await _webViewerHandler.handleWebViewerSocket(ws, request);
        } else {
          await _handleCameraWebSocket(ws);
        }
      } else if (request.uri.path == '/api/cameras') {
        _apiHandler.handleCamerasApi(request);
      } else if (request.uri.path.startsWith('/api/camera/')) {
        _apiHandler.handleCameraApi(request);
      } else if (request.uri.path.startsWith('/stream/')) {
        _apiHandler.handleStreamApi(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        request.response.close();
      }
    });

    notifyListeners();
  }

  /// Método para iniciar servidor (compatibilidade)
  Future<void> startServer() async {
    await _startServer();
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server?.close(force: true);
      _server = null;
      print('WebSocket server stopped');
    }
  }

  Future<void> _restartServer() async {
    _updateHandlers();
    await _startServer();
  }

  /// Manipula conexões WebSocket de câmeras
  Future<void> _handleCameraWebSocket(WebSocket ws) async {
    print('Camera WebSocket connection established');
    final connectionId = DateTime.now().millisecondsSinceEpoch.toString();

    RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
    await remoteRenderer.initialize();

    RTCPeerConnection peerConnection = await PeerConnectionManager.initializeCameraPeerConnection(
      ws,
      remoteRenderer,
      connectionId,
      _onConnectionUpdated,
      _connections,
      _removeConnection,
    );

    // Criar nova conexão de câmera
    final cameraConnection = CameraConnection(
      id: connectionId,
      peerConnection: peerConnection,
      renderer: remoteRenderer,
      webSocket: ws,
      lastSeen: DateTime.now(),
    );

    _connections[connectionId] = cameraConnection;
    _selectedCameraId ??= connectionId;

    onCameraConnected?.call(cameraConnection);

    // Configurar listener para mensagens da câmera
    _setupCameraWebSocketListener(ws, cameraConnection, peerConnection, connectionId);

    notifyListeners();
  }

  /// Configura o listener para mensagens WebSocket da câmera
  void _setupCameraWebSocketListener(
    WebSocket ws,
    CameraConnection cameraConnection,
    RTCPeerConnection peerConnection,
    String connectionId,
  ) {
    ws.listen((message) async {
      var data = jsonDecode(message);
      cameraConnection.lastSeen = DateTime.now();

      if (data['deviceInfo'] != null) {
        cameraConnection.updateDeviceInfo(data['deviceInfo']);
        onCameraUpdated?.call(cameraConnection);
        notifyListeners();
      }

      if (data['battery'] != null) {
        cameraConnection.updateBatteryInfo(data['battery']);
        onCameraUpdated?.call(cameraConnection);
        notifyListeners();
      }

      // Processar mensagens WebRTC
      await PeerConnectionManager.handleWebRTCMessage(data, peerConnection, ws);
      notifyListeners();
    }, onDone: () {
      print('Camera WebSocket connection closed for $connectionId');
      _removeConnection(connectionId);
    }, onError: (error) {
      print('Camera WebSocket error for $connectionId: $error');
      _removeConnection(connectionId);
    });
  }

  /// Callback para atualizações de conexão
  void _onConnectionUpdated(CameraConnection? connection) {
    if (connection != null) {
      onCameraUpdated?.call(connection);
      notifyListeners();
    }
  }

  /// Remove uma conexão
  void _removeConnection(String connectionId) {
    final connection = _connections[connectionId];
    if (connection != null) {
      connection.dispose();
      _connections.remove(connectionId);

      if (_selectedCameraId == connectionId) {
        _selectedCameraId =
            _connections.keys.isNotEmpty ? _connections.keys.first : null;
      }

      // Notificar callback
      onCameraDisconnected?.call(connectionId);

      print('Connection $connectionId removed');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopServer();
    for (var connection in _connections.values) {
      connection.dispose();
    }
    _connections.clear();
    super.dispose();
  }
}
