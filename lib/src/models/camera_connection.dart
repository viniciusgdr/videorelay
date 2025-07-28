import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

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

  /// Converte a conexão para um mapa JSON para APIs
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceModel': deviceModel,
      'batteryLevel': batteryLevel,
      'batteryStatus': batteryStatus,
      'isConnected': isConnected,
      'isCharging': isCharging,
      'hasVideoStream': hasVideoStream,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  /// Atualiza as informações do dispositivo
  void updateDeviceInfo(Map<String, dynamic> deviceInfo) {
    deviceName = deviceInfo['name'] ?? deviceName;
    deviceModel = deviceInfo['model'] ?? deviceModel;
    lastSeen = DateTime.now();
  }

  /// Atualiza as informações da bateria
  void updateBatteryInfo(Map<String, dynamic> batteryInfo) {
    batteryLevel = batteryInfo['level'] ?? batteryLevel;
    batteryStatus = batteryInfo['status'] ?? batteryStatus;
    lastSeen = DateTime.now();
  }

  /// Libera os recursos da conexão
  void dispose() {
    peerConnection.dispose();
    renderer.dispose();
    webSocket.close();
  }
}
