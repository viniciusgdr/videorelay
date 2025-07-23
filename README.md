# StreamEasy - Sistema de Streaming de Câmeras Mobile/Desktop

Um sistema completo de streaming de câmeras usando Flutter e WebRTC, com cliente mobile e servidor desktop avançados.

## 🚀 Funcionalidades Principais

### 📱 Cliente Mobile (main.dart)

#### ✅ Sistema de Permissões Robusto
- Solicitação automática de permissões de câmera e microfone
- Verificação prévia antes de iniciar o streaming
- Interface amigável para guiar o usuário

#### 🔧 Configurações Avançadas de Streaming
- **Resoluções**: 640x480 (VGA), 1280x720 (HD), 1920x1080 (Full HD), 3840x2160 (4K)
- **Frame Rate**: 15, 24, 30, 60 FPS configuráveis
- **Bitrate**: Configurável de 500Kbps a 20Mbps (min/max)
- **Seleção de Câmera**: Traseira, frontal ou câmera específica por ID
- **Áudio**: Liga/desliga captura de áudio
- **Servidor**: Configuração dinâmica de IP e porta

#### 🔋 Monitoramento de Bateria e Dispositivo
- **Bateria em Tempo Real**: Nível e status atualizados automaticamente
- **Informações do Dispositivo**: Nome, modelo e sistema operacional
- **Atualizações Automáticas**: A cada minuto ou em mudanças de estado
- **Envio via WebSocket**: Transmissão das informações para o servidor

#### 🛠️ Sistema de Tratamento de Erros Avançado
- Mensagens específicas e amigáveis
- Logging detalhado para debug
- Tratamento para todos os tipos de erro:
  - Permissões de câmera/microfone
  - Conexões WebSocket
  - Negociação WebRTC
  - Recursos não suportados

#### 🔄 Sistema de Reconexão Inteligente
- Reconexão automática em falhas
- Limite de tentativas (5 máximo)
- Delay progressivo entre tentativas
- Status visual de conexão

### �️ Servidor Desktop (main_server.dart)

#### 📹 Gerenciamento Multi-Câmera
- **Suporte Múltiplas Câmeras**: Conecte vários dispositivos simultaneamente
- **Visualização Individual**: Cada câmera tem seu próprio preview
- **Seleção Dinâmica**: Alterne entre câmeras facilmente
- **Janelas Separadas**: Abra janelas independentes para cada câmera

#### � Monitoramento de Dispositivos
- **Status de Bateria**: Visualização em tempo real do nível de bateria
- **Informações do Dispositivo**: Nome, modelo e sistema operacional
- **Status de Conexão**: Indicadores visuais de conectividade
- **Última Atividade**: Timestamp da última comunicação

#### 🎨 Interface Customizável
- **Configurações de UI**: Altura dos previews, câmeras por linha
- **Temas**: Modo claro e escuro
- **Layout Adaptativo**: Interface responsiva
- **Controles Avançados**: Configurações detalhadas

#### ⚙️ Configurações Avançadas do Servidor
- **Porta Configurável**: Altere a porta WebSocket dinamicamente
- **Reinicialização Automática**: Servidor reinicia ao mudar configurações
- **Interface de Configurações**: Tela dedicada para ajustes
- **Persistência**: Configurações salvas automaticamente

## 📁 Estrutura do Projeto

```
lib/
├── main.dart                          # Cliente mobile principal
├── main_server.dart                   # Servidor desktop
├── screens/
│   └── settings.dart                  # Configurações do servidor
├── src/
│   ├── config/
│   │   ├── streaming_config.dart      # Configurações de streaming
│   │   └── server_ui_config.dart      # Configurações de interface
│   ├── services/
│   │   └── device_info_service.dart   # Serviço de bateria/dispositivo
│   ├── utils/
│   │   └── error_handler.dart         # Tratamento de erros
│   ├── hooks/
│   │   └── websocket_server.dart      # Gerenciador do servidor WebSocket
│   └── widgets/
│       └── screen_select_dialog.dart  # Diálogo de seleção de tela
```

## 🔧 Dependências Principais

```yaml
dependencies:
  flutter_webrtc: ^0.14.2        # WebRTC para streaming
  permission_handler: ^12.0.1    # Gerenciamento de permissões
  web_socket_channel: ^3.0.3     # Comunicação WebSocket
  shared_preferences: ^2.5.3     # Persistência de configurações
  provider: ^6.1.2               # Gerenciamento de estado
  battery_plus: ^6.1.1           # Monitoramento de bateria
  device_info_plus: ^11.2.0      # Informações do dispositivo
```

## 🚀 Como Usar

### 1. Executar o Servidor Desktop
```bash
# Iniciar servidor (porta padrão 8080)
flutter run -t lib/main_server.dart

# O servidor ficará disponível em:
# ws://localhost:8080 (ou sua porta personalizada)
```

### 2. Executar Cliente Mobile
```bash
# Iniciar cliente mobile
flutter run -t lib/main.dart

# Configure o servidor nas configurações do app
```

### 3. Configuração Inicial

#### No Servidor:
1. Abra as configurações (⚙️)
2. Configure a porta desejada
3. Ajuste as configurações de interface
4. O servidor ficará aguardando conexões

#### No Mobile:
1. Conceda permissões de câmera e microfone
2. Configure o servidor (IP:porta do servidor)
3. Ajuste qualidade de vídeo conforme necessário
4. Toque em "Iniciar" para começar o streaming

### 4. Funcionalidades Avançadas

#### Janelas Múltiplas (Servidor):
- Clique no ícone de janela (⊞) para abrir janelas separadas
- Cada câmera terá sua própria janela independente
- Informações de bateria e dispositivo em cada janela

#### Monitoramento de Bateria:
- Visualização automática no servidor
- Cores indicativas: Verde (>50%), Laranja (20-50%), Vermelho (<20%)
- Ícones representativos do nível de bateria
- Status: Carregando, Descarregando, Completa, etc.

## 📊 Recursos de Monitoramento

### Informações Enviadas pelo Mobile:
- **Bateria**: Nível (%), status (carregando/descarregando)
- **Dispositivo**: Nome, modelo, sistema operacional
- **Conectividade**: Status da conexão WebRTC
- **Performance**: FPS, bitrate, resolução

### Visualizadas no Servidor:
- **Dashboard**: Visão geral de todas as câmeras
- **Previews**: Miniatura de cada stream de vídeo
- **Status**: Conectividade e saúde de cada conexão
- **Bateria**: Indicadores visuais com cores e ícones

## ⚙️ Configurações Detalhadas

### Cliente Mobile:
- **Resolução**: Até 4K (3840x2160)
- **Frame Rate**: Até 60 FPS
- **Bitrate**: Até 20 Mbps
- **Servidor**: IP:porta configurável
- **Câmera**: Seleção automática ou manual
- **Áudio**: Opcional

### Servidor Desktop:
- **Porta**: 1-65535 (padrão 8080)
- **UI**: Altura dos previews (80-200px)
- **Layout**: 2-8 câmeras por linha
- **Temas**: Claro/escuro
- **Janelas**: Habilitadas por padrão

## 🔍 Debugging e Logs

### Logs Disponíveis:
- **Configurações**: Carregamento/salvamento
- **Conexões**: Estados WebSocket/WebRTC
- **Bateria**: Atualizações de status
- **Erros**: Stack traces completos
- **Performance**: Estatísticas de streaming

### Visualizar Logs:
```bash
# Flutter logs
flutter logs

# Android específico
adb logcat | grep "StreamEasy"

# Filtrar por componente
adb logcat | grep "WebSocket\|WebRTC\|Battery"
```

## 🐛 Troubleshooting

### Problemas Comuns:

#### Cliente não conecta:
- ✅ Verificar IP e porta do servidor
- ✅ Confirmar que servidor está executando
- ✅ Verificar firewall/rede
- ✅ Testar com IP local (192.168.x.x)

#### Qualidade ruim de vídeo:
- ✅ Reduzir resolução/FPS
- ✅ Ajustar bitrate conforme rede
- ✅ Verificar CPU do dispositivo
- ✅ Testar diferentes câmeras

#### Bateria não aparece:
- ✅ Verificar permissões do dispositivo
- ✅ Reiniciar conexão
- ✅ Verificar logs do cliente
- ✅ Testar em dispositivo físico

#### Múltiplas câmeras:
- ✅ Cada dispositivo precisa conectar separadamente
- ✅ Usar IPs únicos ou portas diferentes
- ✅ Verificar capacidade da rede
- ✅ Monitorar uso de CPU/memória

## 🎯 Cenários de Teste

### Testes de Conectividade:
- [ ] Servidor local (localhost)
- [ ] Servidor em rede local (192.168.x.x)
- [ ] Múltiplos dispositivos simultâneos
- [ ] Reconexão após perda de rede
- [ ] Diferentes portas

### Testes de Qualidade:
- [ ] Todas as resoluções (VGA até 4K)
- [ ] Todos os frame rates (15-60 FPS)
- [ ] Diferentes bitrates
- [ ] Com e sem áudio
- [ ] Diferentes câmeras (frontal/traseira)

### Testes de Bateria:
- [ ] Monitoramento em tempo real
- [ ] Mudanças de estado (carregando/descarregando)
- [ ] Diferentes níveis de bateria
- [ ] Múltiplos dispositivos
- [ ] Reconexão mantém informações

### Testes de Interface:
- [ ] Tema claro/escuro
- [ ] Redimensionamento de janelas
- [ ] Múltiplas janelas de câmera
- [ ] Configurações persistem
- [ ] Layout responsivo

## 🔮 Melhorias Futuras

- [ ] Gravação de vídeo no servidor
- [ ] Streaming RTMP/HLS
- [ ] Controle remoto de configurações
- [ ] Analytics de performance
- [ ] Suporte a plugins de vídeo
- [ ] API REST para controle externo
- [ ] Notificações push
- [ ] Streaming para múltiplos destinos
- [ ] Compressão avançada de vídeo
- [ ] Sincronização de áudio/vídeo

## � Suporte Técnico

Para problemas ou dúvidas:

1. **Verificar Logs**: Use `flutter logs` para diagnósticos
2. **Configurações**: Reset para padrão se necessário  
3. **Rede**: Verificar conectividade e firewall
4. **Hardware**: Confirmar compatibilidade de câmeras
5. **Performance**: Monitorar uso de CPU/memória

---

## 🏆 Principais Melhorias Implementadas

✅ **Sistema multi-câmera** - Suporte a múltiplos dispositivos
✅ **Monitoramento de bateria** - Tempo real e histórico  
✅ **Interface customizável** - Temas e layouts configuráveis
✅ **Janelas separadas** - Preview independente para cada câmera
✅ **Configurações persistentes** - Salvamento automático
✅ **Tratamento robusto de erros** - Mensagens específicas
✅ **Reconexão inteligente** - Recuperação automática
✅ **Logs detalhados** - Debug facilitado
✅ **Performance otimizada** - Uso eficiente de recursos
