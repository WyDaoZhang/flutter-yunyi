import 'package:demo1/utils/config.dart';
import 'package:demo1/utils/evntbus.dart';
import 'package:demo1/utils/toast.dart';
import 'package:demo1/utils/token.dart';
import 'package:dio/dio.dart';

class NetworkService {
  // 创建Dio实例
  final Dio _dio = Dio();

  // 构造函数：初始化配置
  NetworkService() {
    // 基础配置
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    _dio.options.headers = {'Content-Type': 'application/json'};

    // 重定向配置（关键：处理301/302）
    _dio.options.followRedirects = true; // 允许自动重定向
    _dio.options.maxRedirects = 5; // 最大重定向次数（防止无限循环）

    // 添加拦截器（Token、日志、错误处理）
    _addInterceptors();
  }

  // 添加拦截器
  void _addInterceptors() {
    // 1. Token拦截器：添加请求头
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 获取本地Token并添加到请求头
          final token = TokenManager().getToken() ?? '';
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // 响应预处理：可在这里统一解析业务码（如code=200）
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          // 错误预处理：如401自动刷新Token（扩展功能）
          return handler.next(error);
        },
      ),
    );

    // // 2. 日志拦截器（可选：方便调试，需在pubspec.yaml添加dio_logger依赖）
    // _dio.interceptors.add(
    //   DioLogger(
    //     level: Level.body, // 打印请求/响应体
    //     compact: false, // 不压缩日志
    //     responseBody: true, // 打印响应内容
    //   ),
    // );
  }

  // GET请求
  Future<dynamic> get(String url, {Map<String, dynamic>? params}) async {
    try {
      final response = await _dio.get(url, queryParameters: params);
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // POST请求
  Future<dynamic> post(String url, {dynamic data}) async {
    try {
      final response = await _dio.post(url, data: data);
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // PUT请求
  Future<dynamic> put(String url, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.put(url, data: data);
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // DELETE请求
  Future<dynamic> delete(String url, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.delete(url, data: data);
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // 响应处理：区分成功/业务错误
  dynamic _handleResponse(Response response) {
    // 1. HTTP状态码处理（200-299：成功；301-302：重定向已自动处理）
    if ((response.statusCode! >= 200 && response.statusCode! < 300) ||
        response.statusCode == 301 ||
        response.statusCode == 302) {
      // 2. 业务码处理（根据后端实际规则调整）
      final responseData = response.data;
      if (responseData is Map && responseData.containsKey('code')) {
        // 示例：假设code=200为业务成功，其他为业务错误
        if (responseData['code'] == 200) {
          return responseData; // 返回完整数据（含data、msg等）
        } else {
          ToastUtil.showError(responseData['msg']);
          throw Exception('业务错误：${responseData['msg'] ?? '未知错误'}');
        }
      }
      // 若后端无统一业务码，直接返回数据
      return responseData;
    } else {
      throw Exception('请求失败（HTTP状态码：${response.statusCode}）');
    }
  }

  // 错误处理：区分网络错误/服务器错误
  dynamic _handleError(dynamic error) async {
    if (error is DioException) {
      // 1. 网络相关错误
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw Exception('网络超时，请检查网络');
      } else if (error.type == DioExceptionType.connectionError) {
        throw Exception('网络连接失败，请检查网络');
      } else if (error.type == DioExceptionType.cancel) {
        throw Exception('请求已取消');
      }

      // 2. 服务器响应错误（4xx/5xx）
      if (error.type == DioExceptionType.badResponse) {
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        // 401：Token失效（跳转登录页）
        if (statusCode == 401) {
          await TokenManager().removeToken(); // 清除本地Token
          eventBus.fire(LogoutEvent()); // 触发登录页跳转

          throw Exception('登录已过期，请重新登录');
        }

        // 其他状态码（如403/404/500）
        String errorMsg = '服务器错误（HTTP状态码：$statusCode）';
        if (responseData is Map && responseData.containsKey('msg')) {
          errorMsg = responseData['msg']; // 使用后端返回的错误信息
        }
        throw Exception(errorMsg);
      }
    }

    // 3. 其他未知错误
    throw Exception('未知错误：${error.toString()}');
  }
}

// 全局实例：整个项目使用同一网络实例
final http = NetworkService();
