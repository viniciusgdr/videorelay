import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CameraViewerConfig {
  // Configurações padrão - APENAS MODO PAISAGEM
  static const bool defaultPortraitMode = false; // Sempre paisagem
  static const double defaultRotationAngle = 0.0;
  static const RTCVideoViewObjectFit defaultAspectRatio = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
  static const bool defaultMirrored = false;
  static const bool defaultAutoHideControls = true;
  static const Duration autoHideDelay = Duration(seconds: 3);

  // Orientações - APENAS PAISAGEM
  static const List<DeviceOrientation> landscapeOrientations = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  // Configurações específicas por plataforma - SEMPRE PAISAGEM
  static RTCVideoViewObjectFit getDefaultAspectRatio() {
    // Para modo paisagem, preferir ajustar à tela para melhor qualidade
    return RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
  }

  static bool getDefaultPortraitMode() {
    // SEMPRE false - apenas paisagem
    return false;
  }

  static List<DeviceOrientation> getDefaultOrientations() {
    // SEMPRE paisagem
    return landscapeOrientations;
  }
}
