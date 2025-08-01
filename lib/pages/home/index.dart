import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:demo1/utils/http.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../utils/token.dart';
import '../history/index.dart';
import '../setting/index.dart';

// 聊天页面的主入口
class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

// WebSocket管理类
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> connect() async {
    if (_isConnected) {
      await disconnect();
    }

    try {
      final token = TokenManager().getToken() ?? '';
      _channel = WebSocketChannel.connect(
        Uri.parse(
          // 'ws://192.168.1.117:12111/api/v1/chat/api_server/api/ws?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVaWQiOiIxNTZkZjE3OS00YzExLTRmOWYtYWQ3Zi02MDBmMDEzMjFhYWYiLCJVc2VySWQiOiIxMDAwMDAwMDAwNCJ9.7hQZApInstclXwNDVG4CBnvookWNvHygM4Ymfb-Lmmg',
          'ws://192.168.1.117:12111/api/v1/chat/api_server/api/ws?token=$token',
        ),
      );

      _isConnected = true;
      print('WebSocket连接成功');

      _channel?.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> message = json.decode(data.toString());
            _messageController.add(message);
          } catch (e) {
            print('消息解析失败: $e, 原始数据: $data');
          }
        },
        onError: (error) {
          print('WebSocket错误: $error');
          _isConnected = false;
          _messageController.addError(error);
        },
        onDone: () {
          print('WebSocket连接关闭');
          _isConnected = false;
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('WebSocket连接失败: $e');
      _isConnected = false;
      rethrow;
    }
  }

  bool sendMessage(
    String content, {
    List<Map<String, dynamic>> history = const [],
  }) {
    if (!_isConnected || _channel == null) {
      print('WebSocket未连接，无法发送消息');
      return false;
    }

    try {
      final message = json.encode({
        "action": "chat",
        "data": {"query": content, "history": history},
      });
      _channel?.sink.add(message);
      print('消息发送成功: $content');
      return true;
    } catch (e) {
      print('消息发送失败: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_isConnected && _channel != null) {
      await _channel?.sink.close();
      _channel = null;
      _isConnected = false;
      print('WebSocket已手动断开');
    }
  }

  bool get isConnected => _isConnected;
}

// 聊天页面状态类
class _ChatPageState extends State<ChatPage> {
  final WebSocketManager _wsManager = WebSocketManager();

  File? _selectedImage;

  // 状态变量
  bool isRecording = false;
  bool _isReleasing = false;
  Timer? _recordTimer;

  // 用户信息
  Map userInfo = {"id": "", "avatar": null, "nickName": null};
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  // 聊天消息列表
  final List<ChatMessage> messages = [];
  // 临时消息索引（AI流式回复用）
  int? _tempAIMessageIndex;

  // 控制器
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 功能状态
  bool showFunctions = false;
  bool isVoiceMode = false;

  // 消息监听订阅
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initWebSocket();
  }

  void _initWebSocket() async {
    try {
      await _wsManager.connect();
      _messageSubscription = _wsManager.messageStream.listen(
        (message) => _handleServerMessage(message),
        onError: (error) => _showError('接收消息错误: $error'),
      );
    } catch (e) {
      _showError('WebSocket初始化失败: $e');
    }
  }

  // 处理服务器消息（优化后的流式处理）
  void _handleServerMessage(Map<String, dynamic> message) {
    print('收到服务器消息: $message');

    if (message['action'] == 'response') {
      final String segment = message['content'] ?? '';
      if (segment.isEmpty) return;

      if (_tempAIMessageIndex != null &&
          _tempAIMessageIndex! < messages.length) {
        // 向现有AI消息追加文本
        messages[_tempAIMessageIndex!].appendText(segment);
        setState(() {}); // 只刷新，不重建整个对象
      } else {
        // 创建新AI消息
        final newMessage = ChatMessage(text: segment, isMe: false);
        setState(() {
          messages.add(newMessage);
          _tempAIMessageIndex = messages.length - 1;
        });
      }

      _scrollToBottom();
    } else if (message['action'] == 'history_data') {
      // 处理历史消息
      final List<dynamic>? history = message['history'];
      if (history != null) {
        _loadHistoryFromServer(history);
      }
    } else {
      print('未处理的消息类型: ${message['action']}');
    }
  }

  // 从服务器加载历史消息
  void _loadHistoryFromServer(List<dynamic> historyList) {
    setState(() {
      messages.clear();

      for (var item in historyList) {
        if (item is List && item.length >= 2) {
          // 用户消息
          if (item[0] != null && item[0].toString().isNotEmpty) {
            messages.add(ChatMessage(text: item[0].toString(), isMe: true));
          }
          // AI消息
          if (item[1] != null && item[1].toString().isNotEmpty) {
            messages.add(ChatMessage(text: item[1].toString(), isMe: false));
          }
        }
      }
      _scrollToBottom();
    });
  }

  // 添加消息到列表
  void _addMessage(String text, {required bool isMe}) {
    setState(() {
      messages.add(ChatMessage(text: text, isMe: isMe));
    });
    _scrollToBottom();
  }

  // 发送消息
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    _tempAIMessageIndex = null; // 清除AI临时消息索引
    _addMessage(text, isMe: true); // 添加用户消息
    _controller.clear();

    // 生成历史记录时使用完整文本
    final bool success = _wsManager.sendMessage(
      text,
      history: messages
          .map(
            (m) => {
              "role": m.isMe ? "user" : "assistant",
              "content": m.fullText,
            },
          )
          .toList(),
    );
    if (!success) {
      _showError('发送失败，请检查网络连接');
    }
  }

  // 滚动到底部
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // 显示提示消息
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 录音权限检查
  Future<void> _checkPermissions() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showError('需要麦克风权限才能使用语音功能');
        return;
      }
    }
  }

  void _startRecording() {
    _checkPermissions();
    setState(() {
      isRecording = true;
      _isReleasing = false;
    });
  }

  void _stopRecording() {
    setState(() => _isReleasing = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        isRecording = false;
        _isReleasing = false;
      });
      _recordTimer?.cancel();
    });
  }

  // 发送图片消息
  void _sendImageMessage(String imagePath) async {
    String fileName = path.basename(imagePath);
    final res = await http.post(
      'file/uploadUrl',
      data: {
        "files": [
          {"contentType": "image/png", "fileName": fileName},
        ],
      },
    );

    debugPrint('上传结果$res');

    if (res['code'] == 200) {
      if (res['data'] is List && res['data'].isNotEmpty) {
        String imageUrl = res['data'][0]['url'] ?? '';
        if (imageUrl.isNotEmpty) {
          debugPrint('上传结果$imageUrl');
          try {
            // 读取图片文件
            File imageFile = File(imagePath);
            List<int> imageBytes = await imageFile.readAsBytes();

            // 创建Dio实例并配置
            Dio dio = Dio();
            Response response = await dio.put(
              imageUrl,
              // data: imageBytes,
              // options: Options(
              //   contentType: 'image/png', // 设置正确的内容类型
              //   headers: {
              //     'Content-Length': imageBytes.length.toString(), // 设置内容长度
              //   },
              // ),
            );

            // 检查上传结果
            if (response.statusCode == 200) {
              debugPrint('图片上传成功');
              _showToast('图片上传成功');
            } else {
              debugPrint('图片上传失败，状态码: ${response.statusCode}');
              _showError('图片上传失败，请重试');
            }
          } catch (e) {
            debugPrint('图片上传异常: $e');
            _showError('图片上传失败: $e');
          }
        }
      }
    }

    setState(() {
      messages.add(ChatMessage(isMe: true, imageUrl: imagePath));
    });
    _scrollToBottom();
  }

  // 拍照功能处理
  void _handleCameraTap() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        _showError('需要相机权限才能使用拍照功能');
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        _sendImageMessage(pickedFile.path);
      } else {
        _showToast('未选择图片');
      }
    } catch (e) {
      _showError('拍照失败: $e');
      print('拍照异常: $e');
    }
  }

  // 相册功能处理
  void _handleGalleryTap() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        _sendImageMessage(pickedFile.path);
      } else {
        _showToast('未选择图片');
      }
    } catch (e) {
      _showError('选择图片失败: $e');
      print('相册选择异常: $e');
    }
  }

  // 文件功能处理
  void _handleFileTap() {}

  // 录音功能处理
  void _handleAudioTap() async {
    setState(() => showFunctions = false);
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showError('需要麦克风权限才能使用录音功能');
        return;
      }
    }
    _showToast('录音功能待实现');
  }

  // 录音覆盖层
  Widget _buildRecordingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            _buildVoiceAnimation(),
            const SizedBox(height: 30),
            Text(
              _isReleasing ? '松开 取消' : '说话中...',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 100),
            Text(
              _isReleasing ? '取消发送' : '松开 发送',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAnimation() {
    return Container(
      width: _isReleasing ? 80 : 120,
      height: _isReleasing ? 40 : 80,
      child: Image.asset(
        'assets/chat/record.gif',
        color: _isReleasing ? Colors.red : null,
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/chat/bg1.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Column(
              children: [
                _buildAppBar(),
                // 消息列表（从底部开始排列）
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return ChatBubble(message: messages[index]);
                      },
                    ),
                  ),
                ),
                _buildInputBar(),
                if (showFunctions) _buildBottomBar(),
                // 底部说明文字
                Container(
                  height: 60,
                  color: Colors.white,
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        '以上内容由祝余AI生成',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isRecording) _buildRecordingOverlay(),
          ],
        ),
      ),
    );
  }

  // 顶部导航栏
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 5, right: 10, left: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfilePageCustom(),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50.0),

              child: userInfo['avatar'] != null
                  ? Image.network(userInfo['avatar'])
                  : Image.asset('assets/login/6.png'),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
            child: const Image(
              image: AssetImage('assets/chat/history.png'),
              width: 30,
            ),
          ),
        ],
      ),
    );
  }

  // 输入栏
  Widget _buildInputBar() {
    // 添加焦点节点以检测输入框焦点状态
    final FocusNode _focusNode = FocusNode();
    const double horizontalPadding = 16;
    const double verticalPadding = 14;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 语音/文字切换按钮
          GestureDetector(
            onTap: () => setState(() => isVoiceMode = !isVoiceMode),
            child: Container(
              // 向上移动 5 个像素
              margin: const EdgeInsets.only(bottom: 13.55),
              child: Image(
                image: AssetImage(
                  isVoiceMode ? 'assets/chat/8.png' : 'assets/chat/7.png',
                ),
                width: 30,
                height: 30,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 主输入容器，统一样式
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!),
              ),
              // 设置最小高度，确保两种模式下有基础一致的高度
              constraints: const BoxConstraints(minHeight: 60),
              child: Stack(
                children: [
                  // 文本输入模式
                  Offstage(
                    offstage: isVoiceMode,
                    child: TextField(
                      focusNode: _focusNode,
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                      ),
                      style: const TextStyle(fontSize: 17),
                      minLines: 1,
                      maxLines: 3, // 最多显示3行
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      // 监听焦点变化，用于控制发送按钮显示
                      onChanged: (text) => setState(() {}),
                    ),
                  ),
                  // 语音输入模式，确保与文本输入框底部对齐
                  Offstage(
                    offstage: !isVoiceMode,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        // 与文本输入框相同的内边距
                        padding: const EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        // 确保高度与单行文本输入框一致
                        height: 50,
                        child: GestureDetector(
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopRecording(),
                          onLongPressCancel: () => _stopRecording(),
                          child: const Text(
                            '按住说话',
                            style: TextStyle(color: Colors.grey, fontSize: 17),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 功能按钮（如表情、更多等）
          GestureDetector(
            onTap: () => setState(() => showFunctions = !showFunctions),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: Image(
                width: 30,
                height: 30,
                image: AssetImage(
                  showFunctions ? 'assets/chat/14.png' : 'assets/chat/5.png',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 底部功能栏
  Widget _buildBottomBar() {
    return Container(
      height: 95,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomIcon(
            icon: 'assets/chat/13.png',
            label: '拍照',
            onTap: _handleCameraTap,
          ),
          _BottomIcon(
            icon: 'assets/chat/12.png',
            label: '相册',
            onTap: _handleGalleryTap,
          ),
          _BottomIcon(
            icon: 'assets/chat/10.png',
            label: '文件',
            onTap: _handleFileTap,
          ),
          _BottomIcon(
            icon: 'assets/chat/11.png',
            label: '录音',
            onTap: _handleAudioTap,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _wsManager.disconnect();
    _controller.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }
}

// 聊天消息模型（优化后）
class ChatMessage {
  String text; // 直接存储完整文本
  final bool isMe;
  final double? progress;
  final String? imageUrl;

  // 构造方法
  ChatMessage({
    this.text = '',
    required this.isMe,
    this.progress,
    this.imageUrl,
  });

  // 添加文本（AI流式回复用）
  void appendText(String text) {
    this.text += text;
  }

  // 获取完整文本
  String get fullText => text;
}

// 聊天气泡组件（优化后，解决抖动问题）
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        // 保持消息在正确的一侧
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end, // 关键：底部对齐，避免抖动
        children: [_bubbleContent(context)],
      ),
    );
  }

  Widget _bubbleContent(BuildContext context) {
    final isMe = message.isMe;
    final bubbleColor = isMe ? const Color(0xFF3A70E2) : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    const double maxWidth = 270;

    // 图片消息处理
    if (message.imageUrl != null) {
      return Container(
        width: maxWidth,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: _getBorderRadius(isMe),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(message.imageUrl!),
            fit: BoxFit.cover,
            height: 200,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.error, color: Colors.red),
          ),
        ),
      );
    }

    // 文本消息处理
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // 关键：最小化尺寸，避免布局跳动
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: _getBorderRadius(isMe),
            boxShadow: !isMe
                ? [
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      spreadRadius: 0.5,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: isMe
              ? _buildUserMessage(textColor)
              : _buildAIMessage(textColor),
        ),
        // 进度条和操作按钮
        if (message.progress != null) _buildProgressIndicator(),
        if (!message.isMe) _buildAIActions(),
        if (message.isMe) _buildUserActions(),
      ],
    );
  }

  // 构建用户消息
  Widget _buildUserMessage(Color textColor) {
    return Text(
      message.fullText,
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      softWrap: true,
    );
  }

  // 构建AI消息（优化的流式显示）
  Widget _buildAIMessage(Color textColor) {
    // 使用SingleChildScrollView确保内容超出时可滚动但不抖动
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(), // 禁用内部滚动
      child: Column(
        mainAxisSize: MainAxisSize.min, // 关键：内容高度自适应
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 合并所有文本一次性渲染，避免布局抖动
          MarkdownBody(
            data: message.fullText,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5, // 增加行高使内容更稳定
              ),
              h1: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              h2: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              h3: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              code: TextStyle(
                backgroundColor: Colors.grey[100],
                color: Colors.red,
                fontSize: 14,
              ),
              codeblockPadding: const EdgeInsets.all(8),
              codeblockDecoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onTapLink: (text, href, title) {
              if (href != null) {
                _launchUrl(Uri.parse(href));
              }
            },
          ),
        ],
      ),
    );
  }

  // 提取通用的边框半径设置
  BorderRadius _getBorderRadius(bool isMe) {
    return BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );
  }

  // 进度指示器
  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: message.progress,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3A70E2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${(message.progress! * 100).toInt()}%",
            style: const TextStyle(color: Colors.black87, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // AI消息操作按钮
  Widget _buildAIActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _iconButton('assets/chat/stop.png'),
          const SizedBox(width: 15),
          _iconButton('assets/chat/copy.png'),
          const SizedBox(width: 15),
          _iconButton('assets/chat/update.png'),
          const SizedBox(width: 15),
          _iconButton('assets/chat/share.png'),
        ],
      ),
    );
  }

  // 用户消息操作按钮
  Widget _buildUserActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _iconButton('assets/chat/copy.png'),
          const SizedBox(width: 15),
          _iconButton('assets/chat/share.png'),
        ],
      ),
    );
  }

  // 链接打开
  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  // 操作图标按钮
  static Widget _iconButton(String icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1)],
      ),
      child: Image(image: AssetImage(icon), width: 17),
      padding: const EdgeInsets.all(6),
    );
  }
}

// 底部功能图标组件
class _BottomIcon extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _BottomIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Image(image: AssetImage(icon)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
