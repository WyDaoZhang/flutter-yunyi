import 'dart:convert';
import 'dart:io';

import 'package:demo1/pages/home/index.dart';
import 'package:demo1/pages/login/login.dart';
import 'package:demo1/pages/setting/email.dart';
import 'package:demo1/pages/setting/password.dart';
import 'package:demo1/utils/evntbus.dart';
import 'package:demo1/utils/http.dart';
import 'package:demo1/utils/storage.dart';
import 'package:demo1/utils/toast.dart';
import 'package:demo1/utils/token.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:image_picker_web/image_picker_web.dart'; // 如需专门适配Web可添加此依赖

// 用户个人资料页
class ProfilePageCustom extends StatefulWidget {
  const ProfilePageCustom({Key? key}) : super(key: key);

  @override
  State<ProfilePageCustom> createState() => _ProfilePageCustomState();
}

class _ProfilePageCustomState extends State<ProfilePageCustom> {
  // 头像图片路径，默认本地图片
  String avatarPath = 'assets/chat/tx.png';
  // 头像的base64编码
  String? avatarBase64;
  bool _isUploading = false;

  // 跳转到设置密码页面
  void _goToSetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PasswordResetPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    _getuserinfo();
  }

  // 用户信息
  void _getuserinfo() async {
    final info = await http.get('/getUserInfo');
    setState(() {
      avatarPath = info['data']['user']['avatar'];
    });
  }

  // 将图片转换为base64编码（跨平台兼容版本）
  Future<String?> _imageToBase64(XFile imageFile) async {
    try {
      // 直接通过XFile读取字节，避免使用File类
      List<int> imageBytes = await imageFile.readAsBytes();

      // 转换为base64
      String base64String = base64Encode(imageBytes);

      // 获取图片格式
      String mimeType = imageFile.mimeType ?? 'image/jpeg';

      // 返回完整的data URI格式
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      print('图片转换base64失败: $e');
      ToastUtil.showInfo('图片处理失败: ${e.toString()}');
      return null;
    }
  }

  // 修改方法
  void _updateUserInfo() async {
    if (avatarBase64 == null) {
      ToastUtil.showInfo('请选择图片');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final editemy = await http.put(
        '/editMyInfo',
        data: {'avatar': avatarBase64},
      );

      if (editemy['code'] == 200) {
        ToastUtil.showInfo('保存成功');
        // 发送头像更新事件
        eventBus.fire(AvatarUpdatedEvent(avatarBase64!));
      } else {
        ToastUtil.showInfo('保存失败: ${editemy['message'] ?? '未知错误'}');
      }
    } catch (e) {
      print('更新用户信息失败: $e');
      ToastUtil.showInfo('更新失败，请重试');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _goToPcCode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PasswordSettingPages()),
    );
  }

  void _goToPcCodes() async {
    await TokenManager().removeToken();

    // 显示提示信息
    ToastUtil.showInfo('Token已过期，请重新登录');

    // 触发登出事件，这会让应用跳转到登录页面
    eventBus.fire(LogoutEvent());
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
            onPressed: () async {
              TokenManager().removeToken();
              WebSocketManager().disconnect();
              await StorageUtil.clearHistoryMessages();
              Navigator.pop(context); // 关闭对话框
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MyApp()),
                (route) => false,
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // ... existing code ...
  // 获取头像图片提供者
  ImageProvider _getAvatarImageProvider(String path) {
    try {
      if (path.isEmpty) {
        return AssetImage('assets/chat/tx.png');
      } else if (path.startsWith('assets/')) {
        return AssetImage(path);
      } else if (path.startsWith('data:image')) {
        // 处理base64格式的头像
        final base64Data = path.split(',')[1];
        return MemoryImage(base64Decode(base64Data));
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        // 网络图片
        return NetworkImage(path);
      } else if (kIsWeb) {
        return NetworkImage(path);
      } else {
        // 本地文件
        final file = File(path);
        if (file.existsSync()) {
          return FileImage(file);
        } else {
          return AssetImage('assets/chat/tx.png');
        }
      }
    } catch (e) {
      print('头像处理异常: $e');
      return AssetImage('assets/chat/tx.png');
    }
  }

  // ... existing code ...
  // 选择头像图片（跨平台兼容版本）
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        avatarPath = picked.path;
        _isUploading = true;
      });

      // 直接使用XFile进行转换，不依赖File
      String? base64Data = await _imageToBase64(picked);

      setState(() {
        avatarBase64 = base64Data;
        _isUploading = false;
      });

      // 如果转换成功则上传
      if (base64Data != null) {
        _updateUserInfo();
      }
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
                        backgroundImage: _getAvatarImageProvider(avatarPath),
                        backgroundColor: Colors.grey[200],
                        onBackgroundImageError: (exception, stackTrace) {
                          print('头像加载错误: $exception');
                          setState(() {
                            avatarPath = 'assets/chat/tx.png'; // 加载失败时使用默认头像
                          });
                        },
                      ),
                      // 相机按钮（点击可更换头像）
                      Positioned(
                        bottom: 6,
                        right: 0,
                        child: InkWell(
                          onTap: _isUploading ? null : _pickAvatar,
                          child: Image(
                            height: 30,
                            image: AssetImage('assets/chat/9.png'),
                          ),
                        ),
                      ),
                      // 上传中指示器
                      if (_isUploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
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
                        _buildMenuRow(
                          '用户信息',
                          trailing: '详细',
                          onTap: _goToPcCode,
                        ),
                        // 退出登录菜单项
                        _buildMenuRow('退出登录', isLast: true, onTap: _logout),
                        _buildMenuRow(
                          '清除token',
                          isLast: true,
                          onTap: _goToPcCodes,
                        ),
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
