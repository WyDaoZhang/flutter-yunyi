import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/http.dart';
import '../../utils/toast.dart';
import '../../utils/token.dart';
import '../home/index.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isCounting = false;
  int _countdownSeconds = 60;
  String _countdownText = '获取验证码';

  //登录状态
  bool _isLogin = false;

  String ckID = '';
  String? token = '';

  // 固定输入框尺寸
  final double inputWidth = 320;
  final double inputHeight = 56;
  final double fontSize = 16;

  // 倒计时逻辑
  void _startCountdown() async {
    final resa = await http.get(
      'auth/getMobileCode?mobile=${_phoneController.text}',
    );
    ckID = resa['data'];
    debugPrint('登录结果: ' + resa['data'].toString());
    setState(() => _isCounting = true);
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds == 0) {
        setState(() {
          _isCounting = false;
          _countdownSeconds = 60;
          _countdownText = '获取验证码';
        });
        timer.cancel();
      } else {
        setState(() {
          _countdownSeconds--;
          _countdownText = '重新获取($_countdownSeconds)';
        });
      }
    });
  }

  // 验证手机号格式
  bool _isValidPhone(String phone) {
    return phone.length == 11 && RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }

  @override
  void dispose() {
    // 清理控制器
    _phoneController.dispose();
    _codeController.dispose();

    super.dispose();
  }

  // 下一步按钮点击事件
  void _handleNextStep() async {
    String phone = _phoneController.text;
    String code = _codeController.text;

    setState(() {
      _isLogin = true;
    });

    try {
      if (!_isValidPhone(phone)) {
        ToastUtil.showError('请输入正确的手机号');
        return;
      }

      if (code.isEmpty || code.length != 6) {
        ToastUtil.showError('请输入6位验证码');
        return;
      }
      final resa = await http.post(
        'auth/loginKey',
        data: {
          'ak': _phoneController.text,
          'ck': _codeController.text,
          'lt': '2',
          'ckId': ckID,
        },
      );
      debugPrint('登录结果: ' + resa['data'].toString());

      TokenManager().saveToken(resa['data']['token']);
      Future.delayed(Duration.zero, () async {
        await TokenManager().init();
        token = await TokenManager().getToken();
      });
      debugPrint('TokenManager init$token');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => ChatPage()),
        (route) => false,
      );
    } catch (e) {
      ToastUtil.showInfo('登录失败');
    } finally {
      setState(() {
        _isLogin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/login/3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 返回按钮
              IconButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.black54,
                ),
                onPressed: () => Navigator.pop(context),
              ),

              // 主内容区域
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      // 头像
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: AssetImage('assets/login/1.png'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 手机号输入框（固定尺寸）
                      SizedBox(
                        width: inputWidth,
                        height: inputHeight,
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '请输入手机号',
                            hintStyle: TextStyle(
                              fontSize: fontSize,
                              color: Colors.grey[400],
                            ),
                            // 使用prefix参数添加带边距的+86（这是正确的用法）
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 12), // 左边距12像素
                              child: Text('+86 '),
                            ),
                            prefixStyle: TextStyle(
                              fontSize: fontSize,
                              color: Colors.black87,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                          style: TextStyle(fontSize: fontSize),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // 验证码输入框
                      SizedBox(
                        width: inputWidth,
                        height: inputHeight,
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '请输入验证码',
                            hintStyle: TextStyle(
                              fontSize: fontSize,
                              color: Colors.grey[400],
                            ),
                            suffix: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: TextButton(
                                onPressed: _isCounting
                                    ? null
                                    : () {
                                        String phone = _phoneController.text;
                                        if (!_isValidPhone(phone)) {
                                          ToastUtil.showError('请输入正确手机号');
                                          return;
                                        }
                                        _startCountdown();
                                      },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  backgroundColor: _isCounting
                                      ? Colors.grey[300]
                                      : Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _countdownText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                          ),
                          style: TextStyle(fontSize: fontSize),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 下一步按钮
                      SizedBox(
                        width: inputWidth,
                        height: inputHeight,
                        child: ElevatedButton(
                          onPressed: _isLogin
                              ? null
                              : _handleNextStep, // 加载中禁用按钮
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _isLogin
                              ? // 加载状态显示圆形进度指示器
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : // 正常状态显示下一步文本
                                const Text(
                                  '下一步',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
