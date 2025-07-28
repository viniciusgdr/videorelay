import 'dart:convert';
import 'dart:io';

import '../models/camera_connection.dart';

class ApiHandler {
  final Map<String, CameraConnection> connections;
  final int port;

  ApiHandler({
    required this.connections,
    required this.port,
  });

  /// Manipula a API /api/cameras (GET)
  void handleCamerasApi(HttpRequest request) async {
    if (request.method == 'GET') {
      final cameras = connections.values.map((camera) => camera.toJson()).toList();

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'cameras': cameras,
        'totalCameras': cameras.length,
        'serverStatus': 'running',
        'port': port,
      }));
      request.response.close();
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.close();
    }
  }

  /// Manipula a API /api/camera/{id} (GET)
  void handleCameraApi(HttpRequest request) async {
    final cameraId = request.uri.pathSegments.last;
    final camera = connections[cameraId];

    if (camera == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'error': 'Camera not found'}));
      request.response.close();
      return;
    }

    if (request.method == 'GET') {
      request.response.headers.contentType = ContentType.json;
      final cameraData = camera.toJson();
      cameraData.addAll({
        'webSocketUrl': 'ws://localhost:$port/ws/$cameraId',
        'streamUrl': 'http://localhost:$port/stream/$cameraId',
      });
      
      request.response.write(jsonEncode(cameraData));
      request.response.close();
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.close();
    }
  }

  /// Manipula a API /stream/{id} (GET)
  void handleStreamApi(HttpRequest request) async {
    final cameraId = request.uri.pathSegments.last;
    final camera = connections[cameraId];

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
        'webSocketUrl': 'ws://localhost:$port/ws/viewer/$cameraId',
        'signaling': {
          'url': 'ws://localhost:$port/signaling/$cameraId',
          'protocol': 'webrtc'
        }
      }));
      request.response.close();
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.close();
    }
  }

  /// Configurar headers CORS
  static void setCorsHeaders(HttpRequest request) {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers
        .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers
        .add('Access-Control-Allow-Headers', 'Content-Type');
  }

  /// Manipula requisições OPTIONS (CORS)
  static void handleOptionsRequest(HttpRequest request) {
    setCorsHeaders(request);
    request.response.statusCode = HttpStatus.ok;
    request.response.close();
  }
}
