import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/camera_connection.dart';

class PeerConnectionManager {
  static const Map<String, dynamic> _defaultConfiguration = {
    'iceServers': [
      {
        'urls': 'stun:stun.l.google.com:19302',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  /// Inicializa uma nova conexão peer para câmera
  static Future<RTCPeerConnection> initializeCameraPeerConnection(
    WebSocket ws,
    RTCVideoRenderer remoteRenderer,
    String connectionId,
    Function(CameraConnection?) onConnectionUpdated,
    Map<String, CameraConnection> connections,
    Function(String) onRemoveConnection,
  ) async {
    RTCPeerConnection peerConnection = await createPeerConnection(_defaultConfiguration);

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      ws.add(jsonEncode({'candidate': candidate.toMap()}));
    };

    peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        remoteRenderer.srcObject = event.streams[0];
        final connection = connections[connectionId];
        if (connection != null) {
          onConnectionUpdated(connection);
        }
      }
    };

    peerConnection.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state for $connectionId: $state');
      final connection = connections[connectionId];
      if (connection != null) {
        connection.isConnected =
            state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          // Aguardar um pouco antes de remover para permitir reconexões
          Timer(const Duration(seconds: 5), () {
            final currentConnection = connections[connectionId];
            if (currentConnection != null &&
                !currentConnection.isConnected &&
                (currentConnection.peerConnection.connectionState ==
                        RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                    currentConnection.peerConnection.connectionState ==
                        RTCPeerConnectionState.RTCPeerConnectionStateClosed)) {
              onRemoveConnection(connectionId);
            }
          });
        }

        onConnectionUpdated(connection);
      }
    };

    return peerConnection;
  }

  /// Inicializa uma nova conexão peer para viewer web
  static Future<RTCPeerConnection> initializeViewerPeerConnection(
    WebSocket ws,
    CameraConnection camera,
  ) async {
    RTCPeerConnection viewerPeerConnection = await createPeerConnection(_defaultConfiguration);

    // Configurar callbacks do peer connection do viewer
    viewerPeerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (ws.readyState == WebSocket.open) {
        ws.add(jsonEncode({
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid
        }));
      }
    };

    return viewerPeerConnection;
  }

  /// Processa mensagens WebRTC (SDP e ICE candidates)
  static Future<void> handleWebRTCMessage(
    Map<String, dynamic> data,
    RTCPeerConnection peerConnection,
    WebSocket ws,
  ) async {
    if (data['sdp'] != null) {
      await peerConnection.setRemoteDescription(
          RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
      
      if (data['sdp']['type'] == 'offer') {
        var answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        ws.add(jsonEncode({'sdp': answer.toMap()}));
      }
    } else if (data['candidate'] != null) {
      await peerConnection.addCandidate(RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      ));
    }
  }

  /// Adiciona tracks da câmera para o viewer
  static Future<void> addCameraTracksToViewer(
    RTCPeerConnection viewerPeerConnection,
    CameraConnection camera,
  ) async {
    if (camera.renderer.srcObject != null) {
      final stream = camera.renderer.srcObject!;
      final videoTracks = stream.getVideoTracks();
      final audioTracks = stream.getAudioTracks();

      if (videoTracks.isNotEmpty) {
        for (final track in videoTracks) {
          await viewerPeerConnection.addTrack(track, stream);
        }
      }
      if (audioTracks.isNotEmpty) {
        for (final track in audioTracks) {
          await viewerPeerConnection.addTrack(track, stream);
        }
      }
    }
  }
}
