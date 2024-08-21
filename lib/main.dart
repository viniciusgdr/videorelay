import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_mdns_plugin/flutter_mdns_plugin.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Streaming',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const CameraStreamingPage(),
    );
  }
}

class CameraStreamingPage extends StatefulWidget {
  const CameraStreamingPage({super.key});

  @override
  State<CameraStreamingPage> createState() => _CameraStreamingPageState();
}

Future<MediaStream> _getUserMedia() async {
  List<MediaDeviceInfo> cameras = await Helper.cameras;

  // Selecionar a câmera traseira
  MediaDeviceInfo? rearCamera = cameras.firstWhere(
    (camera) => camera.label.toLowerCase().contains('back'),
    orElse: () => cameras.first, // Fallback para a primeira câmera disponível
  );

  // Configuração das restrições para captura de vídeo
  final Map<String, dynamic> mediaConstraints = {
    'audio': false,
    'video': {
      'deviceId': rearCamera.deviceId,
      'width': 1280, // 720p
      'height': 720, // 720p
      'frameRate': '30', // 30 fps
      'mandatory': {
        'minBitrate': 5000000, // Bitrate mínimo de 5Mbps
        'profileLevelId':
            '42e01f' // H.264 Constrained Baseline Profile Level 3.1
      }
    },
  };

  // Captura o stream de vídeo da câmera traseira
  return await navigator.mediaDevices.getUserMedia(mediaConstraints);
}

class _CameraStreamingPageState extends State<CameraStreamingPage> {
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _channel;
  FlutterMdnsPlugin? _mdns;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
    _startWebSocketConnection();
  }

  Future<void> _initializeRenderer() async {
    await _localRenderer.initialize();
  }

  Future<void> _initializeWebRTC() async {
    _localStream = await _getUserMedia(); // Captura da câmera traseira

    // Mostrar o stream da câmera no preview local
    setState(() {
      _localRenderer.srcObject = _localStream;
    });

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
    });

    _applyBandwidthConstraints();

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({
          'candidate': candidate.toMap(),
        }));
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (
        state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
        state == RTCPeerConnectionState.RTCPeerConnectionStateFailed
      ) {
        _peerConnection?.close();
        _localStream?.dispose();
        _localRenderer.srcObject = null;
        _localStream = null;

        _initializeWebRTC();
      }
    };

    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);

    _channel?.sink.add(jsonEncode({
      'sdp': offer.toMap(),
    }));
  }

  void _applyBandwidthConstraints([RTCRtpSender? sender]) {
    RTCRtpParameters parameters = sender?.parameters ?? RTCRtpParameters();
    parameters.encodings = [
      RTCRtpEncoding(
        maxBitrate: 10000000, // Bitrate máximo em 5Mbps
        minBitrate: 8000000, // Bitrate mínimo em 3Mbps
        maxFramerate: 60, // 60 fps
        scaleResolutionDownBy: 1.0, // Não reduzir a resolução
      ),
    ];

    sender?.setParameters(parameters);
  }

  void _startWebSocketConnection() {
    _channel = WebSocketChannel.connect(Uri.parse('ws://192.168.0.2:8080'));

    _channel!.stream.listen((message) async {
      var data = jsonDecode(message);

      if (data['sdp'] != null) {
        await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
      } else if (data['candidate'] != null) {
        await _peerConnection!.addCandidate(RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex']));
      }
    });

    _channel?.ready.then((_) {
      // on connect, start webRTC
      _initializeWebRTC();
    });

    _channel?.sink.done.then((_) async {
      _peerConnection?.close();
      _localStream?.dispose();
      _localRenderer.srcObject = null;
      _localStream = null;
      await Future.delayed(const Duration(seconds: 1));
      _startWebSocketConnection();
    });
  }

  @override
  void dispose() {
    _localStream?.dispose();
    _peerConnection?.dispose();
    _localRenderer.dispose();
    _channel?.sink.close();
    _mdns?.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RTCVideoView(
              _localRenderer, 
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        ],
      ),
    );
  }
}
