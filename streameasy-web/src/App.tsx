import React, { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import CameraGrid from './components/CameraGrid';
import CameraViewer from './components/CameraViewer';
import { API_BASE_URL } from './config';

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

const HomePage: React.FC = () => {
  const [cameras, setCameras] = useState<Camera[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCameras = async () => {
    try {
      setError(null);
      const response = await fetch(`${API_BASE_URL}/api/cameras`);
      
      if (!response.ok) {
        throw new Error('Erro ao conectar com o servidor');
      }
      
      const data = await response.json();
      setCameras(data.cameras || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro desconhecido');
      console.error('Error fetching cameras:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCameras();
    
    // Atualizar a cada 5 segundos
    const interval = setInterval(fetchCameras, 5000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 text-white flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mx-auto mb-4"></div>
          <p>Carregando câmeras...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-900 text-white flex items-center justify-center">
        <div className="text-center">
          <div className="text-6xl mb-4">⚠️</div>
          <h2 className="text-xl font-bold mb-4">Erro de Conexão</h2>
          <p className="text-gray-400 mb-6">{error}</p>
          <button
            onClick={fetchCameras}
            className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg transition-colors"
          >
            Tentar Novamente
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold">StreamEasy</h1>
            <p className="text-gray-400">Sistema de Monitoramento de Câmeras</p>
          </div>
          <div className="text-right">
            <p className="text-sm text-gray-400">
              {cameras.length} câmera{cameras.length !== 1 ? 's' : ''} conectada{cameras.length !== 1 ? 's' : ''}
            </p>
            <div className="flex items-center justify-end space-x-2 mt-1">
              <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
              <span className="text-xs text-gray-500">Atualizando...</span>
            </div>
          </div>
        </div>

        {cameras.length === 0 ? (
          <div className="text-center py-16">
            <div className="text-6xl mb-4">📱</div>
            <h2 className="text-xl font-bold mb-4">Nenhuma câmera conectada</h2>
            <p className="text-gray-400 mb-6">
              Configure o aplicativo móvel para conectar ao servidor em:<br />
              <code className="bg-gray-800 px-2 py-1 rounded text-blue-400">
                {window.location.hostname}:8080
              </code>
            </p>
            <button
              onClick={fetchCameras}
              className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg transition-colors"
            >
              Verificar Novamente
            </button>
          </div>
        ) : (
          <CameraGrid cameras={cameras} />
        )}
      </div>
    </div>
  );
};

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/camera/:cameraId" element={<CameraViewer />} />
      </Routes>
    </Router>
  );
}

export default App;
