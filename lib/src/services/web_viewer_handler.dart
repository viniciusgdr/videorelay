import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/camera_connection.dart';
import 'peer_connection_manager.dart';

class WebViewerHandler {
  final Map<String, CameraConnection> connections;
  final int port;

  WebViewerHandler({
    required this.connections,
    required this.port,
  });

  /// Manipula conexões WebSocket de viewers web
  Future<void> handleWebViewerSocket(WebSocket ws, HttpRequest request) async {
    print('Web viewer WebSocket connection established');

    // Extrair ID da câmera da URL
    String? cameraId = _extractCameraId(request);
    
    if (cameraId == null || !connections.containsKey(cameraId)) {
      ws.add(jsonEncode({'error': 'Camera not found', 'cameraId': cameraId}));
      ws.close();
      return;
    }

    final camera = connections[cameraId]!;

    // Aguardar stream da câmera estar disponível
    if (!await _waitForCameraStream(camera, ws)) {
      return;
    }

    // Inicializar recursos para o viewer
    RTCVideoRenderer viewerRenderer = RTCVideoRenderer();
    await viewerRenderer.initialize();

    RTCPeerConnection viewerPeerConnection = 
        await PeerConnectionManager.initializeViewerPeerConnection(ws, camera);

    // Configurar listeners do WebSocket
    _setupWebSocketListeners(ws, viewerPeerConnection, camera, viewerRenderer, cameraId);

    // Enviar informações da câmera para o viewer
    _sendCameraInfo(ws, camera);
  }

  /// Extrai o ID da câmera da URL
  String? _extractCameraId(HttpRequest request) {
    if (request.uri.path.startsWith('/ws/viewer/')) {
      return request.uri.pathSegments.last;
    } else if (request.uri.path.startsWith('/signaling/')) {
      return request.uri.pathSegments.last;
    }
    return null;
  }

  /// Aguarda o stream da câmera estar disponível
  Future<bool> _waitForCameraStream(CameraConnection camera, WebSocket ws) async {
    if (!camera.hasVideoStream) {
      int attempts = 0;
      while (!camera.hasVideoStream && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (!camera.hasVideoStream) {
        ws.add(jsonEncode({'error': 'Camera stream not available'}));
        ws.close();
        return false;
      }
    }
    return true;
  }

  /// Configura os listeners do WebSocket para o viewer
  void _setupWebSocketListeners(
    WebSocket ws,
    RTCPeerConnection viewerPeerConnection,
    CameraConnection camera,
    RTCVideoRenderer viewerRenderer,
    String cameraId,
  ) {
    ws.listen((message) async {
      try {
        final data = jsonDecode(message);
        print('Web viewer message: ${data.keys.join(", ")}');

        if (data['sdp'] != null) {
          await _handleViewerSdp(data, viewerPeerConnection, camera, ws);
        } else if (data['candidate'] != null) {
          await _handleViewerCandidate(data, viewerPeerConnection);
        }
      } catch (e) {
        print('Error handling web viewer message: $e');
      }
    }, onDone: () {
      print('Web viewer disconnected from camera $cameraId');
      _cleanupViewerResources(viewerPeerConnection, viewerRenderer);
    }, onError: (error) {
      print('Web viewer WebSocket error: $error');
      _cleanupViewerResources(viewerPeerConnection, viewerRenderer);
    });
  }

  /// Manipula mensagens SDP do viewer
  Future<void> _handleViewerSdp(
    Map<String, dynamic> data,
    RTCPeerConnection viewerPeerConnection,
    CameraConnection camera,
    WebSocket ws,
  ) async {
    print('Viewer SDP received: ${data['sdp']['type']}');
    await viewerPeerConnection.setRemoteDescription(
        RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));

    if (data['sdp']['type'] == 'offer') {
      if (camera.renderer.srcObject != null) {
        await PeerConnectionManager.addCameraTracksToViewer(
          viewerPeerConnection, 
          camera
        );
      } else {
        ws.add(jsonEncode({'error': 'Camera stream not available'}));
        return;
      }

      final answer = await viewerPeerConnection.createAnswer();
      await viewerPeerConnection.setLocalDescription(answer);

      ws.add(jsonEncode({
        'sdp': {'type': answer.type, 'sdp': answer.sdp}
      }));
    }
  }

  /// Manipula candidatos ICE do viewer
  Future<void> _handleViewerCandidate(
    Map<String, dynamic> data,
    RTCPeerConnection viewerPeerConnection,
  ) async {
    await viewerPeerConnection.addCandidate(RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex']));
  }

  /// Envia informações da câmera para o viewer
  void _sendCameraInfo(WebSocket ws, CameraConnection camera) {
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

  /// Limpa os recursos do viewer
  void _cleanupViewerResources(
    RTCPeerConnection viewerPeerConnection,
    RTCVideoRenderer viewerRenderer,
  ) {
    viewerPeerConnection.dispose();
    viewerRenderer.dispose();
  }
}
