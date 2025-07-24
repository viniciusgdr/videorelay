import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../src/hooks/websocket_server.dart';
import '../src/config/camera_viewer_config.dart';

class CameraViewerScreen extends StatefulWidget {
  final String? initialCameraId;
  
  const CameraViewerScreen({super.key, this.initialCameraId});

  @override
  State<CameraViewerScreen> createState() => _CameraViewerScreenState();
}

class _CameraViewerScreenState extends State<CameraViewerScreen> {
  String? _selectedCameraId;
  bool _showControls = true;
  bool _isFullscreen = false;
  final FocusNode _focusNode = FocusNode();
  
  // Rotação e proporção - apenas modo paisagem
  double _rotationAngle = CameraViewerConfig.defaultRotationAngle;
  RTCVideoViewObjectFit _aspectRatio = CameraViewerConfig.defaultAspectRatio;
  bool _isMirrored = CameraViewerConfig.defaultMirrored;
  
  @override
  void initState() {
    super.initState();
    _selectedCameraId = widget.initialCameraId;
    
    // Auto-hide controls after 3 seconds
    _startAutoHideTimer();
    
    // Set landscape orientation and fullscreen
    _enableFullscreen();
    
    // Request focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _disableFullscreen();
    _focusNode.dispose();
    super.dispose();
  }

  void _enableFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() {
      _isFullscreen = true;
    });
  }

  void _disableFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _startAutoHideTimer() {
    Future.delayed(CameraViewerConfig.autoHideDelay, () {
      if (mounted && CameraViewerConfig.defaultAutoHideControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    if (_showControls) {
      _startAutoHideTimer();
    }
  }

  void _selectCamera(String cameraId) {
    setState(() {
      _selectedCameraId = cameraId;
    });
    
    final serverManager = Provider.of<WebSocketServerManager>(context, listen: false);
    serverManager.selectCamera(cameraId);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          _previousCamera();
          break;
        case LogicalKeyboardKey.arrowRight:
          _nextCamera();
          break;
        case LogicalKeyboardKey.space:
          _toggleControls();
          break;
        case LogicalKeyboardKey.escape:
          Navigator.pop(context);
          break;
        case LogicalKeyboardKey.f11:
          _toggleFullscreen();
          break;
        case LogicalKeyboardKey.keyR:
          _rotateCamera();
          break;
        case LogicalKeyboardKey.keyM:
          _toggleMirror();
          break;
        case LogicalKeyboardKey.keyA:
          _changeAspectRatio();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Consumer<WebSocketServerManager>(
          builder: (context, serverManager, child) {
            final cameras = serverManager.connections.values.toList();
            
            if (cameras.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      size: 64,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Nenhuma câmera conectada',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Auto-select first camera if none selected
            if (_selectedCameraId == null || 
                !serverManager.connections.containsKey(_selectedCameraId)) {
              _selectedCameraId = cameras.first.id;
            }

            final selectedCamera = serverManager.connections[_selectedCameraId];

            return GestureDetector(
              onTap: _toggleControls,
              onHorizontalDragEnd: (details) {
                // Swipe left to go to next camera
                if (details.primaryVelocity! > 0) {
                  _previousCamera();
                } 
                // Swipe right to go to previous camera
                else if (details.primaryVelocity! < 0) {
                  _nextCamera();
                }
              },
              child: Stack(
                children: [
                  // Main video view
                  if (selectedCamera != null)
                    _buildVideoView(selectedCamera)
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),

                  // Top controls bar
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: _showControls ? 0 : -100,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(cameras, selectedCamera),
                  ),

                  // Bottom controls bar
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    bottom: _showControls ? 0 : -100,
                    left: 0,
                    right: 0,
                    child: _buildBottomBar(cameras),
                  ),

                  // Camera selector (right side)
                  if (_showControls && cameras.length > 1)
                    Positioned(
                      right: 16,
                      top: 100,
                      bottom: 100,
                      child: _buildCameraSelector(cameras),
                    ),

                  // Help overlay (bottom left)
                  if (_showControls)
                    Positioned(
                      left: 16,
                      bottom: 120,
                      child: _buildHelpOverlay(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHelpOverlay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Controles:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildHelpItem('← →', 'Trocar câmera'),
          _buildHelpItem('Espaço', 'Mostrar/ocultar controles'),
          _buildHelpItem('ESC', 'Voltar'),
          _buildHelpItem('F11', 'Tela cheia'),
          _buildHelpItem('R', 'Rotacionar'),
          _buildHelpItem('M', 'Espelhar'),
          _buildHelpItem('A', 'Proporção'),
          _buildHelpItem('Toque', 'Mostrar/ocultar controles'),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String key, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoView(CameraConnection camera) {
    if (camera.renderer.srcObject == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.blue,
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Carregando ${camera.deviceName}...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aguardando stream de vídeo',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Transform.rotate(
        angle: _rotationAngle * (3.14159 / 180), // Converter graus para radianos
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: RTCVideoView(
                camera.renderer,
                objectFit: _aspectRatio,
                mirror: _isMirrored,
                filterQuality: FilterQuality.high,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(List<CameraConnection> cameras, CameraConnection? selectedCamera) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                iconSize: 28,
              ),
              
              const SizedBox(width: 16),
              
              // Camera info
              if (selectedCamera != null) ...[
                const Icon(
                  Icons.videocam,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedCamera.deviceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${selectedCamera.deviceId}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              
              // Battery indicator
              if (selectedCamera != null)
                _buildBatteryIndicator(selectedCamera),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(List<CameraConnection> cameras) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous camera
              if (cameras.length > 1)
                _buildControlButton(
                  icon: Icons.skip_previous,
                  onPressed: _previousCamera,
                  tooltip: 'Câmera anterior',
                ),
              
              // Rotate camera
              _buildControlButton(
                icon: Icons.rotate_90_degrees_ccw,
                onPressed: _rotateCamera,
                tooltip: 'Rotacionar câmera',
              ),

              // Mirror toggle
              _buildControlButton(
                icon: _isMirrored ? Icons.flip : Icons.flip_outlined,
                onPressed: _toggleMirror,
                tooltip: _isMirrored ? 'Desespelhar' : 'Espelhar',
              ),
              
              // Fullscreen toggle
              _buildControlButton(
                icon: _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                onPressed: _toggleFullscreen,
                tooltip: _isFullscreen ? 'Sair da tela cheia' : 'Tela cheia',
              ),
              
              // Settings
              _buildControlButton(
                icon: Icons.settings,
                onPressed: _showSettings,
                tooltip: 'Configurações',
              ),
              
              // Next camera
              if (cameras.length > 1)
                _buildControlButton(
                  icon: Icons.skip_next,
                  onPressed: _nextCamera,
                  tooltip: 'Próxima câmera',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          iconSize: 28,
        ),
      ),
    );
  }

  Widget _buildCameraSelector(List<CameraConnection> cameras) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Câmeras',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cameras.length,
              itemBuilder: (context, index) {
                final camera = cameras[index];
                final isSelected = camera.id == _selectedCameraId;
                
                return GestureDetector(
                  onTap: () => _selectCamera(camera.id),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.videocam,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator(CameraConnection camera) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: batteryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: batteryColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(batteryIcon, color: batteryColor, size: 16),
          const SizedBox(width: 4),
          Text(
            '${camera.batteryLevel}%',
            style: TextStyle(
              color: batteryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _previousCamera() {
    final serverManager = Provider.of<WebSocketServerManager>(context, listen: false);
    final cameras = serverManager.connections.values.toList();
    
    if (cameras.length <= 1) return;
    
    final currentIndex = cameras.indexWhere((c) => c.id == _selectedCameraId);
    final previousIndex = currentIndex > 0 ? currentIndex - 1 : cameras.length - 1;
    
    _selectCamera(cameras[previousIndex].id);
  }

  void _nextCamera() {
    final serverManager = Provider.of<WebSocketServerManager>(context, listen: false);
    final cameras = serverManager.connections.values.toList();
    
    if (cameras.length <= 1) return;
    
    final currentIndex = cameras.indexWhere((c) => c.id == _selectedCameraId);
    final nextIndex = currentIndex < cameras.length - 1 ? currentIndex + 1 : 0;
    
    _selectCamera(cameras[nextIndex].id);
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _disableFullscreen();
    } else {
      _enableFullscreen();
    }
  }

  void _rotateCamera() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  void _toggleMirror() {
    setState(() {
      _isMirrored = !_isMirrored;
    });
  }

  void _changeAspectRatio() {
    setState(() {
      switch (_aspectRatio) {
        case RTCVideoViewObjectFit.RTCVideoViewObjectFitCover:
          _aspectRatio = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
          break;
        case RTCVideoViewObjectFit.RTCVideoViewObjectFitContain:
          _aspectRatio = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
          break;
      }
    });
  }

  String _getAspectRatioText() {
    switch (_aspectRatio) {
      case RTCVideoViewObjectFit.RTCVideoViewObjectFitCover:
        return 'Cobrir tela';
      case RTCVideoViewObjectFit.RTCVideoViewObjectFitContain:
        return 'Ajustar à tela (padrão)';
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configurações de Visualização',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            ListTile(
              leading: const Icon(Icons.aspect_ratio, color: Colors.blue),
              title: const Text(
                'Proporção da Tela',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _getAspectRatioText(),
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () {
                _changeAspectRatio();
                Navigator.pop(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.rotate_90_degrees_ccw, color: Colors.blue),
              title: const Text(
                'Rotação',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${_rotationAngle.toInt()}° - Toque para rotacionar 90°',
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () {
                _rotateCamera();
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: Icon(
                _isMirrored ? Icons.flip : Icons.flip_outlined, 
                color: Colors.blue
              ),
              title: const Text(
                'Espelhar Imagem',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _isMirrored ? 'Imagem espelhada' : 'Imagem normal',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Switch(
                value: _isMirrored,
                onChanged: (value) {
                  _toggleMirror();
                  setState(() {}); // Atualizar o modal
                },
                activeColor: Colors.blue,
              ),
              onTap: () {
                _toggleMirror();
              },
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
