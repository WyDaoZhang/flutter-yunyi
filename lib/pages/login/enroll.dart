import 'dart:async';
import 'dart:math';
import 'package:demo1/utils/http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/toast.dart';

/// 云奕AI注册页面
class VerifyPage1 extends StatefulWidget {
  const VerifyPage1({Key? key}) : super(key: key);

  @override
  State<VerifyPage1> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<VerifyPage1> {
  // 输入控制器
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  // 倒计时相关
  bool _isCounting = false;
  int _countdownSeconds = 60;
  String _countdownText = '获取验证码';
  String ckID = '';

  /// 开始倒计时逻辑
  void _startCountdown() async {
    setState(() {
      _isCounting = true;
    });
    final resa = await http.get(
      'auth/getMobileCode?mobile=${_phoneController.text}',
    );
    ckID = resa['data'];
    debugPrint('登录结果: ' + resa['data'].toString());
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

  /// 验证手机号格式
  bool _isValidPhone(String phone) {
    return phone.length == 11 && RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }

  /// 验证表单数据
  bool _validateForm() {
    if (_accountController.text.trim().isEmpty) {
      ToastUtil.showError('请输入账号');
      return false;
    }
    if (_passwordController.text.trim().isEmpty ||
        _passwordController.text.length < 6) {
      ToastUtil.showError('请输入6位及以上密码');
      return false;
    }
    if (_confirmPasswordController.text.trim() !=
        _passwordController.text.trim()) {
      ToastUtil.showError('两次输入的密码不一致');
      return false;
    }
    if (!_isValidPhone(_phoneController.text.trim())) {
      ToastUtil.showError('请输入正确的手机号');
      return false;
    }
    if (_codeController.text.trim().length != 6) {
      ToastUtil.showError('请输入6位验证码');
      return false;
    }
    return true;
  }

  /// 注册按钮点击事件
  void _handleRegister() async {
    if (_validateForm()) {
      // final registerData = {
      //   'account': _accountController.text,
      //   'password': _passwordController.text,
      //   'confirmPassword': _confirmPasswordController.text,
      //   'phone': _phoneController.text,
      //   'code': _codeController.text,
      // };
      // TODO: 实现注册API调用，比如调用后端接口
      // 示例：调用成功后可跳转首页
      // Navigator.pushReplacementNamed(context, '/home');
      final resas = await http.post(
        'auth/registerKey',
        data: {
          'ck': _codeController.text,
          'ckId': ckID,
          'cpk': _confirmPasswordController.text,
          'mobile': _phoneController.text,
          'pk': _passwordController.text,
          'uk': _accountController.text,
        },
      );

      if (resas['code'] == 200) {
        ToastUtil.showInfo(resas['msg']);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 用于响应式适配，以375px设计稿宽度为基准
    final double rpx = MediaQuery.of(context).size.width / 375;

    return Scaffold(
      // 背景设置，可根据实际需求替换为颜色或图片等
      backgroundColor: const Color(0xFFEAF5FF),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 40 * rpx),
          child: Container(
            width: min(500 * rpx, MediaQuery.of(context).size.width * 0.85),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16 * rpx),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10 * rpx,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(30 * rpx),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Center(
                    child: Text(
                      '云奕AI',
                      style: TextStyle(
                        fontSize: 32 * rpx,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ),
                  SizedBox(height: 30 * rpx),

                  // 账号输入框
                  _buildInputField(
                    controller: _accountController,
                    label: '账号',
                    hintText: '请输入账号',
                    iconData: Icons.person,
                    rpx: rpx,
                  ),
                  SizedBox(height: 15 * rpx),

                  // 密码输入框
                  _buildInputField(
                    controller: _passwordController,
                    label: '密码',
                    hintText: '请输入密码',
                    iconData: Icons.lock,
                    isPassword: true,
                    rpx: rpx,
                  ),
                  SizedBox(height: 15 * rpx),

                  // 确认密码输入框
                  _buildInputField(
                    controller: _confirmPasswordController,
                    label: '确认密码',
                    hintText: '请确认密码',
                    iconData: Icons.lock,
                    isPassword: true,
                    rpx: rpx,
                  ),
                  SizedBox(height: 15 * rpx),

                  // 手机号输入框
                  _buildInputField(
                    controller: _phoneController,
                    label: '手机号',
                    hintText: '请输入手机号',
                    iconData: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    rpx: rpx,
                  ),
                  SizedBox(height: 15 * rpx),

                  // 验证码输入框 + 获取验证码按钮
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: _codeController,
                          label: '验证码',
                          hintText: '验证码',
                          iconData: Icons.verified_user,
                          rpx: rpx,
                        ),
                      ),
                      SizedBox(width: 10 * rpx),
                      _buildCodeButton(rpx),
                    ],
                  ),
                  SizedBox(height: 30 * rpx),

                  // 注册按钮
                  SizedBox(
                    width: double.infinity,
                    height: 50 * rpx,
                    child: ElevatedButton(
                      onPressed: _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF409EFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8 * rpx),
                        ),
                      ),
                      child: Text(
                        '注册',
                        style: TextStyle(
                          fontSize: 16 * rpx,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20 * rpx),

                  // 已有账号登录引导
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        // TODO: 跳转登录页面逻辑
                        Navigator.pop(context);
                      },
                      child: Text(
                        '使用已有账户登录',
                        style: TextStyle(
                          color: const Color(0xFF9933CC),
                          fontSize: 14 * rpx,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 通用输入框组件
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData iconData,
    bool isPassword = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required double rpx,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(8 * rpx),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(fontSize: 14 * rpx, color: const Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14 * rpx,
            color: const Color(0xFF999999),
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15 * rpx),
            child: Icon(
              iconData,
              color: const Color(0xFF999999),
              size: 20 * rpx,
            ),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12 * rpx),
        ),
      ),
    );
  }

  /// 验证码按钮组件
  Widget _buildCodeButton(double rpx) {
    return ElevatedButton(
      onPressed: _isCounting
          ? null
          : () {
              String phone = _phoneController.text.trim();
              if (phone.isEmpty || !_isValidPhone(phone)) {
                ToastUtil.showError('请输入正确手机号');
                return;
              }
              _startCountdown();
              // TODO: 调用发送验证码接口逻辑
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isCounting
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF409EFF),
        foregroundColor: _isCounting ? const Color(0xFF999999) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8 * rpx),
        ),
        padding: EdgeInsets.symmetric(horizontal: 15 * rpx, vertical: 12 * rpx),
      ),
      child: Text(_countdownText, style: TextStyle(fontSize: 14 * rpx)),
    );
  }
}
