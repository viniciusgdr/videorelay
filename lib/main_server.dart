import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streameasy/screens/settings.dart';
import 'package:streameasy/src/models/camera_connection.dart';
import 'package:streameasy/src/services/websocket_server_manager.dart';
import 'screens/camera_viewer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ServerState()),
        ChangeNotifierProxyProvider<ServerState, WebSocketServerManager>(
          create: (context) => WebSocketServerManager(),
          update: (context, serverState, manager) => serverState.serverManager,
        ),
      ],
      child: MaterialApp(
        title: 'StreamEasy Server',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.grey[900],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black87,
            elevation: 4,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.blueAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            iconTheme: IconThemeData(color: Colors.blueAccent),
            shadowColor: Colors.blueAccent,
            toolbarHeight: 70,
          ),
        ),
        home: const ServerHomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class ServerState extends ChangeNotifier {
  final WebSocketServerManager _serverManager = WebSocketServerManager();
  bool _isServerRunning = false;
  String _serverStatus = 'Parado';
  final List<CameraConnection> _cameras = [];

  bool get isServerRunning => _isServerRunning;
  String get serverStatus => _serverStatus;
  List<CameraConnection> get cameras => _cameras;
  int get connectedCameras => _cameras.length;
  WebSocketServerManager get serverManager => _serverManager;

  ServerState() {
    _initializeServer();
  }

  void _initializeServer() {
    _serverManager.onCameraConnected = (camera) {
      _cameras.add(camera);
      notifyListeners();
    };

    _serverManager.onCameraDisconnected = (deviceId) {
      _cameras.removeWhere((camera) => camera.deviceId == deviceId);
      notifyListeners();
    };

    _serverManager.onCameraUpdated = (updatedCamera) {
      final index = _cameras
          .indexWhere((camera) => camera.deviceId == updatedCamera.deviceId);
      if (index != -1) {
        _cameras[index] = updatedCamera;
        notifyListeners();
      }
    };
  }

  Future<void> startServer() async {
    try {
      await _serverManager.startServer();
      _isServerRunning = true;
      _serverStatus = 'Rodando na porta ${_serverManager.port}';
      notifyListeners();
    } catch (e) {
      _serverStatus = 'Erro: $e';
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    try {
      await _serverManager.stopServer();
      _isServerRunning = false;
      _serverStatus = 'Parado';
      _cameras.clear();
      notifyListeners();
    } catch (e) {
      _serverStatus = 'Erro ao parar: $e';
      notifyListeners();
    }
  }

  CameraConnection? getCameraById(String deviceId) {
    try {
      return _cameras.firstWhere((camera) => camera.deviceId == deviceId);
    } catch (e) {
      return null;
    }
  }
}

class ServerHomePage extends StatelessWidget {
  const ServerHomePage({super.key});

  void _openWebInterface(BuildContext context, ServerState serverState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Row(
            children: [
              Icon(Icons.web, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'Interface Web',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Acesse a interface web através dos seguintes endereços:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              _buildUrlCard('Local:', 'http://localhost:${serverState.serverManager.port}'),
              const SizedBox(height: 16),
              const Text(
                'Funcionalidades disponíveis:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Visualizar todas as câmeras conectadas\n'
                '• Abrir câmeras em janelas separadas\n'
                '• Modo tela cheia para cada câmera\n'
                '• Informações de bateria e status',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fechar',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUrlCard(String label, String url) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerState>(
      builder: (context, serverState, child) {
        return Scaffold(
          appBar: AppBar(
            elevation: 8,
            backgroundColor: Colors.black87,
            shadowColor: Colors.blueAccent.withOpacity(0.4),
            leading: const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.computer, color: Colors.white),
              ),
            ),
            title: Row(
              children: [
                const Text(
                  'StreamEasy Server',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: serverState.isServerRunning
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        serverState.isServerRunning
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: serverState.isServerRunning
                            ? Colors.green
                            : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        serverState.isServerRunning ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: serverState.isServerRunning
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color:
                      serverState.isServerRunning ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (serverState.isServerRunning
                              ? Colors.green
                              : Colors.red)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      serverState.isServerRunning
                          ? Icons.play_circle
                          : Icons.stop_circle,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      serverState.serverStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (serverState.isServerRunning)
                IconButton(
                  icon: const Icon(Icons.web, color: Colors.blueAccent),
                  tooltip: 'Abrir Interface Web',
                  onPressed: () => _openWebInterface(context, serverState),
                ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.blueAccent),
                tooltip: 'Configurações',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Controle do Servidor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${serverState.connectedCameras} câmeras conectadas',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (serverState.isServerRunning) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Interface web: http://localhost:${serverState.serverManager.port}',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: serverState.isServerRunning
                          ? serverState.stopServer
                          : serverState.startServer,
                      icon: Icon(
                        serverState.isServerRunning
                            ? Icons.stop
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        serverState.isServerRunning ? 'Parar' : 'Iniciar',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: serverState.isServerRunning
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de câmeras
              Expanded(
                child: serverState.cameras.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              serverState.isServerRunning
                                  ? 'Aguardando conexões de câmeras...'
                                  : 'Inicie o servidor para receber conexões',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (serverState.isServerRunning) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _openWebInterface(context, serverState),
                                icon: const Icon(Icons.web),
                                label: const Text('Abrir Interface Web'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: serverState.cameras.length,
                        itemBuilder: (context, index) {
                          final camera = serverState.cameras[index];
                          return CameraCard(camera: camera);
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: serverState.cameras.isNotEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: "web",
                      onPressed: () => _openWebInterface(context, serverState),
                      backgroundColor: Colors.blueAccent,
                      tooltip: 'Interface Web',
                      child: const Icon(Icons.web),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.extended(
                      heroTag: "viewer",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CameraViewerScreen(),
                          ),
                        );
                      },
                      backgroundColor: Colors.green,
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('Visualizar'),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

class CameraCard extends StatelessWidget {
  final CameraConnection camera;

  const CameraCard({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[800],
      child: InkWell(
        onTap: () => _openCameraWindow(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.videocam,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),

              // Informações da câmera
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.deviceName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${camera.deviceId}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Modelo: ${camera.deviceModel}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Botões de ação
              Column(
                children: [
                  _buildBatteryIndicator(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _openWebViewer(context, camera.deviceId),
                        icon: const Icon(Icons.web, color: Colors.blueAccent),
                        tooltip: 'Abrir no Web',
                      ),
                      IconButton(
                        onPressed: () => _openCameraWindow(context),
                        icon: const Icon(Icons.fullscreen, color: Colors.green),
                        tooltip: 'Tela Cheia',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryIndicator() {
    Color batteryColor;
    IconData batteryIcon;

    if (camera.isCharging) {
      batteryColor = Colors.green;
      batteryIcon = Icons.battery_charging_full;
    } else if (camera.batteryLevel > 50) {
      batteryColor = Colors.green;
      batteryIcon = Icons.battery_full;
    } else if (camera.batteryLevel > 20) {
      batteryColor = Colors.orange;
      batteryIcon = Icons.battery_3_bar;
    } else {
      batteryColor = Colors.red;
      batteryIcon = Icons.battery_1_bar;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: batteryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(batteryIcon, color: batteryColor, size: 16),
          const SizedBox(width: 4),
          Text(
            '${camera.batteryLevel}%',
            style: TextStyle(color: batteryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openCameraWindow(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraViewerScreen(
          initialCameraId: camera.deviceId,
        ),
      ),
    );
  }

  void _openWebViewer(BuildContext context, String cameraId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Row(
            children: [
              Icon(Icons.web, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'Visualizar no Navegador',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Câmera: ${camera.deviceName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Abra o seguinte endereço no seu navegador:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  'http://localhost:8080/viewer.html?camera=$cameraId',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ou use estes botões para abrir automaticamente:',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Aqui você pode implementar uma função para abrir o navegador padrão
                // Por exemplo, usando url_launcher
              },
              icon: const Icon(Icons.open_in_browser, color: Colors.blueAccent),
              label: const Text(
                'Janela Normal',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Implementar abertura em tela cheia
              },
              icon: const Icon(Icons.fullscreen, color: Colors.green),
              label: const Text(
                'Tela Cheia',
                style: TextStyle(color: Colors.green),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fechar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }
}
