import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  // 2. 私有变量
  String? _token = '';
  // 3. 常量
  final String _key = 'enjoy_token_three';

  // 1. 创建一个单例
  static TokenManager? _instance;
  TokenManager._internal();
  factory TokenManager() {
    _instance ??= TokenManager._internal();
    return _instance!;
  }

  // 4. 提供init方法用于从本地获取token
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_key) ?? '';
  }

  // 5. 提供saveToken方法用于存储token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
    _token = token;
  }

  // 6. 提供getToken方法用于同步获取token
  String? getToken() {
    return _token;
  }

  // 7. 提供removeToken方法用于删除token
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _token = null;
  }
}
