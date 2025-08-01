import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo1/utils/toast.dart';

/// 配置邮箱页面
/// 用于设置邮箱账号、密码及服务器信息
class EmailConfigPage extends StatefulWidget {
  const EmailConfigPage({super.key});

  @override
  State<EmailConfigPage> createState() => _EmailConfigPageState();
}

class _EmailConfigPageState extends State<EmailConfigPage> {
  // 表单全局键，用于表单验证
  final _formKey = GlobalKey<FormState>();

  // 文本编辑控制器，用于获取输入框内容
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void dispose() {
    // 释放控制器资源，避免内存泄漏
    _emailController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    _portController.dispose();
    super.dispose();
  }

  /// 提交表单处理函数
  void _submitForm() {
    // 验证表单
    if (_formKey.currentState!.validate()) {
      // 表单验证通过，执行保存逻辑
      _saveEmailConfig();
    }
  }

  /// 保存邮箱配置信息
  void _saveEmailConfig() {
    // 获取表单输入值
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final server = _serverController.text.trim();
    final port = _portController.text.trim();

    // 这里可以添加保存逻辑，如存储到本地或发送到服务器
    // 示例：仅显示成功提示
    ToastUtil.showSuccess('邮箱配置成功');
    // 返回上一页
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 页面主体内容
      body: Container(
        // 设置背景图片
        decoration: BoxDecoration(
          // 使用项目中已有的登录背景图片
          image: DecorationImage(
            image: AssetImage('assets/login/3.png'), // 背景图片路径
            fit: BoxFit.cover, // 图片填充方式：覆盖整个容器
          ),
        ),
        // 使用Stack实现层叠布局，放置返回按钮和表单内容
        child: Stack(
          children: [
            // 返回按钮
            Positioned(
              top: 40, // 距离顶部40px
              left: 20, // 距离左侧20px
              child: GestureDetector(
                // // 点击返回上一页
                // onTap: () => Navigator.pop(context),
                // 使用项目中的返回图标
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black54,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),

            // 表单内容区域
            Padding(
              // 内边距：水平30px，垂直80px
              padding: const EdgeInsets.symmetric(
                horizontal: 30.0,
                vertical: 80.0,
              ),
              child: Form(
                key: _formKey, // 关联表单键
                child: Column(
                  // 主轴对齐方式：顶部对齐
                  mainAxisAlignment: MainAxisAlignment.start,
                  // 交叉轴对齐方式：居中对齐
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 页面标题
                    const Text(
                      '配置邮箱',
                      style: TextStyle(
                        fontSize: 24, // 文字大小
                        fontWeight: FontWeight.bold, // 文字粗细
                        color: Colors.black, // 文字颜色
                      ),
                    ),

                    // 间距：30px
                    const SizedBox(height: 30),

                    // 邮箱地址输入框
                    _buildTextField(
                      controller: _emailController,
                      labelText: '邮箱地址',
                      hintText: '请输入邮箱地址',
                      keyboardType: TextInputType.emailAddress, // 邮箱输入键盘
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入邮箱地址';
                        }
                        // 简单邮箱格式验证
                        if (!RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        ).hasMatch(value)) {
                          return '请输入有效的邮箱地址';
                        }
                        return null;
                      },
                    ),

                    // 间距：16px
                    const SizedBox(height: 16),

                    // 密码输入框
                    _buildTextField(
                      controller: _passwordController,
                      labelText: '密码',
                      hintText: '请输入密码',
                      obscureText: true, // 密码隐藏显示
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                    ),

                    // 间距：16px
                    const SizedBox(height: 16),

                    // 服务器网址输入框
                    _buildTextField(
                      controller: _serverController,
                      labelText: '服务器网址',
                      hintText: '服务器网址',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入服务器网址';
                        }
                        return null;
                      },
                    ),

                    // 间距：16px
                    const SizedBox(height: 16),

                    // 服务器端口输入框
                    _buildTextField(
                      controller: _portController,
                      labelText: '服务器端口',
                      hintText: '服务器端口',
                      keyboardType: TextInputType.number, // 数字输入键盘
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // 只允许输入数字
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入服务器端口';
                        }
                        // 端口范围验证（1-65535）
                        final port = int.tryParse(value);
                        if (port == null || port < 1 || port > 65535) {
                          return '请输入有效的端口号（1-65535）';
                        }
                        return null;
                      },
                    ),

                    // 间距：40px
                    const SizedBox(height: 40),

                    // 设置按钮
                    SizedBox(
                      width: double.infinity, // 宽度占满父容器
                      child: ElevatedButton(
                        onPressed: _submitForm, // 点击触发提交表单
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3), // 按钮背景色：蓝色
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ), // 垂直内边距15px
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), // 圆角半径30px
                          ),
                        ),
                        child: const Text(
                          '设置',
                          style: TextStyle(
                            fontSize: 18, // 文字大小18px
                            color: Colors.white, // 文字颜色白色
                            fontWeight: FontWeight.w500, // 文字粗细
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
    );
  }

  /// 封装文本输入框组件，减少代码重复
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 输入框标签
        Text(
          labelText,
          style: const TextStyle(
            fontSize: 16, // 标签文字大小
            color: Colors.black, // 标签文字颜色
          ),
        ),

        // 间距：8px
        const SizedBox(height: 8),

        // 文本输入框
        TextFormField(
          controller: controller, // 控制器
          obscureText: obscureText, // 是否隐藏输入内容（密码）
          keyboardType: keyboardType, // 键盘类型
          inputFormatters: inputFormatters, // 输入格式化器
          validator: validator, // 验证函数
          style: const TextStyle(color: Colors.black), // 输入文字颜色
          decoration: InputDecoration(
            hintText: hintText, // 提示文字
            hintStyle: const TextStyle(color: Colors.grey), // 提示文字样式
            filled: true, // 是否填充背景
            fillColor: Colors.white.withOpacity(0.8), // 背景色：白色半透明
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), // 边框圆角
              borderSide: BorderSide.none, // 无边框
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ), // 内容内边距
          ),
        ),
      ],
    );
  }
}
