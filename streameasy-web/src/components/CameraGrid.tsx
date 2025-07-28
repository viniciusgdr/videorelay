import React from 'react';
import { useNavigate } from 'react-router-dom';

interface Camera {
  id: string;
  deviceId: string;
  deviceName: string;
  deviceModel: string;
  batteryLevel: number;
  batteryStatus: string;
  isConnected: boolean;
  isCharging: boolean;
  hasVideoStream: boolean;
  lastSeen: string;
}

interface CameraGridProps {
  cameras: Camera[];
}

const CameraGrid: React.FC<CameraGridProps> = ({ cameras }) => {
  const navigate = useNavigate();

  const handleCameraClick = (cameraId: string) => {
    navigate(`/camera/${cameraId}`);
  };
  const getBatteryColor = (level: number, isCharging: boolean) => {
    if (isCharging) return 'text-green-400';
    if (level > 50) return 'text-green-400';
    if (level > 20) return 'text-yellow-400';
    return 'text-red-400';
  };

  const getBatteryIcon = (level: number, isCharging: boolean) => {
    if (isCharging) return '⚡';
    if (level > 50) return '🔋';
    if (level > 20) return '🪫';
    return '🪫';
  };

  const formatLastSeen = (lastSeen: string) => {
    const date = new Date(lastSeen);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const minutes = Math.floor(diff / 60000);
    
    if (minutes < 1) return 'Agora mesmo';
    if (minutes === 1) return '1 minuto atrás';
    if (minutes < 60) return `${minutes} minutos atrás`;
    
    const hours = Math.floor(minutes / 60);
    if (hours === 1) return '1 hora atrás';
    if (hours < 24) return `${hours} horas atrás`;
    
    return date.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const openFullscreenViewer = (cameraId: string) => {
    const url = `http://localhost:8080/viewer.html?camera=${cameraId}&fullscreen=true`;
    window.open(url, '_blank', 'fullscreen=yes,menubar=no,toolbar=no,location=no,status=no');
  };

  const openWindowViewer = (cameraId: string) => {
    const url = `http://localhost:8080/viewer.html?camera=${cameraId}`;
    window.open(url, '_blank', 'width=800,height=600,menubar=no,toolbar=no,location=no,status=no');
  };

  if (cameras.length === 0) {
    return (
      <div className="text-center py-12">
        <div className="text-6xl mb-4">📷</div>
        <h3 className="text-xl font-semibold text-gray-300 mb-2">
          Nenhuma câmera conectada
        </h3>
        <p className="text-gray-500">
          Aguardando conexões de dispositivos móveis...
        </p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
      {cameras.map((camera) => (
        <div
          key={camera.id}
          className="bg-gray-800 rounded-lg border border-gray-700 hover:border-blue-500 transition-all duration-200 hover:shadow-lg hover:shadow-blue-500/20"
        >
          {/* Header da câmera */}
          <div className="p-4 border-b border-gray-700">
            <div className="flex items-center justify-between mb-2">
              <h3 className="font-semibold text-white truncate">
                {camera.deviceName}
              </h3>
              <div className={`flex items-center space-x-1 ${getBatteryColor(camera.batteryLevel, camera.isCharging)}`}>
                <span>{getBatteryIcon(camera.batteryLevel, camera.isCharging)}</span>
                <span className="text-sm font-medium">{camera.batteryLevel}%</span>
              </div>
            </div>
            
            <div className="flex items-center space-x-2 text-sm text-gray-400">
              <span className={`w-2 h-2 rounded-full ${camera.isConnected ? 'bg-green-400' : 'bg-red-400'}`}></span>
              <span>{camera.isConnected ? 'Online' : 'Offline'}</span>
              
              {camera.hasVideoStream && (
                <>
                  <span>•</span>
                  <span className="text-purple-400">🎬 Transmitindo</span>
                </>
              )}
            </div>
          </div>

          {/* Informações da câmera */}
          <div className="p-4">
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-400">Modelo:</span>
                <span className="text-white">{camera.deviceModel}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">ID:</span>
                <span className="text-white font-mono text-xs">{camera.deviceId.substring(0, 8)}...</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Última atividade:</span>
                <span className="text-white">{formatLastSeen(camera.lastSeen)}</span>
              </div>
            </div>
          </div>

          {/* Botões de ação */}
          <div className="p-4 border-t border-gray-700">
            <div className="flex space-x-2">
              <button
                onClick={() => handleCameraClick(camera.id)}
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-2 px-3 rounded-lg text-sm font-medium transition-colors flex items-center justify-center space-x-1"
              >
                <span>👁️</span>
                <span>Visualizar</span>
              </button>
              
              <button
                onClick={() => openWindowViewer(camera.id)}
                className="bg-gray-700 hover:bg-gray-600 text-white py-2 px-3 rounded-lg text-sm font-medium transition-colors"
                title="Abrir em janela"
              >
                🪟
              </button>
              
              <button
                onClick={() => openFullscreenViewer(camera.id)}
                className="bg-green-600 hover:bg-green-700 text-white py-2 px-3 rounded-lg text-sm font-medium transition-colors"
                title="Tela cheia"
              >
                ⛶
              </button>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default CameraGrid;
