import 'package:demo1/utils/http.dart';
import 'package:demo1/utils/toast.dart';
import 'package:flutter/material.dart';

class PasswordSettingPages extends StatefulWidget {
  const PasswordSettingPages({super.key});

  @override
  State<PasswordSettingPages> createState() => _PasswordSettingPageState();
}

class _PasswordSettingPageState extends State<PasswordSettingPages> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(
    text: '13315037492',
  );
  bool _isMale = true;
  bool _isFormValid = false;

  //用户
  String userId = '';
  //昵称
  String mobile = '';
  //创建时间
  String createTime = '';

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_validateForm);
    _nicknameController.addListener(_validateForm);
    _getuserinfo();
  }

  //用户信息
  void _getuserinfo() async {
    final info = await http.get('/getUserInfo');
    setState(() {
      userId = info['data']['user']['uk'];
      // avatar = info['data']['user']['avatar'];
      mobile = info['data']['user']['nickName'];
      createTime = info['data']['user']['createTime'];
      _usernameController.text = userId;
      _nicknameController.text = mobile;
    });

    // print('用户信息: $info');
  }

  //修改方法
  void _updateUserInfo() async {
    final editemy = await http.put(
      '/editMyInfo',
      data: {
        // "endTime": "string",
        "mailbox": "",
        "mobile": "",
        "nickName": _nicknameController.text,
        // "pageNum": 0,
        // "pageSize": 0,
        // "params": {"additionalProp1": {}},
        // "registerType": "string",
        "sex": _isMale ? '男' : '女',
        // "spaceUrl": "string",
        // "startTime": "string",
        // "status": "string",
        "uk": _usernameController.text,
        // "userType": "string",
      },
    );
    if (editemy['code'] == 200) return ToastUtil.showInfo('保存成功');
    print('用户信息: $editemy');
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _nicknameController.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人设置'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 个人信息部分
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '个人信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),
                    _InfoRow(label: '用户名称:', value: userId),
                    _InfoRow(label: '用户昵称:', value: mobile),
                    _InfoRow(label: '用户邮箱:', value: ''),
                    _InfoRow(label: '所属角色:', value: ''),
                    _InfoRow(label: '创建日期:', value: createTime),
                  ],
                ),
              ),

              // 基本资料部分
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '基本资料',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('账号信息', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    _FormField(
                      label: '用户名',
                      controller: _usernameController,
                      hintText: '请输入用户昵称',
                      enabled: true,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: '用户昵称',
                      controller: _nicknameController,
                      hintText: '请输入用户昵称',
                      isRequired: true,
                    ),
                    const SizedBox(height: 20),
                    Text('性别', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _isMale,
                          onChanged: (value) {
                            setState(() {
                              _isMale = value!;
                            });
                          },
                        ),
                        const Text('男'),
                        const SizedBox(width: 30),
                        Radio<bool>(
                          value: false,
                          groupValue: _isMale,
                          onChanged: (value) {
                            setState(() {
                              _isMale = value!;
                            });
                          },
                        ),
                        const Text('女'),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _updateUserInfo,

                          // _isFormValid
                          //     ? () {
                          //         // 保存按钮逻辑
                          //         ScaffoldMessenger.of(context).showSnackBar(
                          //           const SnackBar(content: Text('保存成功')),
                          //         );
                          //       }
                          //     : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text('保存'),
                        ),
                        const SizedBox(width: 20),
                        OutlinedButton(
                          onPressed: () {
                            // 重置按钮逻辑
                            setState(() {
                              _nicknameController.clear();
                              _isMale = true;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            side: const BorderSide(color: Colors.grey),
                          ),
                          child: const Text('重置'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 信息行组件
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '未设置' : value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// 表单字段组件
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool enabled;
  final bool isRequired;

  const _FormField({
    required this.label,
    required this.controller,
    this.hintText,
    this.enabled = true,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
