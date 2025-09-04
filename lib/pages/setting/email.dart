import 'package:demo1/utils/http.dart';
import 'package:demo1/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 倒计时相关变量
  int _countdownTime = 0;
  late Timer _countdownTimer;
  String avatarPath = '';
  String ckID = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    // 页面销毁时取消倒计时
    if (_countdownTimer != null && _countdownTimer.isActive) {
      _countdownTimer.cancel();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // _getuserinfo();
  }

  // void _getuserinfo() async {
  //   final info = await http.get('/getUserInfo');
  //   setState(() {
  //     avatarPath = info['data']['user']['avatar'];
  //   });
  // }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // 这里添加密码重置的业务逻辑（如接口调用）
      final phone = await http.put(
        'resetPwd',
        data: {
          'ck': _codeController.text,
          'ckID': ckID,
          'confirmPwd': '',
          'mobile': _phoneController.text,
          'oldPassword': '',
          'pk': _passwordController.text,
        },
      );
      if (phone['code'] == 200) {
        ToastUtil.showSuccess('密码重置成功');
        Navigator.pop(context); // 重置成功后返回上一页
      }
    }
  }

  // 开始倒计时
  void _startCountdown() {
    setState(() {
      _countdownTime = 60; // 60秒倒计时
    });

    // 取消之前的计时器（如果存在）
    if (_countdownTimer != null && _countdownTimer.isActive) {
      _countdownTimer.cancel();
    }

    // 创建新的计时器
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdownTime > 0) {
          _countdownTime--;
        } else {
          timer.cancel(); // 倒计时结束，取消计时器
        }
      });
    });
  }

  // 获取验证码按钮点击事件
  void _getVerificationCode() async {
    // 简单校验手机号
    if (_phoneController.text.isEmpty ||
        !RegExp(r'^1\d{10}$').hasMatch(_phoneController.text)) {
      ToastUtil.showError('请输入有效的手机号');
      return;
    }
    final resa = await http.get(
      'auth/getMobileCode?mobile=${_phoneController.text}',
    );
    ckID = resa['data'];
    // ckID = resa['data'];
    debugPrint('登录结果: ' + resa['data'].toString());

    // 开始倒计时
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用Stack包裹整个页面内容，让按钮可以浮在容器外部
      body: Stack(
        children: [
          // 主内容容器（原页面内容）
          Container(
            color: Colors.white, // 白色背景
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  const Text(
                    '重置密码',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '请输入手机号、验证码设置新密码',
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 30),

                  // 手机号输入框
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: '手机号',
                      hintStyle: TextStyle(color: Colors.blueGrey),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入手机号';
                      }
                      if (!RegExp(r'^1\d{10}$').hasMatch(value)) {
                        return '请输入有效的手机号';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  // 验证码行（输入框 + 获取按钮）
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          style: const TextStyle(color: Colors.black),
                          decoration: const InputDecoration(
                            hintText: '验证码',
                            hintStyle: TextStyle(color: Colors.blueGrey),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入验证码';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _countdownTime > 0
                            ? null
                            : _getVerificationCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _countdownTime > 0
                              ? const Color(0xFFE0E0E0) // 倒计时时灰色背景
                              : const Color(0xFFE3F2FD), // 正常状态浅蓝背景
                          foregroundColor: _countdownTime > 0
                              ? Colors.grey[600] // 倒计时时灰色文字
                              : Colors.blue, // 正常状态蓝色文字
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _countdownTime > 0
                              ? '${_countdownTime}s后重新获取'
                              : '获取验证码',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 新密码输入框
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: '新密码',
                      hintStyle: TextStyle(color: Colors.blueGrey),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                    inputFormatters: [LengthLimitingTextInputFormatter(16)],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入新密码';
                      }
                      if (value.length < 8 || value.length > 16) {
                        return '密码长度必须为8-16位';
                      }
                      // if (!RegExp(
                      //   r'^(?=.*[A-Za-z])(?=.*\d).+$',
                      // ).hasMatch(value)) {
                      //   return '密码必须包含字母和数字';
                      // }
                      return null;
                    },
                  ),
                  const SizedBox(height: 60),

                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3), // 蓝色背景
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 容器外部的左上角返回按钮（通过Stack定位在整个页面的左上角）
          Positioned(
            left: 20, // 距离屏幕左侧的距离
            top: MediaQuery.of(context).padding.top + 20, // 距离顶部（考虑状态栏高度）
            child: IconButton(
              onPressed: () => Navigator.pop(context), // 返回上一页
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}
