

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streameasy/src/components/webrtc_to_virtual_cam.dart';

class WebSocketServerManager extends ChangeNotifier {
  HttpServer? _server;
  List<RTCPeerConnection> peerConnections = [];
  List<RTCVideoRenderer> remoteRenderers = [];
  List<WebRTCtoVirtualCam> virtualCams = [];
  int _port = 8080; // Porta padrão
  int _selectedCameraIndex = 0;
  bool _audioEnabled = false;

  WebSocketServerManager() {
    _loadPort();
  }

  int get port => _port;
  int get selectedCameraIndex => _selectedCameraIndex;
  bool get audioEnabled => _audioEnabled;
  
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

  set selectedCameraIndex(int index) {
    _selectedCameraIndex = index;
    notifyListeners();
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
    RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
    await remoteRenderer.initialize();

    RTCPeerConnection peerConnection =
        await _initializePeerConnection(ws, remoteRenderer);

    ws.listen((message) async {
      print('Received message: $message');
      var data = jsonDecode(message);

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
      _removeConnection(peerConnection, remoteRenderer);
    }, onError: (error) {
      print('WebSocket error: $error');
      _removeConnection(peerConnection, remoteRenderer);
    });

    peerConnections.add(peerConnection);
    remoteRenderers.add(remoteRenderer);

    notifyListeners();
  }

  Future<RTCPeerConnection> _initializePeerConnection(
      WebSocket ws, RTCVideoRenderer remoteRenderer) async {
    RTCPeerConnection peerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
    });

    print('Peer connection initialized');
    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      ws.add(jsonEncode({'candidate': candidate.toMap()}));
    };

    peerConnection.onTrack = (RTCTrackEvent event) {
      print('Received remote track: ${event.track.kind}');
      if (event.track.kind == 'video') {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    peerConnection.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _removeConnection(peerConnection, remoteRenderer);
      }
    };

    return peerConnection;
  }

  void _removeConnection(
      RTCPeerConnection peerConnection, RTCVideoRenderer remoteRenderer) {
    peerConnection.dispose();
    remoteRenderer.dispose();

    peerConnections.remove(peerConnection);
    remoteRenderers.remove(remoteRenderer);

    notifyListeners(); // Notificar listeners quando uma conexão é removida
  }

  @override
  void dispose() {
    stopServer();
    for (var pc in peerConnections) {
      pc.dispose();
    }
    for (var renderer in remoteRenderers) {
      renderer.dispose();
    }
    super.dispose();
  }
}