import 'dart:convert';

import 'package:demo1/pages/login/verify.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../utils/http.dart';
import '../../utils/toast.dart';
import '../../utils/token.dart';
import '../home/index.dart';
import 'agreement.dart';
import 'enroll.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login UI',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}

// 有状态组件
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 定义状态变量
  bool _agreedToTerms = false; // 协议勾选状态
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    // 清理控制器
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // final channel = IOWebSocketChannel.connect(
  //   'ws://192.168.1.117/chat/api_server/api/ws',
  // );

  String age =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVaWQiOiJlZDhmMDk2Yi1lODRmLTRkYmEtYjE0Yy03ODEwNzgzNTg5YjciLCJVc2VySWQiOiIxMDAwMDAwMDAwMCJ9.iOgSY0EcHpcvLFMRqONP_3TXeeLb2aqy81bKMgMHQCI';
  // 登录按钮点击事件
  void _handleLogin() async {
    if (!_agreedToTerms) {
      ToastUtil.showError('请勾选协议');
      return; // 未勾选协议时直接返回，不继续执行后续逻辑
    }

    // 协议已勾选，继续验证手机号
    String mobile = _usernameController.text;
    if (mobile.isEmpty) {
      ToastUtil.showError('请输入用户名密码');
      return;
    }
    // final resa = await http.post(
    //   '/auth/loginKey',
    //   data: {
    //     'ak': _usernameController.text,
    //     'pk': _passwordController.text,
    //     'lt': '1',
    //   },
    // );
    // debugPrint('登录结果: ' + resa['data'].toString());

    // var res = await http.get('/getUserInfo');
    // debugPrint('获取用户信息: $res');
    // TokenManager tokenManager = TokenManager();
    // //存储token
    // await tokenManager.saveToken(age);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage()),
    );
  }

  // 注册按钮点击事件
  void _handleRegister() {
    if (!_agreedToTerms) {
      ToastUtil.showError('请勾选协议');
      return; // 未勾选协议时直接返回，不继续执行后续逻辑
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VerifyPage1()),
    );
  }

  // 验证码登录按钮点击事件
  void _handleSmsLogin() {
    if (!_agreedToTerms) {
      ToastUtil.showError('请勾选协议');
      return; // 未勾选协议时直接返回，不继续执行后续逻辑
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VerifyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/login/3.png'),
            fit: BoxFit.cover, // 图片填充方式
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 头像
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/login/1.png'),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // 用户名输入框
                TextField(
                  controller: _usernameController, // 关联控制器
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '请输入用户名',
                    hintStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // 密码输入框
                TextField(
                  controller: _passwordController, // 关联控制器
                  obscureText: true,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '请输入密码',
                    hintStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                // 登录按钮
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text(
                    '登录',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                // 注册按钮
                Opacity(
                  opacity: 0.5,
                  child: ElevatedButton(
                    onPressed: _handleRegister,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Text(
                      '注册',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 验证码登录
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _handleSmsLogin,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('验证码登录', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        // 优化箭头图标位置
                        Transform.translate(
                          offset: Offset(0, 1.1),
                          child: Image.asset(
                            'assets/login/5.png',
                            width: 15,
                            height: 15,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 70),
                Text(
                  '第三方登录',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 第三方登录图标按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image(
                            image: AssetImage('./assets/login/2.png'),
                            width: 42,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image(
                            image: AssetImage('./assets/login/8.png'),
                            width: 42,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image(
                            image: AssetImage('./assets/login/7.png'),
                            width: 42,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image(
                            image: AssetImage('./assets/login/6.png'),
                            width: 42,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 协议勾选及文本
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      shape: CircleBorder(),
                      value: _agreedToTerms,
                      activeColor: Colors.blue,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _agreedToTerms = value;
                          });
                        }
                      },
                    ),
                    const Text(
                      '同意并阅读',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AgreementPage(),
                            settings: const RouteSettings(
                              arguments: {'title': '用户协议'},
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        '《用户协议》',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AgreementPage(),
                            settings: const RouteSettings(
                              arguments: {'title': '隐私政策'},
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        '《隐私政策》',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ),

                    // const Text(
                    //   '《用户协议》《隐私政策》',
                    //   style: TextStyle(fontSize: 14, color: Colors.blue),

                    // ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
