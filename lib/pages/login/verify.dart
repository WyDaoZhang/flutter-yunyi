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

  String ckID = '';
  String? token = '';

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

  // 下一步按钮点击事件
  void _handleNextStep() async {
    String phone = _phoneController.text;
    String code = _codeController.text;

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
    // eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVaWQiOiJjNGYxYmU0Mi1jNDYzLTRkNzItODI2Zi1mN2JiNWQ2ZjBmMGUiLCJVc2VySWQiOiIxMDAwMDAwMDAwNCJ9.uGfxc-TvMWFg6e-z6DpWdCMVwCwToVc-gOzMaf07vIw
    debugPrint('登录结果: ' + resa['data'].toString());

    TokenManager().saveToken(resa['data']['token']);
    Future.delayed(Duration.zero, () async {
      await TokenManager().init();
      token = await TokenManager().getToken();
    });
    debugPrint('TokenManager init$token');

    // TODO: 实现登录验证逻辑
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 计算rpx (以750设计稿为基准)
    final double rpx = MediaQuery.of(context).size.width / 750;
    // 获取屏幕宽度，用于响应式调整
    final screenWidth = MediaQuery.of(context).size.width;

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
              GestureDetector(
                child: IconButton(
                  padding: EdgeInsets.symmetric(
                    horizontal: 48 * rpx,
                    vertical: 48 * rpx,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black54,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),

              // 主内容区域
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 48 * rpx,
                    vertical: 40 * rpx,
                  ),
                  child: Column(
                    children: [
                      // 头像
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: const DecorationImage(
                            image: AssetImage('assets/login/1.png'),
                          ),
                        ),
                      ),
                      SizedBox(height: 60 * rpx),

                      // 手机号输入框
                      TextField(
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
                            fontSize: 28 * rpx,
                            color: Colors.grey[400],
                          ),
                          prefixText: '+86 ',
                          prefixStyle: TextStyle(
                            fontSize: 28 * rpx,
                            color: Colors.black87,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50 * rpx),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 24 * rpx,
                          ),
                        ),
                        style: TextStyle(fontSize: 28 * rpx),
                      ),
                      SizedBox(height: 20 * rpx),

                      // 验证码输入框（包含获取按钮）
                      TextField(
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
                            fontSize: 28 * rpx,
                            color: Colors.grey[400],
                          ),
                          // 右侧添加获取验证码按钮
                          suffix: Padding(
                            padding: EdgeInsets.only(right: 15 * rpx),
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: 15 * rpx,
                                  vertical: 8 * rpx,
                                ),
                                backgroundColor: _isCounting
                                    ? Colors.grey[300]
                                    : Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30 * rpx),
                                ),
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              child: Text(
                                _countdownText,
                                style: TextStyle(
                                  // 根据屏幕宽度动态调整字体大小
                                  fontSize: screenWidth < 360
                                      ? 20 * rpx
                                      : 22 * rpx,
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50 * rpx),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 24 * rpx,
                            horizontal: 15 * rpx,
                          ),
                        ),
                        style: TextStyle(fontSize: 28 * rpx),
                      ),
                      SizedBox(height: 60 * rpx),

                      // 下一步按钮
                      SizedBox(
                        width: double.infinity,
                        height: 96 * rpx,
                        child: ElevatedButton(
                          onPressed: _handleNextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50 * rpx),
                            ),
                          ),
                          child: Text(
                            '下一步',
                            style: TextStyle(
                              fontSize: 32 * rpx,
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
