import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraConnection {
  final String id;
  final RTCPeerConnection peerConnection;
  final RTCVideoRenderer renderer;
  final WebSocket webSocket;
  String deviceName;
  String deviceModel;
  int batteryLevel;
  String batteryStatus;
  DateTime lastSeen;
  bool isConnected;

  CameraConnection({
    required this.id,
    required this.peerConnection,
    required this.renderer,
    required this.webSocket,
    this.deviceName = 'Dispositivo Desconhecido',
    this.deviceModel = 'Modelo Desconhecido',
    this.batteryLevel = 0,
    this.batteryStatus = 'Desconhecido',
    required this.lastSeen,
    this.isConnected = true,
  });

  // Properties para compatibilidade
  String get deviceId => id;
  bool get isCharging => batteryStatus.toLowerCase().contains('charging');

  // Método para verificar se há stream de vídeo ativo
  bool get hasVideoStream => renderer.srcObject != null;

  MediaStream? get videoStream => renderer.srcObject;
}

class WebSocketServerManager extends ChangeNotifier {
  HttpServer? _server;
  final Map<String, CameraConnection> _connections = {};
  int _port = 8080; // Porta padrão
  String? _selectedCameraId;
  bool _audioEnabled = false;

  // Callbacks para integração com a nova UI
  Function(CameraConnection)? onCameraConnected;
  Function(String)? onCameraDisconnected;
  Function(CameraConnection)? onCameraUpdated;

  WebSocketServerManager() {
    _loadPort();
  }

  int get port => _port;
  Map<String, CameraConnection> get connections => _connections;
  String? get selectedCameraId => _selectedCameraId;
  bool get audioEnabled => _audioEnabled;

  List<RTCVideoRenderer> get remoteRenderers =>
      _connections.values.map((c) => c.renderer).toList();

  List<RTCPeerConnection> get peerConnections =>
      _connections.values.map((c) => c.peerConnection).toList();

  set muteAudio(bool mute) {
    _audioEnabled = mute;
    _setAudioEnabled(mute);
  }

  Future<void> _setAudioEnabled(bool mute) async {
    notifyListeners();
  }

  set port(int newPort) {
    _port = newPort;
    _savePort();
    _restartServer();
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
    _startServer();
  }

  Future<void> _savePort() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('websocket_port', _port);
  }

  Future<void> _startServer() async {
    await stopServer();
    _server = await HttpServer.bind('0.0.0.0', _port);
    print('WebSocket server is running on ws://localhost:$_port');

    _server?.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocket ws = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(ws);
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.close();
      }
    });

    notifyListeners();
  }

  // Método para iniciar servidor (compatibilidade)
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
    await _startServer();
  }

  void _handleWebSocket(WebSocket ws) async {
    print('WebSocket connection established');
    final connectionId = DateTime.now().millisecondsSinceEpoch.toString();

    RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
    await remoteRenderer.initialize();

    RTCPeerConnection peerConnection =
        await _initializePeerConnection(ws, remoteRenderer, connectionId);

    // Criar nova conexão de câmera
    final cameraConnection = CameraConnection(
      id: connectionId,
      peerConnection: peerConnection,
      renderer: remoteRenderer,
      webSocket: ws,
      lastSeen: DateTime.now(),
    );

    _connections[connectionId] = cameraConnection;

    // Se é a primeira câmera, selecioná-la automaticamente
    _selectedCameraId ??= connectionId;

    // Notificar callback
    onCameraConnected?.call(cameraConnection);

    ws.listen((message) async {
      print('Received message: $message');
      var data = jsonDecode(message);

      // Atualizar informações da câmera
      cameraConnection.lastSeen = DateTime.now();

      if (data['deviceInfo'] != null) {
        cameraConnection.deviceName =
            data['deviceInfo']['name'] ?? 'Dispositivo Desconhecido';
        cameraConnection.deviceModel =
            data['deviceInfo']['model'] ?? 'Modelo Desconhecido';
        onCameraUpdated?.call(cameraConnection);
        notifyListeners();
      }

      if (data['battery'] != null) {
        cameraConnection.batteryLevel = data['battery']['level'] ?? 0;
        cameraConnection.batteryStatus =
            data['battery']['status'] ?? 'Desconhecido';
        onCameraUpdated?.call(cameraConnection);
        notifyListeners();
      }

      if (data['sdp'] != null) {
        await peerConnection.setRemoteDescription(
            RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
        var answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        ws.add(jsonEncode({'sdp': answer.toMap()}));
        notifyListeners();
      } else if (data['candidate'] != null) {
        await peerConnection.addCandidate(RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        ));
        notifyListeners();
      }
    }, onDone: () {
      print('WebSocket connection closed for $connectionId');
      _removeConnection(connectionId);
    }, onError: (error) {
      print('WebSocket error for $connectionId: $error');
      _removeConnection(connectionId);
    });

    notifyListeners();
  }

  Future<RTCPeerConnection> _initializePeerConnection(WebSocket ws,
      RTCVideoRenderer remoteRenderer, String connectionId) async {
    RTCPeerConnection peerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
    });

    print('Peer connection initialized for $connectionId');
    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      ws.add(jsonEncode({'candidate': candidate.toMap()}));
    };

    peerConnection.onTrack = (RTCTrackEvent event) {
      print('Received remote track: ${event.track.kind} for $connectionId');
      if (event.track.kind == 'video') {
        remoteRenderer.srcObject = event.streams[0];
        // Notificar que o stream foi atualizado
        final connection = _connections[connectionId];
        if (connection != null) {
          onCameraUpdated?.call(connection);
          notifyListeners();
        }
      }
    };

    peerConnection.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state for $connectionId: $state');
      final connection = _connections[connectionId];
      if (connection != null) {
        connection.isConnected =
            state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

        // Só remove se realmente falhou ou foi fechado pelo usuário
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          // Aguardar um pouco antes de remover para permitir reconexões
          Timer(const Duration(seconds: 5), () {
            final currentConnection = _connections[connectionId];
            if (currentConnection != null &&
                !currentConnection.isConnected &&
                (currentConnection.peerConnection.connectionState ==
                        RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                    currentConnection.peerConnection.connectionState ==
                        RTCPeerConnectionState.RTCPeerConnectionStateClosed)) {
              _removeConnection(connectionId);
            }
          });
        }

        notifyListeners();
      }
    };

    return peerConnection;
  }

  void _removeConnection(String connectionId) {
    final connection = _connections[connectionId];
    if (connection != null) {
      connection.peerConnection.dispose();
      connection.renderer.dispose();
      connection.webSocket.close();

      _connections.remove(connectionId);

      // Se a câmera removida era a selecionada, selecionar outra
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
      connection.peerConnection.dispose();
      connection.renderer.dispose();
      connection.webSocket.close();
    }
    _connections.clear();
    super.dispose();
  }
}
