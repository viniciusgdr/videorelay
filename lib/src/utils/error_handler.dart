import 'package:flutter/foundation.dart';

class ErrorHandler {
  static void logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('StreamEasy Error: $message');
      if (error != null) {
        print('Error Details: $error');
      }
      if (stackTrace != null) {
        print('Stack Trace: $stackTrace');
      }
    }
  }

  static void logInfo(String message) {
    if (kDebugMode) {
      print('StreamEasy Info: $message');
    }
  }

  static void logWarning(String message) {
    if (kDebugMode) {
      print('StreamEasy Warning: $message');
    }
  }

  static String getErrorMessage(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }

  static String getCameraErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('permission')) {
      return 'Permissão da câmera negada. Verifique as configurações do app.';
    }
    
    if (errorStr.contains('not found') || errorStr.contains('unavailable')) {
      return 'Câmera não encontrada ou indisponível.';
    }
    
    if (errorStr.contains('busy') || errorStr.contains('in use')) {
      return 'Câmera em uso por outro aplicativo.';
    }
    
    if (errorStr.contains('resolution') || errorStr.contains('constraint')) {
      return 'Configurações de resolução não suportadas pela câmera.';
    }
    
    return 'Erro ao acessar câmera: ${getErrorMessage(error)}';
  }

  static String getWebSocketErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('connection refused') || errorStr.contains('failed to connect')) {
      return 'Não foi possível conectar ao servidor. Verifique o endereço e porta.';
    }
    
    if (errorStr.contains('timeout')) {
      return 'Tempo limite de conexão esgotado.';
    }
    
    if (errorStr.contains('network')) {
      return 'Erro de rede. Verifique sua conexão com a internet.';
    }
    
    return 'Erro de conexão WebSocket: ${getErrorMessage(error)}';
  }

  static String getWebRTCErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('ice')) {
      return 'Erro na negociação ICE. Problemas de conectividade de rede.';
    }
    
    if (errorStr.contains('sdp')) {
      return 'Erro na troca de descrições SDP.';
    }
    
    if (errorStr.contains('codec')) {
      return 'Codec de vídeo não suportado.';
    }
    
    return 'Erro WebRTC: ${getErrorMessage(error)}';
  }
}
