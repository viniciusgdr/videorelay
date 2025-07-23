import 'package:shared_preferences/shared_preferences.dart';

class StreamingConfigManager {
  static const String _keyWidth = 'streaming_width';
  static const String _keyHeight = 'streaming_height';
  static const String _keyFrameRate = 'streaming_frame_rate';
  static const String _keyMaxBitrate = 'streaming_max_bitrate';
  static const String _keyMinBitrate = 'streaming_min_bitrate';
  static const String _keyAudio = 'streaming_audio';
  static const String _keyServer = 'streaming_server';
  static const String _keyCameraType = 'streaming_camera_type';

  static Future<void> saveConfig(StreamingConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyWidth, config.width);
      await prefs.setInt(_keyHeight, config.height);
      await prefs.setInt(_keyFrameRate, config.frameRate);
      await prefs.setInt(_keyMaxBitrate, config.maxBitrate);
      await prefs.setInt(_keyMinBitrate, config.minBitrate);
      await prefs.setBool(_keyAudio, config.audio);
      await prefs.setString(_keyServer, config.server);
      await prefs.setString(_keyCameraType, config.cameraType);
    } catch (e) {
      print('Erro ao salvar configurações: $e');
    }
  }

  static Future<StreamingConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StreamingConfig(
        width: prefs.getInt(_keyWidth) ?? 1280,
        height: prefs.getInt(_keyHeight) ?? 720,
        frameRate: prefs.getInt(_keyFrameRate) ?? 30,
        maxBitrate: prefs.getInt(_keyMaxBitrate) ?? 5000000,
        minBitrate: prefs.getInt(_keyMinBitrate) ?? 3000000,
        audio: prefs.getBool(_keyAudio) ?? false,
        server: prefs.getString(_keyServer) ?? '192.168.31.202:8080',
        cameraType: prefs.getString(_keyCameraType) ?? 'back',
      );
    } catch (e) {
      print('Erro ao carregar configurações: $e');
      return const StreamingConfig();
    }
  }

  static Future<void> resetConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyWidth);
      await prefs.remove(_keyHeight);
      await prefs.remove(_keyFrameRate);
      await prefs.remove(_keyMaxBitrate);
      await prefs.remove(_keyMinBitrate);
      await prefs.remove(_keyAudio);
      await prefs.remove(_keyServer);
      await prefs.remove(_keyCameraType);
    } catch (e) {
      print('Erro ao resetar configurações: $e');
    }
  }
}

class StreamingConfig {
  final int width;
  final int height;
  final int frameRate;
  final int maxBitrate;
  final int minBitrate;
  final bool audio;
  final String server;
  final String cameraType;
  final String quality; // Novo campo para qualidade predefinida

  const StreamingConfig({
    this.width = 1920,
    this.height = 1080,
    this.frameRate = 60,
    this.maxBitrate = 8000000,
    this.minBitrate = 5000000,
    this.audio = false,
    this.server = '192.168.31.202:8080',
    this.cameraType = 'back',
    this.quality = 'FHD', // 'HD', 'FHD', '4K'
  });

  StreamingConfig copyWith({
    int? width,
    int? height,
    int? frameRate,
    int? maxBitrate,
    int? minBitrate,
    bool? audio,
    String? server,
    String? cameraType,
    String? quality,
  }) {
    return StreamingConfig(
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
      maxBitrate: maxBitrate ?? this.maxBitrate,
      minBitrate: minBitrate ?? this.minBitrate,
      audio: audio ?? this.audio,
      server: server ?? this.server,
      cameraType: cameraType ?? this.cameraType,
      quality: quality ?? this.quality,
    );
  }

  // Configurações predefinidas de qualidade
  static Map<String, StreamingConfig> qualityPresets = {
    'HD': StreamingConfig(
      width: 1280,
      height: 720,
      frameRate: 30,
      maxBitrate: 4000000,
      minBitrate: 2500000,
      quality: 'HD'
    ),
    'FHD': StreamingConfig(
      width: 1920,
      height: 1080,
      frameRate: 60,
      maxBitrate: 8000000,
      minBitrate: 5000000,
      quality: 'FHD'
    ),
    '4K': StreamingConfig(
      width: 3840,
      height: 2160,
      frameRate: 30,
      maxBitrate: 15000000,
      minBitrate: 10000000,
      quality: '4K'
    ),
  };

  StreamingConfig.fromQuality(String quality, {String? server, String? cameraType, bool? audio}) 
      : this(
          width: qualityPresets[quality]?.width ?? 1920,
          height: qualityPresets[quality]?.height ?? 1080,
          frameRate: qualityPresets[quality]?.frameRate ?? 60,
          maxBitrate: qualityPresets[quality]?.maxBitrate ?? 8000000,
          minBitrate: qualityPresets[quality]?.minBitrate ?? 5000000,
          quality: quality,
          server: server ?? '192.168.31.202:8080',
          cameraType: cameraType ?? 'back',
          audio: audio ?? false,
        );

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'frameRate': frameRate,
      'maxBitrate': maxBitrate,
      'minBitrate': minBitrate,
      'audio': audio,
      'server': server,
      'cameraType': cameraType,
      'quality': quality,
    };
  }

  @override
  String toString() {
    return 'StreamingConfig(${width}x$height, ${frameRate}fps, ${maxBitrate}bps, audio: $audio, camera: $cameraType, server: $server, quality: $quality)';
  }
}
