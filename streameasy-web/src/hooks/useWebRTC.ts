import { useEffect, useRef, useState, useCallback } from 'react';
import SimplePeer from 'simple-peer';

interface WebRTCConfig {
  cameraId: string;
  serverUrl: string;
}

interface WebRTCState {
  stream: MediaStream | null;
  isConnected: boolean;
  isLoading: boolean;
  error: string | null;
  connectionState: string;
}

export const useWebRTC = ({ cameraId, serverUrl }: WebRTCConfig) => {
  const [state, setState] = useState<WebRTCState>({
    stream: null,
    isConnected: false,
    isLoading: false,
    error: null,
    connectionState: 'new'
  });

  const peerRef = useRef<SimplePeer.Instance | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  const updateState = useCallback((updates: Partial<WebRTCState>) => {
    setState(prev => ({ ...prev, ...updates }));
  }, []);

  const connectToCamera = useCallback(async () => {
    const currentState = wsRef.current?.readyState;
    if (!cameraId || currentState === WebSocket.CONNECTING) return;

    if (peerRef.current) {
      peerRef.current.destroy();
      peerRef.current = null;
    }

    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }

    updateState({ isLoading: true, error: null, connectionState: 'connecting' });

    try {
      const wsUrl = `${serverUrl}/ws/viewer/${cameraId}`;
      console.log('Connecting to WebSocket:', wsUrl);
      
      const ws = new WebSocket(wsUrl);
      wsRef.current = ws;

      ws.onopen = () => {
        console.log('WebSocket connected to camera:', cameraId);
        updateState({ connectionState: 'connected' });
        
        // Criamos uma mídia falsa para forçar a solicitação de vídeo
        const offerOptions = {
          offerToReceiveAudio: true,
          offerToReceiveVideo: true
        };
        
        const peer = new SimplePeer({
          initiator: true,
          trickle: false,
          config: {
            iceServers: [
              { urls: 'stun:stun.l.google.com:19302' },
              { urls: 'stun:stun1.l.google.com:19302' }
            ],
          },
          // Adicionar opções para solicitar vídeo explicitamente
          offerOptions: offerOptions
        });

        // Hack para garantir que estamos solicitando vídeo
        // @ts-ignore - Acessando propriedade interna para forçar transceiver de vídeo
        if (peer._pc) {
          // @ts-ignore
          peer._pc.addTransceiver('video', { direction: 'recvonly' });
          // @ts-ignore
          peer._pc.addTransceiver('audio', { direction: 'recvonly' });
          console.log('Added video and audio transceivers to request media');
        }

        peerRef.current = peer;

        peer.on('signal', (data: any) => {
          console.log('SimplePeer signal generated:', JSON.stringify(data, null, 2));
          
          if (data.type === 'offer' || data.type === 'answer') {
            const message = {
              sdp: {
                type: data.type,
                sdp: data.sdp
              }
            };
            console.log('Sending SDP:', message);
            ws.send(JSON.stringify(message));
          } else if (data.candidate) {
            const message = {
              candidate: {
                candidate: data.candidate,
                sdpMid: data.sdpMid,
                sdpMLineIndex: data.sdpMLineIndex
              }
            };
            console.log('Sending ICE candidate:', message);
            ws.send(JSON.stringify(message));
          } else {
            console.log('Unknown signal type:', data);
          }
        });

        peer.on('stream', (stream: MediaStream) => {
          console.log('🎥 Received stream from camera via stream event!');
          console.log('Stream tracks:', stream.getTracks().map(t => `${t.kind}: ${t.enabled}`));
          
          streamRef.current = stream;
          
          updateState({ 
            stream, 
            isConnected: true, 
            isLoading: false,
            connectionState: 'connected'
          });

          if (videoRef.current) {
            console.log('Setting video source');
            videoRef.current.srcObject = stream;
          }
        });
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          console.log('WebSocket message received:', JSON.stringify(data, null, 2));

          if (data.type === 'camera_info') {
            console.log('Camera info:', data.camera);
          } else if (data.sdp) {
            console.log('Received SDP:', data.sdp.type);
            if (peerRef.current && !peerRef.current.destroyed) {
              peerRef.current.signal({
                type: data.sdp.type,
                sdp: data.sdp.sdp
              } as any);
            }
          } else if (data.candidate !== undefined && data.sdpMLineIndex !== undefined) {
            console.log('Received ICE candidate:', data.candidate);
            if (peerRef.current && !peerRef.current.destroyed) {
              try {
                const candidateInit = {
                  candidate: data.candidate,
                  sdpMLineIndex: data.sdpMLineIndex,
                  sdpMid: data.sdpMid
                };
                
                const rtcCandidate = new RTCIceCandidate(candidateInit);
                peerRef.current.signal({
                  type: 'candidate',
                  candidate: rtcCandidate
                } as any);

                console.log('Sent RTCIceCandidate:', rtcCandidate);
              } catch (error) {
                console.error('Error processing ICE candidate:', error);
                console.log('Raw ICE data:', data);
              }
            }
          } else if (data.error) {
            console.error('Server error:', data.error);
            updateState({ error: data.error, isLoading: false, connectionState: 'failed' });
          } else {
            console.log('Unknown message format:', data);
          }
        } catch (error) {
          console.error('Error parsing WebSocket message:', error);
          updateState({ error: 'Erro ao processar mensagem do servidor', isLoading: false });
        }
      };

      ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        updateState({ 
          error: 'Erro de conexão WebSocket', 
          isLoading: false,
          connectionState: 'failed'
        });
      };

      ws.onclose = (event) => {
        console.log('WebSocket closed, code:', event.code, 'reason:', event.reason);
        updateState({ 
          isConnected: false, 
          isLoading: false,
          connectionState: 'disconnected'
        });
        
        if (peerRef.current) {
          peerRef.current.destroy();
          peerRef.current = null;
        }
      };

    } catch (error) {
      console.error('Error connecting to camera:', error);
      updateState({ 
        error: error instanceof Error ? error.message : 'Erro desconhecido', 
        isLoading: false,
        connectionState: 'failed'
      });
    }
  }, [cameraId, serverUrl, updateState]);

  const disconnect = useCallback(() => {
    console.log('Disconnecting from camera');
    
    if (peerRef.current) {
      peerRef.current.destroy();
      peerRef.current = null;
    }

    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.close(1000, 'User disconnect');
      wsRef.current = null;
    }

    updateState({ 
      stream: null, 
      isConnected: false, 
      isLoading: false,
      connectionState: 'disconnected',
      error: null
    });

    streamRef.current = null;

    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }
  }, [updateState]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      disconnect();
    };
  }, [disconnect]);

  return {
    ...state,
    connectToCamera,
    disconnect,
    videoRef
  };
};
