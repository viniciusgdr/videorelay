import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streameasy/src/hooks/websocket_server.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPort();
  }

  void _loadPort() {
    final manager = Provider.of<WebSocketServerManager>(context, listen: false);
    _portController.text = manager.port.toString();
  }

  void _savePort() {
    final newPort = int.tryParse(_portController.text);
    if (newPort != null && newPort > 0 && newPort <= 65535) {
      final manager = Provider.of<WebSocketServerManager>(context, listen: false);
      manager.port = newPort;
      Navigator.pop(context); // Voltar para a tela principal após salvar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port saved and WebSocket restarted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid port number')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WebSocket Port:'),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Port',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePort,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}