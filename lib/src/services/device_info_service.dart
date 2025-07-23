import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoService {
  static final Battery _battery = Battery();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      String deviceName = 'Dispositivo Desconhecido';
      String deviceModel = 'Modelo Desconhecido';
      String osVersion = 'Versão Desconhecida';

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        deviceName = androidInfo.model;
        deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        deviceName = iosInfo.name;
        deviceModel = iosInfo.model;
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      }

      return {
        'name': deviceName,
        'model': deviceModel,
        'osVersion': osVersion,
        'platform': Platform.operatingSystem,
      };
    } catch (e) {
      return {
        'name': 'Dispositivo Desconhecido',
        'model': 'Erro ao obter informações',
        'osVersion': 'Desconhecida',
        'platform': Platform.operatingSystem,
      };
    }
  }

  static Future<Map<String, dynamic>> getBatteryInfo() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;
      
      String status = 'Desconhecido';
      switch (batteryState) {
        case BatteryState.charging:
          status = 'Carregando';
          break;
        case BatteryState.discharging:
          status = 'Descarregando';
          break;
        case BatteryState.full:
          status = 'Completa';
          break;
        case BatteryState.connectedNotCharging:
          status = 'Conectado (não carregando)';
          break;
        case BatteryState.unknown:
          status = 'Desconhecido';
          break;
      }

      return {
        'level': batteryLevel,
        'status': status,
        'state': batteryState.toString(),
      };
    } catch (e) {
      return {
        'level': 0,
        'status': 'Erro ao obter informações',
        'state': 'unknown',
      };
    }
  }

  static Stream<BatteryState> get batteryStateStream => _battery.onBatteryStateChanged;
}

class BatteryMonitor {
  Timer? _timer;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  final Function(Map<String, dynamic>) onBatteryUpdate;
  final Function(Map<String, dynamic>) onDeviceInfoUpdate;

  BatteryMonitor({
    required this.onBatteryUpdate,
    required this.onDeviceInfoUpdate,
  });

  void startMonitoring() {
    // Enviar informações do dispositivo uma vez
    _sendDeviceInfo();
    
    // Enviar informações de bateria a cada minuto
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _sendBatteryInfo();
    });

    // Monitorar mudanças de estado da bateria em tempo real
    _batteryStateSubscription = DeviceInfoService.batteryStateStream.listen((state) {
      _sendBatteryInfo();
    });

    // Enviar informações iniciais de bateria
    _sendBatteryInfo();
  }

  void stopMonitoring() {
    _timer?.cancel();
    _batteryStateSubscription?.cancel();
    _timer = null;
    _batteryStateSubscription = null;
  }

  Future<void> _sendDeviceInfo() async {
    final deviceInfo = await DeviceInfoService.getDeviceInfo();
    onDeviceInfoUpdate(deviceInfo);
  }

  Future<void> _sendBatteryInfo() async {
    final batteryInfo = await DeviceInfoService.getBatteryInfo();
    onBatteryUpdate(batteryInfo);
  }

  void dispose() {
    stopMonitoring();
  }
}
