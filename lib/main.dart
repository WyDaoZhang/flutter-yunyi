import 'package:demo1/pages/home/sinkaf.dart';
import 'package:demo1/pages/login/enroll.dart';
import 'package:demo1/pages/home/index.dart';
import 'package:demo1/pages/login/login.dart';
import 'package:demo1/pages/setting/email.dart';
import 'package:demo1/utils/token.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  // 确保Flutter绑定完成
  WidgetsFlutterBinding.ensureInitialized();
  // 提前初始化TokenManager并等待其完成
  final tokenManager = TokenManager();
  await tokenManager.init();
  runApp(
    MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations
            .delegate, //是Flutter的一个本地化委托，用于提供Material组件库的本地化支持
        GlobalWidgetsLocalizations.delegate, //用于提供通用部件（Widgets）的本地化支持
        GlobalCupertinoLocalizations.delegate, //用于提供Cupertino风格的组件的本地化支持
      ],
      supportedLocales: [
        const Locale('zh', 'CN'), // 支持的语言和地区
      ],
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) => ChatPage(),
      },
      onGenerateRoute: (settings) {
        final tokenManager = TokenManager();
        tokenManager.init(); // 确保初始化token
        final token = tokenManager.getToken() ?? '';
        // 处理根路由 '/' 和未定义的路由
        if (settings.name == '/' || settings.name == null) {
          if (token.isNotEmpty) {
            // 有token时返回主页
            return MaterialPageRoute(builder: (context) => ChatPage());
          } else {
            // 无token时重定向到登录页
            return MaterialPageRoute(builder: (context) => const LoginPage());
          }
        }
        return null;
      },

      // onGenerateRoute: (settings) {
      //   final tokenManager = TokenManager();
      //   final token = tokenManager.getToken() ?? '';
      //   if (token.isEmpty) {
      //     return MaterialPageRoute(builder: (context) => const LoginPage());
      //   }
      // },
    ),
  );
}
