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
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers
          .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers
          .add('Access-Control-Allow-Headers', 'Content-Type');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        request.response.close();
        return;
      }

      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocket ws = await WebSocketTransformer.upgrade(request);

        // Verificar se é um viewer web ou uma câmera
        if (request.uri.path.startsWith('/ws/viewer/') ||
            request.uri.path.startsWith('/signaling/')) {
          _handleWebViewerSocket(ws, request);
        } else {
          _handleWebSocket(ws);
        }
      } else if (request.uri.path == '/api/cameras') {
        _handleCamerasApi(request);
      } else if (request.uri.path.startsWith('/api/camera/')) {
        _handleCameraApi(request);
      } else if (request.uri.path.startsWith('/stream/')) {
        _handleStreamApi(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
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

    _selectedCameraId ??= connectionId;

    onCameraConnected?.call(cameraConnection);

    ws.listen((message) async {
      var data = jsonDecode(message);

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
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      ws.add(jsonEncode({'candidate': candidate.toMap()}));
    };

    peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        remoteRenderer.srcObject = event.streams[0];
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

  void _handleCamerasApi(HttpRequest request) async {
    if (request.method == 'GET') {
      final cameras = _connections.values
          .map((camera) => {
                'id': camera.id,
                'deviceId': camera.deviceId,
                'deviceName': camera.deviceName,
                'deviceModel': camera.deviceModel,
                'batteryLevel': camera.batteryLevel,
                'batteryStatus': camera.batteryStatus,
                'isConnected': camera.isConnected,
                'isCharging': camera.isCharging,
                'hasVideoStream': camera.hasVideoStream,
                'lastSeen': camera.lastSeen.toIso8601String(),
              })
          .toList();

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'cameras': cameras,
        'totalCameras': cameras.length,
        'serverStatus': 'running',
        'port': _port,
      }));
      request.response.close();
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.close();
    }
  }

  void _handleCameraApi(HttpRequest request) async {
    final cameraId = request.uri.pathSegments.last;
    final camera = _connections[cameraId];

    if (camera == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'error': 'Camera not found'}));
      request.response.close();
      return;
    }

    if (request.method == 'GET') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'id': camera.id,
        'deviceId': camera.deviceId,
        'deviceName': camera.deviceName,
        'deviceModel': camera.deviceModel,
        'batteryLevel': camera.batteryLevel,
        'batteryStatus': camera.batteryStatus,
        'isConnected': camera.isConnected,
        'isCharging': camera.isCharging,
        'hasVideoStream': camera.hasVideoStream,
        'lastSeen': camera.lastSeen.toIso8601String(),
        'webSocketUrl': 'ws://localhost:$_port/ws/$cameraId',
        'streamUrl': 'http://localhost:$_port/stream/$cameraId',
      }));
      request.response.close();
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.close();
    }
  }

  void _handleStreamApi(HttpRequest request) async {
    final cameraId = request.uri.pathSegments.last;
    final camera = _connections[cameraId];

    if (camera == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Camera not found');
      request.response.close();
      return;
    }

    if (request.method == 'GET') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'cameraId': cameraId,
        'deviceName': camera.deviceName,
        'hasStream': camera.hasVideoStream,
        'webSocketUrl': 'ws://localhost:$_port/ws/viewer/$cameraId',
        'signaling': {
          'url': 'ws://localhost:$_port/signaling/$cameraId',
          'protocol': 'webrtc'
        }
      }));
      request.response.close();
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.close();
    }
  }

  void _handleWebViewerSocket(WebSocket ws, HttpRequest request) async {
    print('Web viewer WebSocket connection established');

    // Extrair ID da câmera da URL
    String? cameraId;
    if (request.uri.path.startsWith('/ws/viewer/')) {
      cameraId = request.uri.pathSegments.last;
    } else if (request.uri.path.startsWith('/signaling/')) {
      cameraId = request.uri.pathSegments.last;
    }
    if (cameraId == null || !_connections.containsKey(cameraId)) {
      ws.add(jsonEncode({'error': 'Camera not found', 'cameraId': cameraId}));
      ws.close();
      return;
    }

    final camera = _connections[cameraId]!;

    if (!camera.hasVideoStream) {
      int attempts = 0;
      while (!camera.hasVideoStream && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (!camera.hasVideoStream) {
        ws.add(jsonEncode({'error': 'Camera stream not available'}));
        ws.close();
        return;
      }
    }

    RTCVideoRenderer viewerRenderer = RTCVideoRenderer();
    await viewerRenderer.initialize();

    RTCPeerConnection viewerPeerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });

    // Configurar callbacks do peer connection do viewer
    viewerPeerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (ws.readyState == WebSocket.open) {
        ws.add(jsonEncode({
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid
        }));
      }
    };

    ws.listen((message) async {
      try {
        final data = jsonDecode(message);
        print('Web viewer message: ${data.keys.join(", ")}');

        if (data['sdp'] != null) {
          print('Viewer SDP received: ${data['sdp']['type']}');
          await viewerPeerConnection.setRemoteDescription(
              RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));

          if (data['sdp']['type'] == 'offer') {
            if (camera.renderer.srcObject != null) {
              final stream = camera.renderer.srcObject!;
              final videoTracks = stream.getVideoTracks();
              final audioTracks = stream.getAudioTracks();

              if (videoTracks.isNotEmpty) {
                for (final track in videoTracks) {
                  await viewerPeerConnection.addTrack(track, stream);
                }
              }
              if (audioTracks.isNotEmpty) {
                for (final track in audioTracks) {
                  await viewerPeerConnection.addTrack(track, stream);
                }
              }
            } else {
              ws.add(jsonEncode({'error': 'Camera stream not available'}));
            }

            final answer = await viewerPeerConnection.createAnswer();
            await viewerPeerConnection.setLocalDescription(answer);

            ws.add(jsonEncode({
              'sdp': {'type': answer.type, 'sdp': answer.sdp}
            }));
          }
        } else if (data['candidate'] != null) {
          await viewerPeerConnection.addCandidate(RTCIceCandidate(
              data['candidate']['candidate'],
              data['candidate']['sdpMid'],
              data['candidate']['sdpMLineIndex']));
        }
      } catch (e) {
        print('Error handling web viewer message: $e');
      }
    }, onDone: () {
      print('Web viewer disconnected from camera $cameraId');
      viewerPeerConnection.dispose();
      viewerRenderer.dispose();
    }, onError: (error) {
      print('Web viewer WebSocket error: $error');
      viewerPeerConnection.dispose();
      viewerRenderer.dispose();
    });

    ws.add(jsonEncode({
      'type': 'camera_info',
      'camera': {
        'id': camera.id,
        'deviceName': camera.deviceName,
        'deviceModel': camera.deviceModel,
        'batteryLevel': camera.batteryLevel,
        'isCharging': camera.isCharging,
      }
    }));
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
