import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/toast.dart';


/// 注册验证页面
/// 包含手机号、验证码、姓名和AI昵称输入，以及注册功能
class VerifyPage1 extends StatefulWidget {
  const VerifyPage1({super.key});

  @override
  State<VerifyPage1> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage1> {
  // 手机号输入控制器
  final TextEditingController _phoneController = TextEditingController();
  // 验证码输入控制器
  final TextEditingController _codeController = TextEditingController();
  // 姓名输入控制器
  final TextEditingController _nameController = TextEditingController();
  // AI昵称输入控制器
  final TextEditingController _aiNicknameController = TextEditingController();
  // 是否正在倒计时
  bool _isCounting = false;
  // 倒计时秒数
  int _countdownSeconds = 60;
  // 倒计时显示文本
  String _countdownText = '获取验证码';

  /// 开始倒计时
  void _startCountdown() {
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

  /// 验证手机号格式
  bool _isValidPhone(String phone) {
    // 简单手机号验证：1开头，11位数字
    return phone.length == 11 && RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }

  /// 验证表单数据
  bool _validateForm() {
    // 验证手机号
    if (!_isValidPhone(_phoneController.text)) {
      ToastUtil.showError('请输入正确的手机号');
      return false;
    }

    // 验证验证码
    if (_codeController.text.isEmpty || _codeController.text.length != 6) {
      ToastUtil.showError('请输入6位验证码');
      return false;
    }

    // 验证姓名
    if (_nameController.text.isEmpty) {
      ToastUtil.showError('请输入姓名');
      return false;
    }

    // 验证AI昵称
    if (_aiNicknameController.text.isEmpty) {
      ToastUtil.showError('请输入AI昵称');
      return false;
    }

    return true;
  }

  /// 注册按钮点击事件
  void _handleRegister() {
    // 表单验证
    if (!_validateForm()) return;

    // 收集表单数据
    final registerData = {
      'phone': _phoneController.text,
      'code': _codeController.text,
      'name': _nameController.text,
      'aiNickname': _aiNicknameController.text,
    };

    // TODO: 实现注册API调用
    // await http.post('/register', data: registerData);
    // 注册成功后跳转到首页
    // Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    // 计算rpx (以750设计稿为基准)
    final double rpx = MediaQuery.of(context).size.width / 750;
    // 获取屏幕宽度，用于响应式调整
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // 页面主体内容
      body: Container(
        // 背景图片
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/login/3.png'),
            fit: BoxFit.cover,
          ),
        ),
        // 安全区域，确保内容不会被系统UI遮挡
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
                          // 添加蓝色边框
                          border: Border.all(color: Colors.blue, width: 4),
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
                        decoration: InputDecoration(
                          hintText: '请输入手机号',
                          hintStyle: TextStyle(
                            fontSize: 28 * rpx,
                            color: Colors.grey[400],
                          ),
                          // 修改prefix为带边距的Text组件
                          prefix: Padding(
                            padding: EdgeInsets.only(
                              left: 20 * rpx,
                              right: 5 * rpx,
                            ),
                            child: Text(
                              '手机号:',
                              style: TextStyle(
                                fontSize: 28 * rpx,
                                color: Colors.black87,
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
                      SizedBox(height: 20 * rpx),

                      // 验证码输入框（包含获取按钮）
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          hintText: '请输入验证码',
                          hintStyle: TextStyle(
                            fontSize: 28 * rpx,
                            color: Colors.grey[400],
                          ),
                          // 前缀文本
                          prefix: Padding(
                            padding: EdgeInsets.only(
                              left: 20 * rpx,
                              right: 5 * rpx,
                            ),
                            child: Text(
                              '验证码:',
                              style: TextStyle(
                                fontSize: 28 * rpx,
                                color: Colors.black87,
                              ),
                            ),
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
                                      // TODO: 实现发送验证码API调用
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
                      SizedBox(height: 20 * rpx),

                      // 姓名输入框
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: '请输入姓名',
                          hintStyle: TextStyle(
                            fontSize: 28 * rpx,
                            color: Colors.grey[400],
                          ),
                          // 修改prefix为带边距的Text组件
                          prefix: Padding(
                            padding: EdgeInsets.only(
                              left: 20 * rpx,
                              right: 5 * rpx,
                            ),
                            child: Text(
                              '姓名:    ',
                              style: TextStyle(
                                fontSize: 28 * rpx,
                                color: Colors.black87,
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
                      SizedBox(height: 20 * rpx),

                      // AI昵称输入框
                      TextField(
                        controller: _aiNicknameController,
                        decoration: InputDecoration(
                          hintText: '请输入AI昵称',
                          hintStyle: TextStyle(
                            fontSize: 28 * rpx,
                            color: Colors.grey[400],
                          ),
                          // 修改prefix为带边距的Text组件
                          prefix: Padding(
                            padding: EdgeInsets.only(
                              left: 20 * rpx,
                              right: 5 * rpx,
                            ),
                            child: Text(
                              'AI昵称:',
                              style: TextStyle(
                                fontSize: 28 * rpx,
                                color: Colors.black87,
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

                      // 注册按钮
                      SizedBox(
                        width: double.infinity,
                        height: 96 * rpx,
                        child: ElevatedButton(
                          onPressed: _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50 * rpx),
                            ),
                          ),
                          child: Text(
                            '注册',
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
