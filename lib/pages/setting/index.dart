import 'dart:io';

import 'package:demo1/pages/login/login.dart';
import 'package:demo1/pages/setting/email.dart';
import 'package:demo1/pages/setting/password.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// 用户个人资料页
class ProfilePageCustom extends StatefulWidget {
  const ProfilePageCustom({Key? key}) : super(key: key);

  @override
  State<ProfilePageCustom> createState() => _ProfilePageCustomState();
}

class _ProfilePageCustomState extends State<ProfilePageCustom> {
  // 头像图片路径，默认本地图片
  String avatarPath = 'assets/login/6.png';

  // 跳转到设置密码页面
  void _goToSetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PasswordSettingPage()),
    );
  }

  // 跳转到PC端登录码页面（暂未实现）
  void _goToPcCode() {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => const PcCodePage()),
    // );
  }

  // 跳转到邮箱认证页面
  void _goToEmailVerify() {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => const EmailVerifyPage()),
    // );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmailConfigPage()),
    );
  }

  // 退出登录
  void _logout() {
    // 弹出确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出登录?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 取消
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭对话框
              // 执行退出逻辑，比如清除token等
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const MyApp()),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 选择头像图片（从相册）
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        avatarPath = picked.path;
      });
      // 这里可以上传头像到服务器
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景图片
          Positioned.fill(
            child: Image.asset('assets/chat/bg1.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                // 左上角返回按钮
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 6),
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
                const SizedBox(height: 25),
                // 头像和相机icon层叠
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      // 用户头像
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: avatarPath.startsWith('assets/')
                            ? AssetImage(avatarPath)
                            : FileImage(
                                    // ignore: prefer_const_constructors
                                    File(avatarPath),
                                  )
                                  as ImageProvider,
                        backgroundColor: Colors.white,
                      ),
                      // 相机按钮（点击可更换头像）
                      Positioned(
                        bottom: 6,
                        right: 0,
                        child: InkWell(
                          onTap: _pickAvatar,
                          child: Image(
                            height: 30,
                            image: AssetImage('assets/chat/9.png'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
                // 菜单卡片，无阴影
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.93),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        // 设置密码菜单项
                        _buildMenuRow(
                          '设置密码',
                          trailing: '去设置',
                          onTap: _goToSetPassword,
                        ),
                        // 生成PC端登录码菜单项
                        _buildMenuRow('生成pc端登陆码', onTap: _goToPcCode),
                        // 邮箱认证菜单项
                        _buildMenuRow(
                          '邮箱认证',
                          trailing: '去认证',
                          onTap: _goToEmailVerify,
                        ),
                        // 退出登录菜单项
                        _buildMenuRow('退出登录', isLast: true, onTap: _logout),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建菜单行
  Widget _buildMenuRow(
    String text, {
    String? trailing,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              // 菜单标题
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
              // 右侧提示文字和箭头
              if (trailing != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailing,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 以下是示例页面，你可以替换为你的实际页面
// class SetPasswordPage extends StatelessWidget { ... }
// class PcCodePage extends StatelessWidget { ... }
// class EmailVerifyPage extends StatelessWidget { ... }
// class LoginPage extends StatelessWidget { ... }
