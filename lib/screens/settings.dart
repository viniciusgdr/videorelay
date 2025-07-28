import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streameasy/src/services/websocket_server_manager.dart';
import '../src/config/server_ui_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _portController = TextEditingController();
  ServerUIConfig _uiConfig = const ServerUIConfig();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final manager = Provider.of<WebSocketServerManager>(context, listen: false);
    _portController.text = manager.port.toString();
    
    final config = await ServerUIConfigManager.loadConfig();
    setState(() {
      _uiConfig = config;
    });
  }

  void _savePort() {
    final newPort = int.tryParse(_portController.text);
    if (newPort != null && newPort > 0 && newPort <= 65535) {
      final manager = Provider.of<WebSocketServerManager>(context, listen: false);
      manager.port = newPort;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Porta salva e servidor reiniciado')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de porta inválido')),
      );
    }
  }

  void _saveUIConfig() async {
    await ServerUIConfigManager.saveConfig(_uiConfig);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações de interface salvas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações do Servidor'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Configurações do Servidor
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configurações do Servidor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Porta WebSocket',
                      hintText: '8080',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savePort,
                      child: const Text('Salvar Porta'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<WebSocketServerManager>(
                    builder: (context, manager, child) {
                      return Card(
                        color: manager.connections.isNotEmpty 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(
                                manager.connections.isNotEmpty 
                                  ? Icons.wifi 
                                  : Icons.wifi_off,
                                color: manager.connections.isNotEmpty 
                                  ? Colors.green 
                                  : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Status: ${manager.connections.isNotEmpty ? "Ativo" : "Aguardando"} | '
                                'Porta: ${manager.port} | '
                                'Câmeras: ${manager.connections.length}',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Configurações da Interface
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configurações da Interface',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Mostrar Informações de Bateria'),
                    subtitle: const Text('Exibe nível e status da bateria dos dispositivos'),
                    value: _uiConfig.showBatteryInfo,
                    onChanged: (value) {
                      setState(() {
                        _uiConfig = _uiConfig.copyWith(showBatteryInfo: value);
                      });
                      _saveUIConfig();
                    },
                  ),
                  
                  SwitchListTile(
                    title: const Text('Mostrar Informações do Dispositivo'),
                    subtitle: const Text('Exibe nome e modelo dos dispositivos'),
                    value: _uiConfig.showDeviceInfo,
                    onChanged: (value) {
                      setState(() {
                        _uiConfig = _uiConfig.copyWith(showDeviceInfo: value);
                      });
                      _saveUIConfig();
                    },
                  ),
                  
                  SwitchListTile(
                    title: const Text('Habilitar Janelas de Câmera'),
                    subtitle: const Text('Permite abrir janelas separadas para cada câmera'),
                    value: _uiConfig.enableCameraWindows,
                    onChanged: (value) {
                      setState(() {
                        _uiConfig = _uiConfig.copyWith(enableCameraWindows: value);
                      });
                      _saveUIConfig();
                    },
                  ),
                  
                  SwitchListTile(
                    title: const Text('Seleção Automática'),
                    subtitle: const Text('Seleciona automaticamente a primeira câmera conectada'),
                    value: _uiConfig.enableAutoSelect,
                    onChanged: (value) {
                      setState(() {
                        _uiConfig = _uiConfig.copyWith(enableAutoSelect: value);
                      });
                      _saveUIConfig();
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Altura do Preview das Câmeras: ${_uiConfig.cameraPreviewHeight.toInt()}px',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Slider(
                    value: _uiConfig.cameraPreviewHeight,
                    min: 80.0,
                    max: 200.0,
                    divisions: 12,
                    label: '${_uiConfig.cameraPreviewHeight.toInt()}px',
                    onChanged: (value) {
                      setState(() {
                        _uiConfig = _uiConfig.copyWith(cameraPreviewHeight: value);
                      });
                    },
                    onChangeEnd: (value) {
                      _saveUIConfig();
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Máximo de Câmeras por Linha: ${_uiConfig.maxCamerasPerRow}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Slider(
                    value: _uiConfig.maxCamerasPerRow.toDouble(),
                    min: 2.0,
                    max: 8.0,
                    divisions: 6,
                    label: '${_uiConfig.maxCamerasPerRow}',
                    onChanged: (value) {
                      setState(() {
                        _uiConfig = _uiConfig.copyWith(maxCamerasPerRow: value.toInt());
                      });
                    },
                    onChangeEnd: (value) {
                      _saveUIConfig();
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Informações do Sistema
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informações do Sistema',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Consumer<WebSocketServerManager>(
                    builder: (context, manager, child) {
                      return Column(
                        children: [
                          if (manager.connections.isEmpty)
                            const ListTile(
                              leading: Icon(Icons.info_outline),
                              title: Text('Nenhuma câmera conectada'),
                              subtitle: Text('Conecte um dispositivo móvel para começar'),
                            )
                          else
                            ...manager.connections.values.map((connection) => 
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: connection.isConnected 
                                    ? Colors.green 
                                    : Colors.red,
                                  child: Text(
                                    connection.deviceName.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(connection.deviceName),
                                subtitle: Text(
                                  '${connection.deviceModel} | Bateria: ${connection.batteryLevel}% | ${connection.batteryStatus}'
                                ),
                                trailing: Icon(
                                  connection.isConnected 
                                    ? Icons.circle 
                                    : Icons.circle_outlined,
                                  color: connection.isConnected 
                                    ? Colors.green 
                                    : Colors.red,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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