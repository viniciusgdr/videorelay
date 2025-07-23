import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerUIConfig {
  final bool showBatteryInfo;
  final bool showDeviceInfo;
  final bool enableCameraWindows;
  final bool enableAutoSelect;
  final int maxCamerasPerRow;
  final double cameraPreviewHeight;
  final bool showConnectionStatus;
  final bool enableDarkMode;

  const ServerUIConfig({
    this.showBatteryInfo = true,
    this.showDeviceInfo = true,
    this.enableCameraWindows = true,
    this.enableAutoSelect = true,
    this.maxCamerasPerRow = 4,
    this.cameraPreviewHeight = 120.0,
    this.showConnectionStatus = true,
    this.enableDarkMode = true,
  });

  ServerUIConfig copyWith({
    bool? showBatteryInfo,
    bool? showDeviceInfo,
    bool? enableCameraWindows,
    bool? enableAutoSelect,
    int? maxCamerasPerRow,
    double? cameraPreviewHeight,
    bool? showConnectionStatus,
    bool? enableDarkMode,
  }) {
    return ServerUIConfig(
      showBatteryInfo: showBatteryInfo ?? this.showBatteryInfo,
      showDeviceInfo: showDeviceInfo ?? this.showDeviceInfo,
      enableCameraWindows: enableCameraWindows ?? this.enableCameraWindows,
      enableAutoSelect: enableAutoSelect ?? this.enableAutoSelect,
      maxCamerasPerRow: maxCamerasPerRow ?? this.maxCamerasPerRow,
      cameraPreviewHeight: cameraPreviewHeight ?? this.cameraPreviewHeight,
      showConnectionStatus: showConnectionStatus ?? this.showConnectionStatus,
      enableDarkMode: enableDarkMode ?? this.enableDarkMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showBatteryInfo': showBatteryInfo,
      'showDeviceInfo': showDeviceInfo,
      'enableCameraWindows': enableCameraWindows,
      'enableAutoSelect': enableAutoSelect,
      'maxCamerasPerRow': maxCamerasPerRow,
      'cameraPreviewHeight': cameraPreviewHeight,
      'showConnectionStatus': showConnectionStatus,
      'enableDarkMode': enableDarkMode,
    };
  }

  factory ServerUIConfig.fromJson(Map<String, dynamic> json) {
    return ServerUIConfig(
      showBatteryInfo: json['showBatteryInfo'] ?? true,
      showDeviceInfo: json['showDeviceInfo'] ?? true,
      enableCameraWindows: json['enableCameraWindows'] ?? true,
      enableAutoSelect: json['enableAutoSelect'] ?? true,
      maxCamerasPerRow: json['maxCamerasPerRow'] ?? 4,
      cameraPreviewHeight: json['cameraPreviewHeight'] ?? 120.0,
      showConnectionStatus: json['showConnectionStatus'] ?? true,
      enableDarkMode: json['enableDarkMode'] ?? true,
    );
  }
}

class ServerUIConfigManager {
  static const String _keyConfig = 'server_ui_config';

  static Future<void> saveConfig(ServerUIConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = config.toJson();
      await prefs.setString(_keyConfig, configJson.toString());
    } catch (e) {
      print('Erro ao salvar configurações de UI: $e');
    }
  }

  static Future<ServerUIConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configString = prefs.getString(_keyConfig);
      if (configString != null) {
        // Implementar parsing do JSON se necessário
      }
      return const ServerUIConfig();
    } catch (e) {
      print('Erro ao carregar configurações de UI: $e');
      return const ServerUIConfig();
    }
  }

  static Future<void> resetConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyConfig);
    } catch (e) {
      print('Erro ao resetar configurações de UI: $e');
    }
  }
}

class ServerTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
