import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'src/config/streaming_config.dart';
import 'src/utils/error_handler.dart';
import 'src/services/device_info_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Forçar orientação paisagem apenas
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamEasy - Camera Streaming',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const PermissionScreen(),
    );
  }
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isCheckingPermissions = true;
  String _permissionStatus = 'Verificando permissões...';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      setState(() {
        _permissionStatus = 'Verificando permissão da câmera...';
      });

      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;

      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        _navigateToCameraScreen();
        return;
      }

      setState(() {
        _isCheckingPermissions = false;
        _permissionStatus = 'Permissões necessárias: Câmera e Microfone';
      });
    } catch (e) {
      setState(() {
        _isCheckingPermissions = false;
        _permissionStatus = 'Erro ao verificar permissões: $e';
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      setState(() {
        _isCheckingPermissions = true;
        _permissionStatus = 'Solicitando permissões...';
      });

      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera]!.isGranted && 
          statuses[Permission.microphone]!.isGranted) {
        _navigateToCameraScreen();
      } else {
        setState(() {
          _isCheckingPermissions = false;
          _permissionStatus = 'Permissões negadas. O app precisa de acesso à câmera e microfone.';
        });
      }
    } catch (e) {
      setState(() {
        _isCheckingPermissions = false;
        _permissionStatus = 'Erro ao solicitar permissões: $e';
      });
    }
  }

  void _navigateToCameraScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CameraStreamingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StreamEasy'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam,
                size: 100,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 32),
              Text(
                _permissionStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              if (_isCheckingPermissions)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _requestPermissions,
                  child: const Text('Conceder Permissões'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraStreamingPage extends StatefulWidget {
  const CameraStreamingPage({super.key});

  @override
  State<CameraStreamingPage> createState() => _CameraStreamingPageState();
}

class _CameraStreamingPageState extends State<CameraStreamingPage> {
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _channel;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  
  StreamingConfig _config = const StreamingConfig();
  BatteryMonitor? _batteryMonitor;
  
  bool _isStreaming = false;
  bool _isConnecting = false;
  String _connectionStatus = 'Desconectado';
  String _errorMessage = '';
  List<MediaDeviceInfo> _availableCameras = [];
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 10;

  @override
  void initState() {
    super.initState();
    // Garantir orientação paisagem
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeRenderer();
    _loadConfiguration();
    _loadAvailableCameras();
  }

  Future<void> _loadConfiguration() async {
    try {
      final savedConfig = await StreamingConfigManager.loadConfig();
      setState(() {
        _config = savedConfig;
      });
      ErrorHandler.logInfo('Configurações carregadas: ${_config.toString()}');
    } catch (e) {
      ErrorHandler.logError('Erro ao carregar configurações', error: e);
    }
  }

  Future<void> _initializeRenderer() async {
    try {
      await _localRenderer.initialize();
      ErrorHandler.logInfo('Renderer inicializado com sucesso');
    } catch (e) {
      final errorMessage = ErrorHandler.getErrorMessage(e);
      _setError('Erro ao inicializar renderizador: $errorMessage');
      ErrorHandler.logError('Erro ao inicializar renderizador', error: e);
    }
  }

  Future<void> _loadAvailableCameras() async {
    try {
      _availableCameras = await Helper.cameras;
      setState(() {});
      ErrorHandler.logInfo('${_availableCameras.length} câmeras encontradas');
    } catch (e) {
      final errorMessage = ErrorHandler.getCameraErrorMessage(e);
      _setError('Erro ao carregar câmeras: $errorMessage');
      ErrorHandler.logError('Erro ao carregar câmeras', error: e);
    }
  }

  Future<MediaStream> _getUserMedia() async {
    try {
      if (_availableCameras.isEmpty) {
        throw Exception('Nenhuma câmera disponível');
      }

      // Selecionar câmera baseada na configuração
      MediaDeviceInfo? selectedCamera = _availableCameras.firstWhere(
        (camera) => camera.label.toLowerCase().contains(_config.cameraType),
        orElse: () => _availableCameras.first,
      );

      ErrorHandler.logInfo('Selecionando câmera: ${selectedCamera.label} (${selectedCamera.deviceId})');

      final Map<String, dynamic> mediaConstraints = {
        'audio': _config.audio,
        'video': {
          'deviceId': selectedCamera.deviceId,
          'width': {'ideal': _config.width, 'min': _config.width ~/ 2},
          'height': {'ideal': _config.height, 'min': _config.height ~/ 2},
          'frameRate': {'ideal': _config.frameRate, 'min': 15, 'max': _config.frameRate},
          'facingMode': _config.cameraType == 'back' ? 'environment' : 'user',
          'aspectRatio': 1.7777777778, // 16:9
        },
      };

      ErrorHandler.logInfo('Configurações de mídia: $mediaConstraints');
      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      ErrorHandler.logInfo('Stream de câmera obtido com sucesso');
      return stream;
    } catch (e) {
      final errorMessage = ErrorHandler.getCameraErrorMessage(e);
      ErrorHandler.logError('Erro ao acessar câmera', error: e);
      throw Exception(errorMessage);
    }
  }

  Future<void> _initializeWebRTC() async {
    try {
      setState(() {
        _isConnecting = true;
        _connectionStatus = 'Inicializando câmera...';
        _errorMessage = '';
      });

      _localStream = await _getUserMedia();

      setState(() {
        _localRenderer.srcObject = _localStream;
        _connectionStatus = 'Criando conexão WebRTC...';
      });

      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });

      ErrorHandler.logInfo('Conexão WebRTC criada');
      _applyBandwidthConstraints();

      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
        ErrorHandler.logInfo('Track adicionado: ${track.kind}');
      });

      _setupPeerConnectionCallbacks();

      setState(() {
        _connectionStatus = 'Criando oferta...';
      });

      RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': false,
        'offerToReceiveAudio': _config.audio,
      });
      
      await _peerConnection!.setLocalDescription(offer);
      ErrorHandler.logInfo('Oferta criada e definida localmente');

      if (_channel != null) {
        _channel!.sink.add(jsonEncode({
          'sdp': offer.toMap(),
        }));
        
        setState(() {
          _connectionStatus = 'Enviando oferta...';
        });
        ErrorHandler.logInfo('Oferta enviada via WebSocket');
      }
    } catch (e) {
      final errorMessage = ErrorHandler.getWebRTCErrorMessage(e);
      _setError('Erro ao inicializar WebRTC: $errorMessage');
      ErrorHandler.logError('Erro ao inicializar WebRTC', error: e);
      _stopStreaming();
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _setupPeerConnectionCallbacks() {
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({
          'candidate': candidate.toMap(),
        }));
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      setState(() {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            _connectionStatus = 'Conectando...';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _connectionStatus = 'Conectado';
            _reconnectAttempts = 0;
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _connectionStatus = 'Desconectado';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _connectionStatus = 'Falha na conexão';
            _attemptReconnect();
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _connectionStatus = 'Conexão fechada';
            break;
          default:
            _connectionStatus = 'Estado desconhecido';
        }
      });
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE Connection State: $state');
    };
  }

  void _applyBandwidthConstraints() {
    _peerConnection?.getSenders().then((senders) {
      for (var sender in senders) {
        if (sender.track?.kind == 'video') {
          RTCRtpParameters parameters = sender.parameters;
          parameters.encodings = [
            RTCRtpEncoding(
              maxBitrate: _config.maxBitrate,
              minBitrate: _config.minBitrate,
              maxFramerate: _config.frameRate,
              scaleResolutionDownBy: _config.width / _config.height,
            ),
          ];
          sender.setParameters(parameters);
        }
      }
    });
  }

  void _startWebSocketConnection() {
    try {
      setState(() {
        _isConnecting = true;
        _connectionStatus = 'Conectando ao servidor...';
        _errorMessage = '';
      });

      final wsUrl = 'ws://${_config.server}';
      ErrorHandler.logInfo('Conectando ao WebSocket: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) async {
          try {
            var data = jsonDecode(message);
            ErrorHandler.logInfo('Mensagem WebSocket recebida: ${data.keys.join(', ')}');

            if (data['sdp'] != null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type'])
              );
              ErrorHandler.logInfo('Descrição remota definida');
            } else if (data['candidate'] != null) {
              await _peerConnection!.addCandidate(RTCIceCandidate(
                data['candidate']['candidate'],
                data['candidate']['sdpMid'],
                data['candidate']['sdpMLineIndex']
              ));
              ErrorHandler.logInfo('Candidato ICE adicionado');
            }
          } catch (e) {
            final errorMessage = ErrorHandler.getWebRTCErrorMessage(e);
            _setError('Erro ao processar mensagem WebSocket: $errorMessage');
            ErrorHandler.logError('Erro ao processar mensagem WebSocket', error: e);
          }
        },
        onError: (error) {
          final errorMessage = ErrorHandler.getWebSocketErrorMessage(error);
          _setError('Erro WebSocket: $errorMessage');
          ErrorHandler.logError('Erro WebSocket', error: error);
          
          if (_isStreaming) {
            _attemptReconnect();
          }
        },
        onDone: () {
          setState(() {
            _connectionStatus = 'Conexão WebSocket fechada';
          });
          ErrorHandler.logWarning('Conexão WebSocket fechada');
          
          if (_isStreaming) {
            _attemptReconnect();
          }
        },
      );

      _channel?.ready.then((_) {
        setState(() {
          _connectionStatus = 'Conectado ao servidor';
        });
        ErrorHandler.logInfo('WebSocket conectado com sucesso');
        
        // Iniciar monitoramento de bateria
        _batteryMonitor = BatteryMonitor(
          onBatteryUpdate: (batteryInfo) {
            if (_channel != null) {
              _channel!.sink.add(jsonEncode({
                'battery': batteryInfo,
              }));
              ErrorHandler.logInfo('Informações de bateria enviadas: ${batteryInfo['level']}% - ${batteryInfo['status']}');
            }
          },
          onDeviceInfoUpdate: (deviceInfo) {
            if (_channel != null) {
              _channel!.sink.add(jsonEncode({
                'deviceInfo': deviceInfo,
              }));
              ErrorHandler.logInfo('Informações do dispositivo enviadas: ${deviceInfo['name']}');
            }
          },
        );
        _batteryMonitor?.startMonitoring();
        
        _initializeWebRTC();
      }).catchError((error) {
        final errorMessage = ErrorHandler.getWebSocketErrorMessage(error);
        _setError('Erro ao conectar WebSocket: $errorMessage');
        ErrorHandler.logError('Erro ao conectar WebSocket', error: error);
        _attemptReconnect();
      });

    } catch (e) {
      final errorMessage = ErrorHandler.getWebSocketErrorMessage(e);
      _setError('Erro ao iniciar conexão WebSocket: $errorMessage');
      ErrorHandler.logError('Erro ao iniciar conexão WebSocket', error: e);
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _attemptReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts || !_isStreaming) {
      if (_reconnectAttempts >= maxReconnectAttempts) {
        _setError('Máximo de tentativas de reconexão atingido');
      }
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 3 * (_reconnectAttempts + 1)), () {
      if (!_isStreaming || _reconnectAttempts >= maxReconnectAttempts) {
        return;
      }
      
      _reconnectAttempts++;
      
      setState(() {
        _connectionStatus = 'Reconectando... ($_reconnectAttempts/$maxReconnectAttempts)';
      });
      
      // Limpar conexões antigas
      _peerConnection?.close();
      _channel?.sink.close();
      
      Timer(const Duration(milliseconds: 500), () {
        if (_isStreaming) {
          _startWebSocketConnection();
        }
      });
    });
  }

  void _startStreaming() {
    if (_isStreaming || _isConnecting) {
      return;
    }
    
    setState(() {
      _isStreaming = true;
      _isConnecting = true;
      _errorMessage = '';
      _connectionStatus = 'Iniciando...';
    });
    
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    
    _startWebSocketConnection();
  }

  void _stopStreaming() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0; // Reset attempts quando parar manualmente
    _batteryMonitor?.stopMonitoring();
    _peerConnection?.close();
    _localStream?.dispose();
    _channel?.sink.close();
    
    setState(() {
      _isStreaming = false;
      _isConnecting = false;
      _connectionStatus = 'Parado pelo usuário';
      _localRenderer.srcObject = null;
      _localStream = null;
      _peerConnection = null;
      _channel = null;
    });
  }

  void _setError(String error) {
    ErrorHandler.logError(error);
    setState(() {
      _errorMessage = error;
      _connectionStatus = 'Erro';
    });
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => StreamingConfigDialog(
        config: _config,
        availableCameras: _availableCameras,
        onConfigChanged: (newConfig) async {
          setState(() {
            _config = newConfig;
          });
          
          try {
            await StreamingConfigManager.saveConfig(newConfig);
            ErrorHandler.logInfo('Configurações salvas: ${newConfig.toString()}');
          } catch (e) {
            ErrorHandler.logError('Erro ao salvar configurações', error: e);
          }
          
          if (_isStreaming) {
            _stopStreaming();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _batteryMonitor?.dispose();
    _stopStreaming();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StreamEasy'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigDialog,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: _localStream != null
                ? RTCVideoView(
                    _localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Câmera não iniciada',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
          
          // Control panel - painel lateral
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: _errorMessage.isNotEmpty 
                      ? Colors.red.withOpacity(0.2)
                      : _isStreaming 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isStreaming ? Icons.circle : Icons.circle_outlined,
                              color: _isStreaming ? Colors.green : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Status: $_connectionStatus',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Erro: $_errorMessage',
                            style: const TextStyle(color: Colors.red, fontSize: 10),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Servidor: ${_config.server}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          'Resolução: ${_config.width}x${_config.height}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          'FPS: ${_config.frameRate}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  
                  // Espaçador
                  const Spacer(),
                  
                  // Controls
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isConnecting ? null : (_isStreaming ? _stopStreaming : _startStreaming),
                          icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                          label: Text(_isConnecting 
                            ? 'Conectando...' 
                            : (_isStreaming ? 'Parar' : 'Iniciar')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isStreaming ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _showConfigDialog,
                          icon: const Icon(Icons.tune),
                          label: const Text('Configurar'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StreamingConfigDialog extends StatefulWidget {
  final StreamingConfig config;
  final List<MediaDeviceInfo> availableCameras;
  final Function(StreamingConfig) onConfigChanged;

  const StreamingConfigDialog({
    super.key,
    required this.config,
    required this.availableCameras,
    required this.onConfigChanged,
  });

  @override
  State<StreamingConfigDialog> createState() => _StreamingConfigDialogState();
}

class _StreamingConfigDialogState extends State<StreamingConfigDialog> {
  late StreamingConfig _config;
  final _serverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _serverController.text = _config.server;
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurações de Streaming'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Servidor
            TextField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: 'Servidor WebSocket',
                hintText: '192.168.1.100:8080',
              ),
              onChanged: (value) {
                _config = _config.copyWith(server: value);
              },
            ),
            const SizedBox(height: 16),

            // Resolução
            DropdownButtonFormField<String>(
              value: '${_config.width}x${_config.height}',
              decoration: const InputDecoration(labelText: 'Resolução'),
              items: const [
                DropdownMenuItem(value: '640x480', child: Text('640x480 (VGA)')),
                DropdownMenuItem(value: '1280x720', child: Text('1280x720 (HD)')),
                DropdownMenuItem(value: '1920x1080', child: Text('1920x1080 (Full HD)')),
                DropdownMenuItem(value: '3840x2160', child: Text('3840x2160 (4K)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  final parts = value.split('x');
                  _config = _config.copyWith(
                    width: int.parse(parts[0]),
                    height: int.parse(parts[1]),
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            // Frame Rate
            DropdownButtonFormField<int>(
              value: _config.frameRate,
              decoration: const InputDecoration(labelText: 'Frame Rate (FPS)'),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 FPS')),
                DropdownMenuItem(value: 24, child: Text('24 FPS')),
                DropdownMenuItem(value: 30, child: Text('30 FPS')),
                DropdownMenuItem(value: 60, child: Text('60 FPS')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _config = _config.copyWith(frameRate: value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Bitrate
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _config.maxBitrate,
                    decoration: const InputDecoration(labelText: 'Bitrate Máximo'),
                    items: const [
                      DropdownMenuItem(value: 1000000, child: Text('1 Mbps')),
                      DropdownMenuItem(value: 2000000, child: Text('2 Mbps')),
                      DropdownMenuItem(value: 5000000, child: Text('5 Mbps')),
                      DropdownMenuItem(value: 10000000, child: Text('10 Mbps')),
                      DropdownMenuItem(value: 20000000, child: Text('20 Mbps')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _config = _config.copyWith(maxBitrate: value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _config.minBitrate,
                    decoration: const InputDecoration(labelText: 'Bitrate Mínimo'),
                    items: const [
                      DropdownMenuItem(value: 500000, child: Text('500 Kbps')),
                      DropdownMenuItem(value: 1000000, child: Text('1 Mbps')),
                      DropdownMenuItem(value: 2000000, child: Text('2 Mbps')),
                      DropdownMenuItem(value: 3000000, child: Text('3 Mbps')),
                      DropdownMenuItem(value: 5000000, child: Text('5 Mbps')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _config = _config.copyWith(minBitrate: value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Câmera
            if (widget.availableCameras.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _config.cameraType,
                decoration: const InputDecoration(labelText: 'Câmera'),
                items: [
                  const DropdownMenuItem(value: 'back', child: Text('Traseira')),
                  const DropdownMenuItem(value: 'front', child: Text('Frontal')),
                  ...widget.availableCameras.map((camera) =>
                    DropdownMenuItem(
                      value: camera.deviceId,
                      child: Text(camera.label.isNotEmpty ? camera.label : 'Câmera ${camera.deviceId}'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _config = _config.copyWith(cameraType: value);
                  }
                },
              ),
            const SizedBox(height: 16),

            // Áudio
            SwitchListTile(
              title: const Text('Incluir Áudio'),
              value: _config.audio,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(audio: value);
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await StreamingConfigManager.resetConfig();
            const defaultConfig = StreamingConfig();
            setState(() {
              _config = defaultConfig;
              _serverController.text = defaultConfig.server;
            });
          },
          child: const Text('Resetar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final serverValue = _serverController.text.trim();
            if (serverValue.isNotEmpty) {
              _config = _config.copyWith(server: serverValue);
            }
            widget.onConfigChanged(_config);
            Navigator.of(context).pop();
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
