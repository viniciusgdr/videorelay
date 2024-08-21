import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:streameasy/screens/settings.dart';
import 'package:streameasy/src/hooks/websocket_server.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => WebSocketServerManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebSocket Server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const WebRTCServer(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class WebRTCServer extends StatelessWidget {
  const WebRTCServer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VideoRelay Server'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          Consumer<WebSocketServerManager>(
            builder: (context, manager, child) {
              return IconButton(
                icon: Icon(manager.audioEnabled ? Icons.mic_off : Icons.mic),
                onPressed: () {
                  manager.muteAudio = !manager.audioEnabled;
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<WebSocketServerManager>(
        builder: (context, manager, child) {
          return Column(
            children: [
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: manager.remoteRenderers.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        manager.selectedCameraIndex = index;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        alignment: Alignment.center,
                        color: index == manager.selectedCameraIndex
                            ? Colors.blueAccent
                            : Colors.grey,
                        child: Text('Camera ${index + 1}'),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: manager.remoteRenderers.isNotEmpty
                    ? RTCVideoView(
                        manager.remoteRenderers[manager.selectedCameraIndex])
                    : const Center(child: Text('No camera selected')),
              ),
            ],
          );
        },
      ),
    );
  }
}