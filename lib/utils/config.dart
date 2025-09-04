// 全局配置文件

/// API配置类
class ApiConfig {
  static const String baseUrl = 'http://192.168.1.127:12111/api/v1/';

  /// WebSocket连接URL
  static String getWebSocketUrl(String token) {
    return 'ws://192.168.1.127:12111/api/v1/chat/api_server/api/ws?token=$token';
  }

  /// 语音音频流URL
  static String getAudioStreamUrl(String messageId, String token) {
    return 'http://192.168.1.127:12111/api/v1/voice/audio/stream/$messageId?token=$token';
  }
}
