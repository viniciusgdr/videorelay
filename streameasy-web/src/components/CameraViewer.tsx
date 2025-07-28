import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useWebRTC } from '../hooks/useWebRTC';
import { useAutoReconnect } from '../hooks/useAutoReconnect';
import { API_BASE_URL } from '../config';

interface CameraInfo {
  id: string;
  deviceName: string;
  deviceModel: string;
  batteryLevel: number;
  isCharging: boolean;
  isConnected: boolean;
  hasVideoStream: boolean;
}

const CameraViewer: React.FC = () => {
  const { cameraId } = useParams<{ cameraId: string }>();
  const navigate = useNavigate();
  const [cameraInfo, setCameraInfo] = useState<CameraInfo | null>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);

  const {
    stream,
    isConnected,
    isLoading,
    error,
    connectionState,
    connectToCamera,
    disconnect,
    videoRef
  } = useWebRTC({
    cameraId: cameraId || '',
    serverUrl: API_BASE_URL.replace('http', 'ws')
  });

  console.log(isLoading)

  // Auto-reconnect quando a conexão cair
  const { reconnectAttempts, isReconnecting } = useAutoReconnect({
    isConnected,
    connectionState,
    error,
    onReconnect: connectToCamera,
    maxAttempts: 5,
    enabled: true
  });

  useEffect(() => {
    if (!cameraId) {
      navigate('/');
      return;
    }

    console.log('Connecting to camera:', cameraId);

    // Buscar informações da câmera
    const fetchCameraInfo = async () => {
      try {
        const response = await fetch(`${API_BASE_URL}/api/camera/${cameraId}`);
        if (response.ok) {
          const data = await response.json();
          setCameraInfo(data);
        } else {
          console.error('Camera not found');
          navigate('/');
        }
      } catch (error) {
        console.error('Error fetching camera info:', error);
      }
    };

    fetchCameraInfo();
    
    // Conectar ao WebRTC
    connectToCamera();

    // Cleanup on unmount
    return () => {
      disconnect();
    };
  }, [cameraId, navigate, connectToCamera, disconnect]); // Incluir todas as dependências necessárias

  const toggleFullscreen = () => {
    if (!document.fullscreenElement) {
      videoRef.current?.requestFullscreen();
      setIsFullscreen(true);
    } else {
      document.exitFullscreen();
      setIsFullscreen(false);
    }
  };

  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };

    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange);
  }, []);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'connected': return 'text-green-400';
      case 'connecting': return 'text-yellow-400';
      case 'failed': return 'text-red-400';
      default: return 'text-gray-400';
    }
  };

  const getStatusText = (status: string) => {
    if (isReconnecting && reconnectAttempts > 0) {
      return `Reconectando... (${reconnectAttempts}/5)`;
    }
    
    switch (status) {
      case 'connected': return 'Conectado';
      case 'connecting': return 'Conectando...';
      case 'failed': return 'Falhou';
      case 'disconnected': return 'Desconectado';
      case 'closed': return 'Conexão fechada';
      default: return 'Aguardando...';
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* Header */}
      <div className="bg-gray-800 p-4 flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <button
            onClick={() => navigate('/')}
            className="bg-gray-700 hover:bg-gray-600 px-4 py-2 rounded-lg transition-colors"
          >
            ← Voltar
          </button>
          <div>
            <h1 className="text-xl font-bold">
              {cameraInfo?.deviceName || `Câmera ${cameraId?.slice(-6)}`}
            </h1>
            <p className="text-sm text-gray-400">
              {cameraInfo?.deviceModel}
            </p>
          </div>
        </div>

        {/* Status */}
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <div className={`w-3 h-3 rounded-full ${
              isConnected ? 'bg-green-400' : 
              (isLoading || isReconnecting) ? 'bg-yellow-400' : 
              'bg-red-400'
            }`}></div>
            <span className={`text-sm ${getStatusColor(connectionState)}`}>
              {getStatusText(connectionState)}
            </span>
          </div>

          {cameraInfo && (
            <div className="flex items-center space-x-2 text-sm text-gray-400">
              <span>🔋 {cameraInfo.batteryLevel}%</span>
              {cameraInfo.isCharging && <span>⚡</span>}
            </div>
          )}

          {/* Botão de reconexão manual quando há erro */}
          {(error || connectionState === 'failed') && (
            <button
              onClick={connectToCamera}
              disabled={isLoading || isReconnecting}
              className="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 px-3 py-1 rounded text-sm transition-colors"
            >
              {isLoading || isReconnecting ? 'Conectando...' : 'Reconectar'}
            </button>
          )}
        </div>
      </div>

      {/* Video Container */}
      <div className="relative flex-1 flex items-center justify-center p-4">
        {error && (
          <div className="absolute top-4 left-1/2 transform -translate-x-1/2 z-10 max-w-md">
            <div className="bg-red-600 text-white px-4 py-2 rounded-lg shadow-lg">
              <div className="font-semibold">Erro de Conexão</div>
              <div className="text-sm opacity-90">{error}</div>
              {reconnectAttempts > 0 && (
                <div className="text-xs mt-1 opacity-75">
                  Tentativa {reconnectAttempts}/5
                </div>
              )}
            </div>
          </div>
        )}

        <div className="relative bg-black rounded-lg overflow-hidden shadow-2xl max-w-full max-h-full">
          <video
            ref={videoRef}
            autoPlay
            playsInline
            muted
            className="w-full h-full object-contain"
            style={{ minWidth: '640px', minHeight: '480px' }}
          />

          {/* Loading Overlay */}
          {isLoading && (
            <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
              <div className="text-center">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mx-auto mb-4"></div>
                <p>Conectando à câmera...</p>
              </div>
            </div>
          )}

          {/* No Stream Overlay */}
          {!stream && !isLoading && !error && (
            <div className="absolute inset-0 flex items-center justify-center bg-gray-800">
              <div className="text-center text-gray-400">
                <div className="text-6xl mb-4">📹</div>
                <p>Aguardando stream da câmera...</p>
              </div>
            </div>
          )}

          {/* Controls Overlay */}
          <div className="absolute bottom-4 right-4 flex space-x-2">
            <button
              onClick={toggleFullscreen}
              className="bg-black bg-opacity-50 hover:bg-opacity-75 text-white p-2 rounded-lg transition-all"
              title={isFullscreen ? 'Sair da tela cheia' : 'Tela cheia'}
            >
              {isFullscreen ? (
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M15 9v-4.5M15 9h4.5M15 9l5.25-5.25M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 15v4.5M15 15h4.5m0 0l5.25 5.25" />
                </svg>
              ) : (
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
                </svg>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CameraViewer;
