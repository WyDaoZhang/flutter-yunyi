// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';
// import 'package:audio_session/audio_session.dart';
// // import 'package:audioplayers/audioplayers.dart';
// import 'package:clipboard/clipboard.dart';
// import 'package:demo1/utils/audio.dart';
// import 'package:demo1/utils/evntbus.dart';
// import 'package:demo1/utils/http.dart';
// import 'package:demo1/utils/httpd.dart';
// import 'package:demo1/utils/recorder.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter/foundation.dart';
// // import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_file_dialog/flutter_file_dialog.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:flutter_sound/public/flutter_sound_recorder.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path/path.dart' as path;
// // import 'package:path_provider/path_provider.dart';
// // import 'package:permission_handler/permission_handler.dart';
// // import 'package:record/record.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import '../../utils/token.dart';
// import '../history/index.dart';
// import '../setting/index.dart';
// import '../../utils/toast.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/material.dart';
// import 'package:record/record.dart';

// // 聊天页面的主入口
// class ChatPage extends StatefulWidget {
//   @override
//   State<ChatPage> createState() => _ChatPageState();
// }

// // 任务模型
// class Task {
//   final String name;
//   final String status;
//   final String? detail;

//   Task({required this.name, required this.status, this.detail});
// }

// // WebSocket管理类
// class WebSocketManager {
//   static final WebSocketManager _instance = WebSocketManager._internal();
//   factory WebSocketManager() => _instance;
//   WebSocketManager._internal();

//   WebSocketChannel? _channel;
//   bool _isConnected = false;
//   bool _isReconnecting = false;
//   final StreamController<Map<String, dynamic>> _messageController =
//       StreamController.broadcast();
//   Timer? _reconnectTimer;
//   Timer? _heartbeatTimer; // 心跳定时器
//   Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

//   Future<void> connect() async {
//     if (_isConnected) {
//       await disconnect();
//       return;
//     }
//     try {
//       await TokenManager().init();
//       final token = TokenManager().getToken() ?? '';
//       _channel = WebSocketChannel.connect(
//         Uri.parse(
//           'ws://api.lengjing-ai.com/api/v1/chat/api_server/api/ws?token=$token',
//         ),
//       );

//       _isConnected = true;
//       print('WebSocket连接成功');
//       // 若当前是重连状态，连接成功后重置状态
//       if (_isReconnecting) {
//         ToastUtil.showSuccess('WebSocket重连成功');
//         _isReconnecting = false;
//       }
//       _startHeartbeat();
//       _channel?.stream.listen(
//         (data) {
//           try {
//             final Map<String, dynamic> message = json.decode(data.toString());
//             _messageController.add(message);
//           } catch (e) {
//             print('消息解析失败: $e, 原始数据: $data');
//           }
//         },
//         onError: (error) {
//           print('WebSocket错误: $error');
//           _isConnected = false;
//           _stopHeartbeat();
//           _messageController.addError(error);
//           _scheduleReconnect();
//           // 若未在重连中且未连接，触发重连
//           if (!_isReconnecting && !_isConnected) {
//             _scheduleReconnect();
//           }
//         },
//         onDone: () {
//           print('WebSocket连接关闭');
//           _isConnected = false;
//           _stopHeartbeat(); // 连接关闭时停止心跳
//           // 若未在重连中且未连接，触发重连
//           if (!_isReconnecting && !_isConnected) {
//             _scheduleReconnect();
//           }
//         },
//         cancelOnError: true,
//       );
//     } catch (e) {
//       print('WebSocket连接失败: $e');
//       _isConnected = false;
//       _isReconnecting = false; // 连接失败时重置重连状态
//       _scheduleReconnect();
//       rethrow;
//     }
//   }

//   // 启动心跳定时器，每10秒发送一次心跳包
//   void _startHeartbeat() {
//     // 先停止可能存在的旧定时器
//     _stopHeartbeat();

//     // 启动新的心跳定时器，延迟0秒执行第一次，之后每10秒执行一次
//     _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
//       _sendHeartbeat();
//     });
//   }

//   // 发送心跳包
//   void _sendHeartbeat() {
//     if (!_isConnected || _channel == null) {
//       print('WebSocket未连接，无法发送心跳');
//       _stopHeartbeat();
//       return;
//     }

//     try {
//       final heartbeat = json.encode({"action": "heartbeat", "data": "PING"});
//       _channel?.sink.add(heartbeat);
//       print('发送心跳包成功');
//     } catch (e) {
//       print('发送心跳包失败: $e');
//       _stopHeartbeat();
//       // 心跳发送失败时触发重连
//       if (_isConnected) {
//         _scheduleReconnect();
//       }
//     }
//   }

//   // 停止心跳定时器
//   void _stopHeartbeat() {
//     if (_heartbeatTimer != null) {
//       _heartbeatTimer?.cancel();
//       _heartbeatTimer = null;
//     }
//   }

//   void _scheduleReconnect() {
//     // 若已有重连定时器、正在重连或已连接，则不重复调度
//     if (_reconnectTimer != null || _isReconnecting || _isConnected) return;

//     _isReconnecting = true; // 标记为正在重连
//     print('调度重连，5秒后尝试...');

//     _reconnectTimer = Timer(const Duration(seconds: 5), () async {
//       _reconnectTimer?.cancel(); // 清除定时器
//       _reconnectTimer = null;

//       try {
//         await connect(); // 执行重连
//       } catch (e) {
//         print('重连失败: $e');
//         _isReconnecting = false; // 重连失败，重置状态
//         _scheduleReconnect(); // 继续调度下一次重连
//       }
//     });
//   }

//   bool sendMessage(
//     String content, {
//     List<Map<String, dynamic>> history = const [],
//   }) {
//     if (!_isConnected || _channel == null) {
//       print('WebSocket未连接，无法发送消息');
//       return false;
//     }

//     try {
//       final message = json.encode({
//         "action": "chat",
//         "data": {"query": content, "history": history},
//       });
//       _channel?.sink.add(message);
//       print('消息发送成功: $content');
//       return true;
//     } catch (e) {
//       print('消息发送失败: $e');
//       return false;
//     }
//   }

//   Future<void> disconnect() async {
//     if (_isConnected && _channel != null) {
//       await _channel?.sink.close();
//       _channel = null;
//       _isConnected = false;
//       print('WebSocket已手动断开');
//     }
//     _stopHeartbeat(); // 断开连接时停止心跳
//     _reconnectTimer?.cancel();
//     _reconnectTimer = null;
//   }

//   bool get isReconnecting => _isReconnecting;
//   bool get isConnected => _isConnected;
// }

// // 聊天页面状态类 - 实现WidgetsBindingObserver以监听键盘状态
// class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
//   final WebSocketManager _wsManager = WebSocketManager();

//   File? _selectedImage;

//   bool _isLoading = false; // 新增：控制加载状态的变量
//   // 状态变量
//   bool isRecording = false;
//   bool _isReleasing = false;
//   Timer? _recordTimer;
//   int _recordingDuration = 0; // 录音时长（秒）
//   // 新增：跟踪当前正在处理的message_id
//   String? _currentProcessingMessageId;

//   // 新增: 键盘状态和输入内容状态变量
//   // bool _isKeyboardVisible = false; // 键盘是否可见
//   bool _hasInputContent = false; // 输入框是否有内容

//   // 用户信息
//   Map userInfo = {"id": "", "avatar": null, "nickName": null};
//   final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
//   // 聊天消息列表
//   final List<ChatMessage> messages = [];
//   // 临时消息索引（AI流式回复用）
//   int? _tempAIMessageIndex;

//   // 控制器
//   final TextEditingController _controller = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   // 功能状态
//   bool showFunctions = false;
//   bool isVoiceMode = false;

//   // 创建录音器实例
//   final _recorderas = AudioRecorder();
//   // 创建音频播放器实例
//   final _player = AudioPlayer();
//   // 存储录音文件路径
//   String? _filePath;
//   // 录音状态标志
//   bool _isRecording = false;

//   Map<String, dynamic>? _knowledgeData; // 直接用Map存储数据，无需创建模型类

//   // 消息监听订阅
//   StreamSubscription? _messageSubscription;
//   // 添加PageController控制页面滑动
//   final PageController _pageController = PageController(initialPage: 1);

//   @override
//   void initState() {
//     super.initState();
//     _initWebSocket();

//     // 新增: 初始化时添加监听器
//     WidgetsBinding.instance.addObserver(this);

//     // 新增: 监听输入框内容变化
//     _controller.addListener(_onInputChanged);

//     //注册跳转到登录页的通知接受
//     eventBus.on<LogoutEvent>().listen((event) {
//       Navigator.pushNamed(context, '/login');
//     });
//   }

//   @override
//   void dispose() {
//     _messageSubscription?.cancel();
//     _wsManager.disconnect();
//     _controller.dispose();
//     _scrollController.dispose();
//     _recordTimer?.cancel();
//     _pageController.dispose();

//     // 新增: 移除监听器
//     WidgetsBinding.instance.removeObserver(this);

//     super.dispose();
//   }

//   // 新增: 监听输入框内容变化
//   void _onInputChanged() {
//     final hasContent = _controller.text.trim().isNotEmpty;
//     if (_hasInputContent != hasContent) {
//       setState(() {
//         _hasInputContent = hasContent;
//       });
//     }
//   }

//   // 新增: 监听应用生命周期和键盘状态变化
//   @override
//   void didChangeMetrics() {
//     super.didChangeMetrics();

//     // 计算当前窗口的可见区域
//     final window = WidgetsBinding.instance.window;
//     final bottomInset = window.viewInsets.bottom;

//     // // 当底部内边距大于200时，判断为键盘弹出
//     // final isKeyboardVisible = bottomInset > 200;

//     // if (_isKeyboardVisible != isKeyboardVisible) {
//     //   setState(() {
//     //     _isKeyboardVisible = isKeyboardVisible;
//     //   });
//     // }
//   }

//   void _initWebSocket() async {
//     try {
//       await _wsManager.connect();
//       _messageSubscription = _wsManager.messageStream.listen(
//         (message) => _handleServerMessage(message),
//         onError: (error) => ToastUtil.showError('正在连接.....'),
//       );
//     } catch (e) {
//       _showError('WebSocket初始化失败: $e');
//     }
//   }

//   // 处理服务器消息
//   void _handleServerMessage(Map<String, dynamic> message) {
//     print('收到服务器消息: $message');
//     // 收到响应消息时关闭加载状态
//     if (message['action'] == 'response' || message['action'] == 'system_info') {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//     // 新增处理knowledge_info类型消息
//     if (message['action'] == 'knowledge_info') {
//       if (message['message'] is Map<String, dynamic>) {
//         setState(() {
//           _knowledgeData = message['message']; // 直接存储原始Map
//         });
//       }
//       return;
//     }

//     if (message['action'] == 'response') {
//       // 处理正常响应消息（保持不变）
//       final String segment = message['content'] ?? '';
//       final String messageId = message['message_id'] ?? ''; // 提取message_id
//       if (segment.isEmpty) return;

//       // if (_tempAIMessageIndex != null &&
//       //     _tempAIMessageIndex! < messages.length) {
//       //   messages[_tempAIMessageIndex!].appendText(segment);
//       //   setState(() {});
//       // } else {
//       //   final newMessage = ChatMessage(text: segment, isMe: false);
//       //   setState(() {
//       //     messages.add(newMessage);
//       //     _tempAIMessageIndex = messages.length - 1;
//       //   });
//       // }
//       // 情况1：当前没有正在处理的消息，或收到新的message_id
//       if (_currentProcessingMessageId == null ||
//           _currentProcessingMessageId != messageId) {
//         // 创建新消息，绑定messageId
//         final newMessage = ChatMessage(
//           text: segment,
//           isMe: false,
//           messageId: messageId, // 关联ID
//         );
//         setState(() {
//           messages.add(newMessage);
//           _tempAIMessageIndex = messages.length - 1;
//           _currentProcessingMessageId = messageId; // 更新当前处理的ID
//         });
//       }
//       // 情况2：同一个message_id的分块内容，继续追加
//       else if (_tempAIMessageIndex != null &&
//           _tempAIMessageIndex! < messages.length) {
//         messages[_tempAIMessageIndex!].appendText(segment);
//         setState(() {});
//       }

//       _scrollToBottom();
//       return;
//     }

//     if (message['action'] == 'history_data') {
//       // 处理历史消息数据
//       final List<dynamic>? history = message['history_data'];
//       if (history != null) {
//         _loadHistoryFromServer(history);
//       }
//     } else if (message['action'] == 'system_info') {
//       if (message['progress'] == 1) {
//         final String info = message['content'] ?? '';
//         // 提取;号后面的文字
//         String contentAfterSemicolon = info; // 默认使用原始内容

//         // 检查是否包含;号
//         if (info.contains('；')) {
//           // 分割字符串并获取;号后面的部分
//           List<String> parts = info.split('；');
//           if (parts.length > 1) {
//             // 拼接所有;号后面的内容（处理多个;的情况）
//             contentAfterSemicolon = parts.sublist(1).join('；').trim();
//           }
//         }
//         final newMessage = ChatMessage(
//           text: contentAfterSemicolon,
//           isMe: false,
//         );
//         setState(() {
//           messages.add(newMessage);
//           _tempAIMessageIndex = messages.length - 1;
//         });
//         _scrollToBottom();
//       }
//     } else {
//       print('未处理的消息类型: ${message['action']}');
//     }
//   }

//   // 从服务器加载历史消息并筛选不同类型
//   void _loadHistoryFromServer(List<dynamic> historyList) {
//     setState(() {
//       messages.clear();

//       for (var item in historyList) {
//         // 确保是Map类型且包含必要字段
//         if (item is Map<String, dynamic>) {
//           final String action = item['action'] ?? '';
//           final String datetime = item['datetime'] ?? '未知时间';

//           // 处理文件处理类型的历史记录
//           if (action == 'process_files') {
//             _handleProcessFilesHistory(item, datetime);
//           }
//           // 处理聊天类型的历史记录
//           else if (action == 'chat') {
//             _handleChatHistory(item);
//           }
//           // 可以添加其他类型的处理
//           else {
//             print('未处理的历史记录类型: $action');
//           }
//         }
//       }
//       // 所有历史记录处理完成后再更新UI和滚动到底部
//       setState(() {});
//       _scrollToBottom();
//     });
//   }

//   // 处理文件处理类型的历史记录
//   void _handleProcessFilesHistory(
//     Map<String, dynamic> item,
//     String datetime,
//   ) async {
//     // 构建文件信息字符串
//     String filesInfo = '';
//     // final List<dynamic> files = item['files'] ?? [];

//     // 构建消息内容
//     String content = '[${datetime}] 上传了文件: ';
//     final String response = item['action_response'] ?? '';
//     String contentAftersome = response;
//     if (response.contains('；')) {
//       List<String> parts = response.split('；');
//       if (parts.length > 1) {
//         contentAftersome = parts.sublist(1).join('；').trim();
//       }
//     }
//     if (response.isNotEmpty) {
//       content += contentAftersome;
//     }

//     final List<dynamic> files = item['files'] ?? [];
//     if (files.isNotEmpty) {
//       filesInfo = files
//           .map((file) {
//             if (file is Map<String, dynamic>) {
//               return file['filename'] ?? '未知文件';
//             }
//             return '未知文件';
//           })
//           .join('、');
//     }
//     //用户发的文件
//     final lsages = await http.post(
//       'chat/api_server/api/get_file_path',
//       data: {"filetype": "image/png", "filename": filesInfo},
//     );
//     setState(() {
//       messages.add(ChatMessage(imageUrl: lsages, isMe: true));
//       // 添加到消息列表（作为系统提示类型）
//       messages.add(ChatMessage(text: content, isMe: false));
//     });
//   }

//   // 处理聊天类型的历史记录
//   void _handleChatHistory(Map<String, dynamic> item) {
//     // 用户发送的查询
//     final String query = item['query'] ?? '';
//     if (query.isNotEmpty) {
//       messages.add(ChatMessage(text: query, isMe: true));
//     }

//     // AI的回复
//     final String response = item['response'] ?? '';
//     if (response.isNotEmpty) {
//       messages.add(ChatMessage(text: response, isMe: false));
//     }
//   }

//   // 添加消息到列表
//   void _addMessage(String text, {required bool isMe}) {
//     setState(() {
//       messages.add(ChatMessage(text: text, isMe: isMe));
//     });
//     _scrollToBottom();
//   }

//   // 发送消息
//   void _sendMessage(String text) {
//     if (text.trim().isEmpty) return;
//     FocusScope.of(context).unfocus();

//     _tempAIMessageIndex = null; // 清除AI临时消息索引
//     _addMessage(text, isMe: true); // 添加用户消息
//     _controller.clear();
//     // 发送消息前设置加载状态为true
//     setState(() {
//       _isLoading = true;
//     });
//     // 生成历史记录时使用完整文本
//     final bool success = _wsManager.sendMessage(
//       text,
//       history: messages
//           .map(
//             (m) => {
//               "role": m.isMe ? "user" : "assistant",
//               "content": m.fullText,
//             },
//           )
//           .toList(),
//     );
//     if (!success) {
//       _showError('发送失败，请检查网络连接');
//       // 发送失败时也需要关闭加载状态
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   // 滚动到底部
//   void _scrollToBottom() {
//     Future.delayed(const Duration(milliseconds: 50), () {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 200),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
//     );
//   }

//   // 显示提示消息
//   void _showToast(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         duration: const Duration(seconds: 2),
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   // 录音权限检查
//   Future<void> _checkPermissions() async {
//     var status = await Permission.microphone.status;
//     if (!status.isGranted) {
//       status = await Permission.microphone.request();
//       if (!status.isGranted) {
//         _showError('需要麦克风权限才能使用语音功能');
//         return;
//       }
//     }
//   }

//   void _startRecording() async {
//     // 检查权限
//     await _checkPermissions();

//     // 重置录音时长
//     _recordingDuration = 0;

//     // 更新UI状态
//     setState(() {
//       isRecording = true;
//       _isReleasing = false;
//     });

//     // 开始实际录音
//     try {
//       // 获取临时目录
//       final dir = await getTemporaryDirectory();
//       // 创建唯一的录音文件名
//       final path =
//           '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

//       // 开始录音
//       await _recorderas.start(
//         RecordConfig(encoder: AudioEncoder.aacHe),
//         path: path,
//       );

//       // 保存录音路径
//       setState(() {
//         _filePath = path;
//         _isRecording = true;
//       });

//       debugPrint('录音开始: $path');

//       // 启动录音计时器
//       _recordTimer?.cancel();
//       _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//         setState(() {
//           _recordingDuration++;
//         });
//       });
//     } catch (e) {
//       print('录音开始失败: $e');
//       _showToast('录音失败，请重试');
//       setState(() {
//         isRecording = false;
//         _isRecording = false;
//       });
//     }
//   }

//   // 停止录音并处理
//   void _stopRecording() async {
//     // 停止计时器
//     _recordTimer?.cancel();

//     // 如果没有录音或录音时间太短
//     if (!_isRecording || _recordingDuration < 1) {
//       if (_recordingDuration < 1 && _isRecording) {
//         _showToast('录音时间太短');
//         // 删除短录音文件
//         if (_filePath != null) {
//           final file = File(_filePath!);
//           if (await file.exists()) {
//             await file.delete();
//           }
//           setState(() {
//             _filePath = null;
//           });
//         }
//       }

//       // 重置状态
//       setState(() {
//         isRecording = false;
//         _isRecording = false;
//         _isReleasing = false;
//       });
//       return;
//     }

//     // 如果用户滑动到取消区域
//     if (_isReleasing) {
//       _showToast('已取消录音');
//       // 删除录音文件
//       if (_filePath != null) {
//         final file = File(_filePath!);
//         if (await file.exists()) {
//           await file.delete();
//         }
//         setState(() {
//           _filePath = null;
//         });
//       }

//       // 重置状态
//       setState(() {
//         isRecording = false;
//         _isRecording = false;
//         _isReleasing = false;
//       });
//       return;
//     }

//     // 正常停止录音
//     try {
//       // 停止录音
//       await _recorderas.stop();

//       // 更新状态
//       setState(() {
//         _isRecording = false;
//       });

//       // 发送录音
//       _sendAudioMessage();
//     } catch (e) {
//       print('录音停止失败: $e');
//       _showToast('录音处理失败，请重试');
//     } finally {
//       // 重置状态
//       setState(() {
//         isRecording = false;
//         _isReleasing = false;
//       });
//     }
//   }

//   //开始播放
//   Future<void> _toggle(StateSetter setState) async {
//     if (await Permission.microphone.request().isDenied) return;

//     if (_isRecording) {
//       final path = await _recorderas.stop();
//       setState(() {
//         _filePath = path;
//         _isRecording = false;
//       });
//     } else {
//       final dir = await getTemporaryDirectory();
//       final path =
//           '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
//       await _recorderas.start(
//         RecordConfig(encoder: AudioEncoder.aacHe),
//         path: path,
//       );
//       setState(() => _isRecording = true);
//       debugPrint('录音成功$path');
//     }
//   }

//   // 播放录音的方法
//   Future<void> _play() async {
//     // 如果存在录音文件路径，则播放录音
//     if (_filePath != null) {
//       await _player.play(DeviceFileSource(_filePath!));
//     }
//   }

//   // 播放录音的方法
//   Future<void> _plays(
//     String? audioPath,
//     String? audioUrl,
//     ChatMessage message,
//   ) async {
//     // 切换播放状态
//     setState(() {
//       message.isPlaying = !message.isPlaying;
//     });

//     if (message.isPlaying) {
//       // 停止其他正在播放的音频
//       _stopOtherAudios(message);

//       try {
//         // 播放录音
//         if (audioUrl != null && audioUrl.isNotEmpty) {
//           await _player.play(UrlSource(audioUrl));
//         } else if (audioPath != null) {
//           await _player.play(DeviceFileSource(audioPath));
//         }

//         // 监听播放完成
//         _player.onPlayerComplete.listen((_) {
//           setState(() {
//             message.isPlaying = false;
//           });
//         });
//       } catch (e) {
//         print('播放失败: $e');
//         _showToast('播放失败，请重试');
//         setState(() {
//           message.isPlaying = false;
//         });
//       }
//     } else {
//       // 停止播放
//       await _player.stop();
//     }
//   }

//   // 停止其他正在播放的音频
//   void _stopOtherAudios(ChatMessage currentMessage) {
//     for (var msg in messages) {
//       if (msg != currentMessage && msg.isPlaying) {
//         setState(() {
//           msg.isPlaying = false;
//         });
//         _player.stop();
//       }
//     }
//   }

//   //发送录音文件到聊天服务器
//   Future<void> _sendAudioMessage() async {
//     if (_filePath == null) {
//       _showToast('没有录音文件可发送');
//       return;
//     }

//     // 关闭录音弹窗
//     Navigator.of(context).pop();

//     // 获取录音文件信息
//     final file = File(_filePath!);
//     if (!await file.exists()) {
//       _showToast('录音文件不存在');
//       return;
//     }

//     // 获取文件大小
//     final fileSizeInBytes = await file.length();
//     final fileSizeInKB = (fileSizeInBytes / 1024).round();

//     // 获取录音时长（需要添加audio_session依赖来获取时长）
//     // 简化处理：这里不实际获取时长，仅作为示例
//     final duration = "未知时长";

//     // 在聊天列表中添加临时消息
//     int messageIndex = -1;
//     setState(() {
//       messages.add(
//         ChatMessage(
//           isMe: true,
//           text: '正在发送录音...',
//           fileInfo: {
//             'name': path.basename(_filePath!),
//             'path': _filePath!,
//             'status': 'uploading',
//             'type': 'audio',
//             'duration': duration,
//             'size': fileSizeInKB,
//           },
//         ),
//       );
//       messageIndex = messages.length - 1;
//     });
//     _scrollToBottom();

//     try {
//       // 1. 请求上传URL
//       final fileName = path.basename(_filePath!);
//       final uploadUrlResponse = await http.post(
//         'file/uploadUrl',
//         data: {
//           "files": [
//             {"contentType": 'audio/m4a', "fileName": fileName},
//           ],
//         },
//       );

//       if (uploadUrlResponse['code'] != 200 ||
//           !(uploadUrlResponse['data'] is List) ||
//           uploadUrlResponse['data'].isEmpty) {
//         _updateFileMessageStatus(messageIndex, 'failed', '获取上传地址失败');
//         return;
//       }

//       // 提取上传URL
//       final uploadUrl = uploadUrlResponse['data'][0]['url'] ?? '';
//       if (uploadUrl.isEmpty) {
//         _updateFileMessageStatus(messageIndex, 'failed', '上传地址无效');
//         return;
//       }

//       // 2. 上传录音文件
//       final dio = Dio();
//       final response = await dio.put(
//         uploadUrl,
//         data: await file.readAsBytes(),
//         options: Options(
//           contentType: 'audio/m4a',
//           headers: {'Content-Length': fileSizeInBytes.toString()},
//         ),
//         onSendProgress: (sent, total) {
//           final progress = (sent / total * 100).round();
//           _updateFileMessageStatus(
//             messageIndex,
//             'uploading',
//             '正在上传: $progress%',
//           );
//         },
//       );

//       if (response.statusCode == 200) {
//         // 3. 通知服务器文件已上传
//         await http.post(
//           'chat/api_server/api/upload_file_remind',
//           data: {
//             "files": [
//               {
//                 "file_type": 'audio/m4a',
//                 "filename": fileName,
//                 "size_readable": fileSizeInKB,
//               },
//             ],
//           },
//         );

//         // 获取文件在线访问路径
//         final fileUrlResponse = await http.post(
//           'chat/api_server/api/get_file_path',
//           data: {"filetype": 'audio/m4a', "filename": fileName},
//         );

//         // 更新消息为上传成功状态
//         _updateFileMessageStatus(
//           messageIndex,
//           'success',
//           '录音发送成功',
//           fileUrl: fileUrlResponse ?? '',
//         );

//         _showToast('录音发送成功');

//         // 清空录音文件路径，准备下次录音
//         setState(() {
//           _filePath = null;
//         });
//       } else {
//         _updateFileMessageStatus(
//           messageIndex,
//           'failed',
//           '上传失败，状态码: ${response.statusCode}',
//         );
//       }
//     } catch (e) {
//       _updateFileMessageStatus(messageIndex, 'failed', '上传异常: ${e.toString()}');
//       print('录音上传异常: $e');
//     }
//   }

//   // 发送图片消息
//   void _sendImageMessage(String imagePath) async {
//     int messageIndex;
//     setState(() {
//       messages.add(
//         ChatMessage(
//           isMe: true,
//           localImagePath: imagePath, // 先显示本地图片
//           text: '上传中...', // 显示上传状态
//         ),
//       );
//       messageIndex = messages.length - 1; // 保存当前消息索引
//     });
//     _scrollToBottom();

//     String fileName = path.basename(imagePath);
//     //获取图片文件
//     File imageFile = File(imagePath);
//     //获取文件大小（大小）
//     int fileSizeInBytes = await imageFile.length();
//     //转kb
//     int fileSizeInKBInt = (fileSizeInBytes / 1024).round();
//     final res = await http.post(
//       'file/uploadUrl',
//       data: {
//         "files": [
//           {"contentType": "image/png", "fileName": fileName},
//         ],
//       },
//     );

//     // debugPrint('上传结果$res');
//     final age = await http.post(
//       'chat/api_server/api/upload_file_remind',
//       data: {
//         "files": [
//           {
//             "file_type": "image/png",
//             "filename": fileName,
//             "size_readable": fileSizeInKBInt,
//           },
//         ],
//       },
//     );
//     final ages = await http.post(
//       'chat/api_server/api/get_file_path',
//       data: {"filetype": "image/png", "filename": fileName},
//     );
//     String onlineImageUrl = ages ?? '';
//     debugPrint('返回浏览结果$ages');
//     debugPrint('通知ws$age');
//     setState(() {
//       // messages.add(ChatMessage(isMe: true, imageUrl: ages));
//     });
//     _scrollToBottom();

//     if (res['code'] == 200) {
//       if (res['data'] is List && res['data'].isNotEmpty) {
//         //提取临时的上传链接
//         String imageUrl = res['data'][0]['url'] ?? '';
//         if (imageUrl.isNotEmpty) {
//           debugPrint('临时连接$imageUrl');
//           try {
//             // 读取图片文件
//             File imageFile = File(imagePath);
//             List<int> imageBytes = await imageFile.readAsBytes();

//             // 创建Dio实例并配置
//             Dio dio = Dio();
//             Response response = await dio.put(
//               imageUrl,
//               data: imageBytes,
//               options: Options(
//                 contentType: 'image/png', // 设置正确的内容类型
//                 headers: {
//                   'Content-Length': imageBytes.length.toString(), // 设置内容长度
//                 },
//               ),
//             );
//             // 检查上传结果
//             if (response.statusCode == 200) {
//               debugPrint('图片上传成功');
//               _showToast('图片上传成功');
//             } else {
//               debugPrint('图片上传失败，状态码: ${response.statusCode}');
//               _showError('图片上传失败，请重试');
//             }
//           } catch (e) {
//             debugPrint('图片上传异常: $e');
//             _showError('图片上传失败: $e');
//           }
//         }
//       }
//     }
//   }

//   // 拍照功能处理
//   void _handleCameraTap() async {
//     var status = await Permission.camera.status;
//     setState(() => showFunctions = false);
//     if (!status.isGranted) {
//       status = await Permission.camera.request();
//       if (!status.isGranted) {
//         _showError('需要相机权限才能使用拍照功能');
//         return;
//       }
//     }

//     try {
//       final picker = ImagePicker();
//       final pickedFile = await picker.pickImage(
//         source: ImageSource.camera,
//         imageQuality: 80,
//         maxWidth: 800,
//       );

//       if (pickedFile != null) {
//         _sendImageMessage(pickedFile.path);
//         showFunctions = true;
//       } else {
//         _showToast('未选择图片');
//       }
//     } catch (e) {
//       _showError('拍照失败: $e');
//       print('拍照异常: $e');
//     }
//   }

//   // 相册功能处理
//   void _handleGalleryTap() async {
//     try {
//       setState(() => showFunctions = false);
//       final picker = ImagePicker();
//       final pickedFile = await picker.pickImage(
//         source: ImageSource.gallery,
//         imageQuality: 80,
//         maxWidth: 800,
//       );

//       if (pickedFile != null) {
//         _sendImageMessage(pickedFile.path);
//       } else {
//         _showToast('未选择图片');
//       }
//     } catch (e) {
//       _showError('选择图片失败: $e');
//       print('相册选择异常: $e');
//     }
//   }

//   // 文件功能处理
//   void _handleFileTap() {
//     // setState(() => showFunctions = false);
//     _handleFileUpload();
//   }

//   void _handleFileUpload() async {
//     try {
//       // 隐藏功能菜单
//       setState(() => showFunctions = false);

//       // 1. 使用flutter_file_dialog选择文件
//       // 支持的文件类型，这里设置为所有类型，可根据需求调整
//       final params = OpenFileDialogParams(
//         dialogType: OpenFileDialogType.document,
//         // 可以指定允许的文件类型，例如：
//         // allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
//       );

//       // 打开文件选择对话框
//       final result = await FlutterFileDialog.pickFile(params: params);

//       // 检查是否选择了文件
//       if (result == null) {
//         _showToast('未选择文件');
//         return;
//       }

//       // 获取选择的文件路径
//       final filePath = result;
//       if (filePath == null || filePath.isEmpty) {
//         _showToast('文件路径无效');
//         return;
//       }

//       // 2. 在聊天列表中添加一个临时消息，显示上传状态
//       int? messageIndex;
//       final fileName = path.basename(filePath);
//       setState(() {
//         messages.add(
//           ChatMessage(
//             isMe: true,
//             text: '正在上传文件: $fileName',
//             fileInfo: {
//               'name': fileName,
//               'path': filePath,
//               'status': 'uploading',
//             },
//           ),
//         );
//         messageIndex = messages.length - 1;
//       });
//       _scrollToBottom();

//       // 3. 获取文件信息并上传
//       final file = File(filePath);
//       if (!await file.exists()) {
//         _updateFileMessageStatus(messageIndex!, 'failed', '文件不存在');
//         return;
//       }

//       // 获取文件大小
//       final fileSizeInBytes = await file.length();
//       final fileSizeInKB = (fileSizeInBytes / 1024).round();

//       // 获取文件MIME类型
//       final mimeType = await _getMimeType(filePath);

//       // 4. 先请求上传URL（与现有图片上传逻辑类似）
//       final uploadUrlResponse = await http.post(
//         'file/uploadUrl',
//         data: {
//           "files": [
//             {
//               "contentType": mimeType ?? 'application/octet-stream',
//               "fileName": fileName,
//             },
//           ],
//         },
//       );

//       if (uploadUrlResponse['code'] != 200 ||
//           !(uploadUrlResponse['data'] is List) ||
//           uploadUrlResponse['data'].isEmpty) {
//         _updateFileMessageStatus(messageIndex!, 'failed', '获取上传地址失败');
//         return;
//       }

//       // 提取上传URL
//       final uploadUrl = uploadUrlResponse['data'][0]['url'] ?? '';
//       if (uploadUrl.isEmpty) {
//         _updateFileMessageStatus(messageIndex!, 'failed', '上传地址无效');
//         return;
//       }

//       // 5. 上传文件到获取的URL
//       try {
//         final dio = Dio();
//         final response = await dio.put(
//           uploadUrl,
//           data: await file.readAsBytes(),
//           options: Options(
//             contentType: mimeType ?? 'application/octet-stream',
//             headers: {'Content-Length': fileSizeInBytes.toString()},
//           ),
//           // 可以添加上传进度监听
//           onSendProgress: (sent, total) {
//             final progress = (sent / total * 100).round();
//             _updateFileMessageStatus(
//               messageIndex!,
//               'uploading',
//               '正在上传: $progress%',
//             );
//           },
//         );

//         if (response.statusCode == 200) {
//           // 6. 上传成功，通知服务器并更新消息状态
//           await http.post(
//             'chat/api_server/api/upload_file_remind',
//             data: {
//               "files": [
//                 {
//                   "file_type": mimeType ?? 'unknown',
//                   "filename": fileName,
//                   "size_readable": fileSizeInKB,
//                 },
//               ],
//             },
//           );

//           // 获取文件在线访问路径
//           final fileUrlResponse = await http.post(
//             'chat/api_server/api/get_file_path',
//             data: {"filetype": mimeType ?? 'unknown', "filename": fileName},
//           );

//           // 更新消息为上传成功状态
//           _updateFileMessageStatus(
//             messageIndex!,
//             'success',
//             '文件上传成功',
//             fileUrl: fileUrlResponse ?? '',
//           );

//           _showToast('文件上传成功');
//         } else {
//           _updateFileMessageStatus(
//             messageIndex!,
//             'failed',
//             '上传失败，状态码: ${response.statusCode}',
//           );
//         }
//       } catch (e) {
//         _updateFileMessageStatus(
//           messageIndex!,
//           'failed',
//           '上传异常: ${e.toString()}',
//         );
//         print('文件上传异常: $e');
//       }
//     } catch (e) {
//       _showError('文件处理失败: $e');
//       print('文件选择/上传异常: $e');
//     }
//   }

//   // 更新文件消息状态
//   void _updateFileMessageStatus(
//     int messageIndex,
//     String status,
//     String text, {
//     String fileUrl = '',
//   }) {
//     if (messageIndex >= 0 && messageIndex < messages.length) {
//       setState(() {
//         // 更新消息文本
//         messages[messageIndex].text = text;
//         // 更新文件信息状态
//         if (messages[messageIndex].fileInfo != null) {
//           messages[messageIndex].fileInfo!['status'] = status;
//           if (fileUrl.isNotEmpty) {
//             messages[messageIndex].fileInfo!['url'] = fileUrl;
//           }
//         }
//       });
//       _scrollToBottom();
//     }
//   }

//   // 获取文件MIME类型
//   Future<String?> _getMimeType(String filePath) async {
//     // 简单根据文件扩展名判断MIME类型
//     final ext = path.extension(filePath).toLowerCase();
//     switch (ext) {
//       case '.pdf':
//         return 'application/pdf';
//       case '.doc':
//       case '.docx':
//         return 'application/msword';
//       case '.xls':
//       case '.xlsx':
//         return 'application/vnd.ms-excel';
//       case '.ppt':
//       case '.pptx':
//         return 'application/vnd.ms-powerpoint';
//       case '.txt':
//         return 'text/plain';
//       case '.jpg':
//       case '.jpeg':
//         return 'image/jpeg';
//       case '.png':
//         return 'image/png';
//       case '.gif':
//         return 'image/gif';
//       default:
//         return 'application/octet-stream'; // 未知类型
//     }
//   }

//   // 录音功能处理
//   void _handleAudioTap() async {
//     var status = await Permission.microphone.status;
//     if (!status.isGranted) {
//       status = await Permission.microphone.request();
//       if (!status.isGranted) {
//         _showError('需要麦克风权限才能使用录音功能');
//         return;
//       }
//     }
//     _showRecordingBottomSheet(); // 显示底部弹窗
//   }

//   // 显示录音底部弹窗
//   void _showRecordingBottomSheet() {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) =>
//             _buildRecordingSheetContent(context, setState),
//       ),
//     );
//   }

//   Widget _buildRecordingSheetContent(
//     BuildContext context,
//     StateSetter setState,
//   ) {
//     return Scaffold(
//       appBar: AppBar(title: const Text(' 录音')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // 录音/停止按钮
//             ElevatedButton(
//               onPressed: () => _toggle(setState),
//               child: Text(_isRecording ? '停止录音' : '开始录音'),
//             ),
//             const SizedBox(height: 12), // 间距
//             // 当不在录音且存在录音文件时，显示文件信息和播放按钮
//             if (!_isRecording && _filePath != null) ...[
//               // 显示录音文件名（仅显示文件名，不显示完整路径）
//               Text('已保存: ${_filePath!.split('/').last}'),
//               // 播放按钮
//               ElevatedButton(onPressed: _play, child: const Text('播放')),
//               ElevatedButton(
//                 onPressed: _sendAudioMessage,
//                 child: const Text('发送'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   setState(() => _filePath = null);
//                   Navigator.of(context).pop();
//                 },
//                 child: const Text('取消'),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   // 录音覆盖层
//   Widget _buildRecordingOverlay() {
//     return Positioned.fill(
//       child: GestureDetector(
//         // 监听滑动事件，用于取消录音
//         onLongPressMoveUpdate: (details) {
//           // 检测是否滑动到取消区域（屏幕上半部分）
//           if (details.localPosition.dy <
//               MediaQuery.of(context).size.height / 2) {
//             setState(() {
//               _isReleasing = true;
//             });
//           } else {
//             setState(() {
//               _isReleasing = false;
//             });
//           }
//         },
//         child: Container(
//           color: Colors.black54,
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const SizedBox(height: 30),
//               _buildVoiceAnimation(),
//               const SizedBox(height: 30),
//               // 显示录音时长
//               Text(
//                 '${_recordingDuration ~/ 60}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
//                 style: const TextStyle(color: Colors.white, fontSize: 24),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 _isReleasing ? '松开 取消' : '说话中...',
//                 style: const TextStyle(color: Colors.white, fontSize: 20),
//               ),
//               const SizedBox(height: 100),
//               Text(
//                 _isReleasing ? '取消发送' : '松开 发送',
//                 style: const TextStyle(color: Colors.white, fontSize: 18),
//               ),
//               const SizedBox(height: 40),
//               // 取消提示图标
//               if (_isReleasing)
//                 const Icon(Icons.delete, color: Colors.red, size: 40),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildVoiceAnimation() {
//     return Container(
//       width: _isReleasing ? 80 : 120,
//       height: _isReleasing ? 40 : 80,
//       child: Image.asset(
//         'assets/chat/record.gif',
//         color: _isReleasing ? Colors.red : null,
//         fit: BoxFit.contain,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: PageView(
//           controller: _pageController,
//           // 禁止页面无限滚动
//           physics: const ClampingScrollPhysics(),
//           children: [
//             // 左滑页面
//             _buildLeftScreen(),
//             // 中间主聊天页面
//             _buildMainChatScreen(),
//             // 右滑页面
//             // _buildRightScreen(),
//           ],
//         ),
//       ),
//     );
//   }

//   // 主聊天界面（原有内容）
//   Widget _buildMainChatScreen() {
//     return Stack(
//       children: [
//         Container(
//           decoration: BoxDecoration(
//             image: DecorationImage(
//               image: const AssetImage('assets/chat/bg1.png'),
//               fit: BoxFit.cover,
//             ),
//           ),
//         ),
//         Column(
//           children: [
//             _buildAppBar(),
//             // 消息列表
//             Expanded(
//               child: Align(
//                 alignment: Alignment.bottomCenter,
//                 child: ListView.builder(
//                   controller: _scrollController,
//                   shrinkWrap: true,
//                   padding: const EdgeInsets.symmetric(vertical: 20),
//                   itemCount: messages.length + (_isLoading ? 1 : 0),
//                   itemBuilder: (context, index) {
//                     // 如果是最后一个item且处于加载状态，显示加载指示器
//                     if (_isLoading && index == messages.length) {
//                       return const ChatLoadingIndicator();
//                     }
//                     return ChatBubble(
//                       message: messages[index],
//                       onAudioPlay: (audioPath, audioUrl, message) =>
//                           _plays(audioPath, audioUrl, message),
//                     );
//                   },
//                 ),
//               ),
//             ),
//             _buildInputBar(),
//             if (showFunctions) _buildBottomBar(),
//             // 底部说明文字
//             Container(
//               height: 60,
//               color: Colors.white,
//               child: const Align(
//                 alignment: Alignment.topCenter,
//                 child: Padding(
//                   padding: EdgeInsets.only(top: 5),
//                   child: Text(
//                     '以上内容由云奕AI生成',
//                     style: TextStyle(fontSize: 11, color: Colors.blueGrey),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         if (isRecording) _buildRecordingOverlay(),
//       ],
//     );
//   }

//   // 左滑页面内容
//   Widget _buildLeftScreen() {
//     final stats = _knowledgeData?['statistics'] ?? {};
//     final fileBreakdown = stats['file_breakdown'] ?? {};
//     // final exportTime = _knowledgeData?['export_time'] ?? '未导出';
//     return Scaffold(
//       // appBar: AppBar(
//       //   title: const Text(''),
//       //   automaticallyImplyLeading: false, // 去除返回按钮
//       // ),
//       body: Container(
//         decoration: BoxDecoration(
//           image: DecorationImage(
//             image: const AssetImage('assets/chat/bg1.png'),
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // 标题和导出按钮 Row
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     '用户数据信息',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     // 增加文字阴影，在背景图上更清晰
//                     // shadows: [Shadow(color: Colors.white, blurRadius: 3)],
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),
//               // 表格内容，使用带透明背景的Container包裹，提升可读性
//               Container(
//                 color: Colors.white.withOpacity(0.85),
//                 child: Table(
//                   border: TableBorder.all(
//                     color: Colors.grey.shade300,
//                     width: 1,
//                   ),
//                   children: [
//                     _buildTableRow(
//                       '对话数量',
//                       (stats['history_count'] ?? 0).toString(),
//                     ),
//                     _buildTableRow(
//                       '记忆数量',
//                       (stats['memory_count'] ?? 0).toString(),
//                     ),
//                     _buildTableRow(
//                       '上传文件数量',
//                       (stats['uploaded_file_count'] ?? 0).toString(),
//                     ),
//                     _buildTableRow(
//                       '输出报告数',
//                       (stats['report_count'] ?? 0).toString(),
//                     ),
//                     _buildTableRow(
//                       '知识向量数',
//                       (stats['total_vectors'] ?? 0).toString(),
//                     ),
//                     _buildTableRow(
//                       '文档数量',
//                       (fileBreakdown['document_count'] ?? 0).toString(),
//                     ),
//                     _buildTableRow(
//                       '音频数量',
//                       (fileBreakdown['audio_count'] ?? 0).toString(),
//                     ),
//                     _buildTableRow(
//                       '图片数量',
//                       (fileBreakdown['image_count'] ?? 0).toString(),
//                     ),
//                     _buildTableRow(
//                       '视频数量',
//                       (fileBreakdown['video_count'] ?? 0).toString(),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // 辅助函数，构建表格的每一行
//   TableRow _buildTableRow(String label, String value) {
//     return TableRow(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(8),
//           color: Colors.grey.shade100,
//           child: Text(
//             label,
//             style: const TextStyle(fontWeight: FontWeight.w500),
//           ),
//         ),
//         Container(padding: const EdgeInsets.all(8), child: Text(value)),
//       ],
//     );
//   }

//   // 右滑页面内容
//   Widget _buildRightScreen() {
//     // 任务列表，包含不同状态的任务
//     List<Task> tasks = [
//       Task(
//         name: "任务1.png",
//         status: "已完成",
//         detail: "1.png-等信息处理-2025-08-10 16:24:36 任务处理完成...",
//       ),
//       Task(name: "任务IMG_20250723_204435.jpg", status: "已完成", detail: ""),
//       Task(name: "任务数据分析报告.docx", status: "待处理", detail: ""),
//       Task(name: "任务季度总结.pptx", status: "待处理", detail: ""),
//       Task(name: "任务IMG_20250723_204420.jpg", status: "已完成", detail: ""),
//       Task(name: "任务系统升级方案.pdf", status: "失败", detail: "升级过程中出现兼容性问题"),
//       Task(
//         name: "任务10.1126@science.352.6285.508.pdf",
//         status: "已完成",
//         detail: "",
//       ),
//       Task(name: "任务用户调研表.xlsx", status: "待处理", detail: ""),
//       Task(name: "任务大尺寸.png", status: "已完成", detail: ""),
//       Task(name: "任务服务器部署脚本.sh", status: "失败", detail: "权限不足导致部署失败"),
//     ];

//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           image: DecorationImage(
//             image: const AssetImage('assets/chat/bg1.png'),
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // 任务池标题
//               const Text(
//                 '任务池',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   shadows: [Shadow(color: Colors.white, blurRadius: 3)],
//                 ),
//               ),

//               const SizedBox(height: 16), // 标题与列表之间的间距
//               // 任务列表
//               Expanded(
//                 child: ListView.builder(
//                   padding: const EdgeInsets.only(top: 10),
//                   itemCount: tasks.length,
//                   itemBuilder: (context, index) {
//                     Task task = tasks[index];

//                     // 根据任务状态设置颜色
//                     Color statusColor;
//                     switch (task.status) {
//                       case "已完成":
//                         statusColor = Colors.green;
//                         break;
//                       case "待处理":
//                         statusColor = Colors.blue;
//                         break;
//                       case "失败":
//                         statusColor = Colors.red;
//                         break;
//                       default:
//                         statusColor = Colors.grey;
//                     }

//                     return Container(
//                       margin: const EdgeInsets.symmetric(
//                         vertical: 4,
//                         horizontal: 8,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.85),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: ExpansionTile(
//                         title: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               task.name,
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: statusColor.withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: Text(
//                                 task.status,
//                                 style: TextStyle(
//                                   color: statusColor,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         children: [
//                           if (task.detail != null && task.detail!.isNotEmpty)
//                             Padding(
//                               padding: const EdgeInsets.all(12.0),
//                               child: Text(task.detail!),
//                             ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // 顶部导航栏
//   Widget _buildAppBar() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 15, bottom: 5, right: 10, left: 10),
//       child: Row(
//         children: [
//           GestureDetector(
//             onTap: () {
//               // 个人资料页面跳转
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const ProfilePageCustom(),
//                 ),
//               );
//             },
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(50.0),
//               // 通过设置宽度和高度缩小头像
//               child: SizedBox(
//                 width: 40, // 缩小头像宽度
//                 height: 40, // 缩小头像高度
//                 child: userInfo['avatar'] != null
//                     ? Image.network(
//                         userInfo['avatar'],
//                         fit: BoxFit.cover, // 确保图片填充整个容器
//                       )
//                     : Image.asset('assets/login/6.png', fit: BoxFit.cover),
//               ),
//             ),
//           ),
//           const Spacer(),
//           // GestureDetector(
//           //   onTap: () {
//           //     // 历史记录页面跳转
//           //     Navigator.push(
//           //       context,
//           //       MaterialPageRoute(builder: (context) => const HistoryPage()),
//           //     );
//           //   },
//           //   child: const Image(
//           //     image: AssetImage('assets/chat/history.png'),
//           //     width: 30,
//           //   ),
//           // ),
//         ],
//       ),
//     );
//   }

//   // 输入栏 - 已修改以实现动态图标切换
//   Widget _buildInputBar() {
//     const double horizontalPadding = 16;
//     const double verticalPadding = 14;

//     return Container(
//       color: Colors.white,
//       padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           // 语音/文字切换按钮
//           GestureDetector(
//             onTap: () => setState(() => isVoiceMode = !isVoiceMode),
//             child: Container(
//               margin: const EdgeInsets.only(bottom: 13.55),
//               child: Image(
//                 image: AssetImage(
//                   isVoiceMode ? 'assets/chat/8.png' : 'assets/chat/7.png',
//                 ),
//                 width: 30,
//                 height: 30,
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           // 主输入容器
//           Expanded(
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(24),
//                 border: Border.all(color: Colors.grey[300]!),
//               ),
//               constraints: const BoxConstraints(minHeight: 60),
//               child: Stack(
//                 children: [
//                   // 文本输入模式
//                   Offstage(
//                     offstage: isVoiceMode,
//                     child: TextField(
//                       controller: _controller,
//                       decoration: InputDecoration(
//                         hintText: '输入消息...',
//                         border: InputBorder.none,
//                         contentPadding: EdgeInsets.symmetric(
//                           horizontal: horizontalPadding,
//                           vertical: verticalPadding,
//                         ),
//                       ),
//                       style: const TextStyle(fontSize: 17),
//                       minLines: 1,
//                       maxLines: 3,
//                       textInputAction: TextInputAction.send,
//                       onSubmitted: _sendMessage,
//                     ),
//                   ),
//                   // 语音输入模式
//                   Offstage(
//                     offstage: !isVoiceMode,
//                     child: Align(
//                       alignment: Alignment.center,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: horizontalPadding,
//                           vertical: verticalPadding,
//                         ),
//                         height: 50,
//                         child: GestureDetector(
//                           onLongPressStart: (_) => _startRecording(),
//                           onLongPressEnd: (_) => _stopRecording(),
//                           onLongPressCancel: () => _stopRecording(),
//                           child: const Text(
//                             '按住说话',
//                             style: TextStyle(color: Colors.grey, fontSize: 17),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           // 右侧图标 - 根据键盘状态和输入内容动态切换
//           if (!isVoiceMode) _buildRightIcon(),
//           if (isVoiceMode)
//             GestureDetector(
//               onTap: () => setState(() => showFunctions = !showFunctions),
//               child: Container(
//                 margin: const EdgeInsets.only(bottom: 14),
//                 child: Image(
//                   width: 30,
//                   height: 30,
//                   image: AssetImage(
//                     showFunctions ? 'assets/chat/14.png' : 'assets/chat/5.png',
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   // 新增: 根据键盘状态和输入内容构建右侧图标
//   Widget _buildRightIcon() {
//     // 逻辑:
//     // 1. 键盘弹出时，显示功能菜单切换图标
//     // 2. 键盘未弹出但有输入内容时，显示发送图标(fson.svg)
//     // 3. 其他情况显示功能菜单切换图标

//     if (_hasInputContent) {
//       // 键盘未弹出且有输入内容，显示发送图标
//       return GestureDetector(
//         onTap: () => _sendMessage(_controller.text),
//         child: Container(
//           margin: const EdgeInsets.only(bottom: 14),
//           child: Image(
//             width: 30,
//             height: 30,
//             image: const AssetImage('assets/chat/fs.png'), // 发送图标
//           ),
//         ),
//       );
//     } else {
//       // 其他情况显示功能菜单切换图标
//       return GestureDetector(
//         onTap: () => setState(() => showFunctions = !showFunctions),
//         child: Container(
//           margin: const EdgeInsets.only(bottom: 13.5),
//           child: Image(
//             width: 30,
//             height: 30,
//             image: AssetImage(
//               showFunctions ? 'assets/chat/14.png' : 'assets/chat/5.png',
//             ),
//           ),
//         ),
//       );
//     }
//   }

//   // 底部功能栏
//   Widget _buildBottomBar() {
//     return Container(
//       height: 95,
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
//       color: Colors.white,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           _BottomIcon(
//             icon: 'assets/chat/13.png',
//             label: '拍照',
//             onTap: _handleCameraTap,
//           ),
//           _BottomIcon(
//             icon: 'assets/chat/12.png',
//             label: '相册',
//             onTap: _handleGalleryTap,
//           ),
//           _BottomIcon(
//             icon: 'assets/chat/10.png',
//             label: '文件',
//             onTap: _handleFileTap,
//           ),
//           _BottomIcon(
//             icon: 'assets/chat/11.png',
//             label: '录音',
//             onTap: _handleAudioTap,
//           ),
//         ],
//       ),
//     );
//   }
// }

// // 5. 创建加载指示器组件
// class ChatLoadingIndicator extends StatelessWidget {
//   const ChatLoadingIndicator({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.start, // AI消息在左侧
//         children: [
//           // AI头像
//           // Container(
//           //   width: 40,
//           //   height: 40,
//           //   decoration: const BoxDecoration(
//           //     shape: BoxShape.circle,
//           //     color: Colors.grey,
//           //     image: DecorationImage(
//           //       image: AssetImage('assets/chat/ai_avatar.png'), // 替换为你的AI头像
//           //       fit: BoxFit.cover,
//           //     ),
//           //   ),
//           // ),
//           const SizedBox(width: 10),
//           // 加载指示器和文字
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               borderRadius: const BorderRadius.only(
//                 topRight: Radius.circular(16),
//                 bottomLeft: Radius.circular(16),
//                 bottomRight: Radius.circular(16),
//               ),
//             ),
//             child: Row(
//               children: const [
//                 Text(
//                   "正在思考中...",
//                   style: TextStyle(color: Colors.grey, fontSize: 14),
//                 ),
//                 SizedBox(width: 8),
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     valueColor: AlwaysStoppedAnimation(Colors.grey),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // 聊天消息模型
// class ChatMessage {
//   String text; // 直接存储完整文本
//   final bool isMe;
//   final double? progress;
//   final String? imageUrl;
//   final String? localImagePath; // 本地图片路径（用于上传过程中显示）
//   final String? messageId; // 新增：存储消息唯一ID
//   final Map<String, dynamic>? fileInfo; // 新增：用于存储文件信息
//   String _fullText;
//   bool isPlaying; // 音频是否正在播放
//   // 构造方法
//   ChatMessage({
//     this.text = '',
//     required this.isMe,
//     this.progress,
//     this.imageUrl,
//     this.localImagePath,
//     this.messageId,
//     this.fileInfo, // 新增参数
//     this.isPlaying = false, // 默认不播放
//   }) : _fullText = text;

//   // 添加文本（AI流式回复用）
//   void appendText(String text) {
//     this.text += text;
//   }

//   // 获取完整文本
//   String get fullText => text;
//   // 新增：用于更新消息状态的复制方法
//   ChatMessage copyWith({
//     String? text,
//     bool? isMe,
//     double? progress,
//     String? messageId,
//     String? imageUrl,
//     String? localImagePath,
//     bool? isPlaying,
//   }) {
//     return ChatMessage(
//       text: text ?? this.text,
//       isMe: isMe ?? this.isMe,
//       progress: progress ?? this.progress,
//       imageUrl: imageUrl ?? this.imageUrl,
//       messageId: messageId ?? this.messageId, // 复制时携带ID
//       localImagePath: localImagePath ?? this.localImagePath,
//       isPlaying: isPlaying ?? this.isPlaying,
//     );
//   }
// }

// // 聊天气泡组件
// class ChatBubble extends StatelessWidget {
//   final ChatMessage message;
//   final Function(String?, String?, ChatMessage) onAudioPlay;
//   ChatBubble({super.key, required this.message, required this.onAudioPlay});

//   @override
//   Widget build(BuildContext context) {
//     // 处理文件消息
//     if (message.fileInfo != null) {
//       // 如果是音频文件，使用音频消息UI
//       if (message.fileInfo!['type'] == 'audio') {
//         return _buildAudioMessage(context);
//       }
//       return _buildFileMessage(context);
//     }
//     final isMe = message.isMe;
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       child: Row(
//         mainAxisAlignment: isMe
//             ? MainAxisAlignment.end
//             : MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [_bubbleContent(context)],
//       ),
//     );
//   }

//   // 构建音频消息UI
//   Widget _buildAudioMessage(BuildContext context) {
//     final fileInfo = message.fileInfo!;
//     final fileName = fileInfo['name'] ?? '未知音频';
//     final duration = fileInfo['duration'] ?? '00:00';
//     final fileSize = fileInfo['size'] ?? 0;
//     final status = fileInfo['status'] ?? 'unknown';
//     final filePath = fileInfo['path'] ?? '';
//     final fileUrl = fileInfo['url'] ?? '';

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: Row(
//         mainAxisAlignment: message.isMe
//             ? MainAxisAlignment.end
//             : MainAxisAlignment.start,
//         children: [
//           Container(
//             constraints: BoxConstraints(
//               maxWidth: MediaQuery.of(context).size.width * 0.7,
//             ),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: message.isMe ? Colors.blue[100] : Colors.grey[100],
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // 音频播放控制和信息
//                 InkWell(
//                   onTap: () => onAudioPlay(filePath, fileUrl, message),
//                   child: Row(
//                     children: [
//                       // 播放/暂停图标
//                       Icon(
//                         message.isPlaying
//                             ? Icons.pause_circle
//                             : Icons.play_circle,
//                         color: message.isMe ? Colors.blue : Colors.grey[700],
//                         size: 24,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               fileName,
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: message.isMe
//                                     ? Colors.blue[800]
//                                     : Colors.grey[800],
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               '$duration | $fileSize KB',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: message.isMe
//                                     ? Colors.blue[600]
//                                     : Colors.grey[600],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 // 状态文本（上传中、失败等）
//                 if (status != 'success')
//                   Padding(
//                     padding: const EdgeInsets.only(top: 8),
//                     child: Text(
//                       message.text,
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: status == 'failed'
//                             ? Colors.red
//                             : Colors.grey[600],
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _bubbleContent(BuildContext context) {
//     final isMe = message.isMe;
//     final bubbleColor = isMe ? const Color(0xFF3A70E2) : Colors.white;
//     final textColor = isMe ? Colors.white : Colors.black87;
//     const double maxWidth = 320;

//     // 图片消息处理（优先显示本地图片，没有则显示在线图片）
//     if (message.localImagePath != null || message.imageUrl != null) {
//       return Container(
//         width: 270,
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: bubbleColor,
//           borderRadius: _getBorderRadius(isMe),
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(10),
//           child: _buildImageWidget(), // 新增图片显示逻辑
//         ),
//       );
//     }

//     // 文本消息处理（保持不变）
//     return Column(
//       crossAxisAlignment: isMe
//           ? CrossAxisAlignment.end
//           : CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           constraints: BoxConstraints(maxWidth: maxWidth),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           decoration: BoxDecoration(
//             color: bubbleColor,
//             borderRadius: _getBorderRadius(isMe),
//             boxShadow: !isMe
//                 ? [
//                     const BoxShadow(
//                       color: Colors.black12,
//                       blurRadius: 2,
//                       spreadRadius: 0.5,
//                       offset: Offset(0, 1),
//                     ),
//                   ]
//                 : null,
//           ),
//           child: isMe
//               ? _buildUserMessage(textColor)
//               : _buildAIMessage(textColor),
//         ),
//         // 进度条和操作按钮（保持不变）
//         if (message.progress != null) _buildProgressIndicator(),
//         if (!message.isMe) _buildAIActions(message),
//         if (message.isMe) _buildUserActions(message),
//       ],
//     );
//   }

//   // 构建文件消息UI
//   Widget _buildFileMessage(BuildContext context) {
//     final fileInfo = message.fileInfo!;
//     final fileName = fileInfo['name'] ?? '未知文件';
//     final status = fileInfo['status'] ?? 'unknown';
//     final fileUrl = fileInfo['url'] ?? '';

//     // 根据状态选择图标
//     IconData fileIcon;
//     Color iconColor = Colors.grey;

//     switch (status) {
//       case 'uploading':
//         fileIcon = Icons.cloud_upload;
//         iconColor = Colors.blue;
//         break;
//       case 'success':
//         fileIcon = Icons.insert_drive_file;
//         iconColor = Colors.green;
//         break;
//       case 'failed':
//         fileIcon = Icons.error;
//         iconColor = Colors.red;
//         break;
//       default:
//         fileIcon = Icons.insert_drive_file;
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: Row(
//         mainAxisAlignment: message.isMe
//             ? MainAxisAlignment.end
//             : MainAxisAlignment.start,
//         children: [
//           Container(
//             constraints: BoxConstraints(
//               maxWidth: MediaQuery.of(context).size.width * 0.7,
//             ),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: message.isMe ? Colors.blue[100] : Colors.grey[100],
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // 文件图标和名称
//                 Row(
//                   children: [
//                     Icon(fileIcon, color: iconColor, size: 24),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         fileName,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w500,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 // 状态文本
//                 Text(
//                   message.text,
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: status == 'failed' ? Colors.red : Colors.grey[600],
//                   ),
//                 ),
//                 // 如果上传成功且有文件URL，显示下载/打开按钮
//                 if (status == 'success' && fileUrl.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 8),
//                     child: TextButton(
//                       onPressed: () => _openFile(context, fileUrl),
//                       style: TextButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 4,
//                         ),
//                         minimumSize: Size.zero,
//                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                       ),
//                       child: const Text(
//                         '打开文件',
//                         style: TextStyle(fontSize: 12, color: Colors.blue),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // 打开文件
//   void _openFile(BuildContext context, String url) async {
//     try {
//       if (await canLaunch(url)) {
//         await launch(url);
//       } else {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('无法打开文件: $url')));
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('打开文件失败: ${e.toString()}')));
//     }
//   }

//   // 新增：根据消息类型显示本地/网络图片
//   Widget _buildImageWidget() {
//     // 优先显示本地图片（上传过程中）
//     if (message.localImagePath != null) {
//       return Image.file(
//         File(message.localImagePath!),
//         fit: BoxFit.cover,
//         height: 200,
//         width: double.infinity,
//         errorBuilder: (context, error, stackTrace) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: const [
//                 Icon(Icons.error_outline, color: Colors.red),
//                 SizedBox(height: 8),
//                 Text('本地图片加载失败'),
//               ],
//             ),
//           );
//         },
//       );
//     }

//     // 显示网络图片（上传完成后或历史消息）
//     return Image.network(
//       message.imageUrl!,
//       fit: BoxFit.cover,
//       height: 200,
//       width: double.infinity,
//       loadingBuilder: (context, child, loadingProgress) {
//         if (loadingProgress == null) return child;
//         return Center(
//           child: CircularProgressIndicator(
//             value: loadingProgress.expectedTotalBytes != null
//                 ? loadingProgress.cumulativeBytesLoaded /
//                       (loadingProgress.expectedTotalBytes ?? 1)
//                 : null,
//           ),
//         );
//       },
//       errorBuilder: (context, error, stackTrace) {
//         return Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: const [
//               Icon(Icons.error_outline, color: Colors.red),
//               SizedBox(height: 8),
//               Text('图片加载失败'),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // 构建用户消息
//   Widget _buildUserMessage(Color textColor) {
//     return Text(
//       message.fullText,
//       style: TextStyle(
//         color: textColor,
//         fontSize: 15,
//         fontWeight: FontWeight.w400,
//       ),
//       softWrap: true,
//     );
//   }

//   // 构建AI消息
//   Widget _buildAIMessage(Color textColor) {
//     return SingleChildScrollView(
//       physics: const NeverScrollableScrollPhysics(),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           MarkdownBody(
//             data: message.fullText,
//             styleSheet: MarkdownStyleSheet(
//               p: TextStyle(
//                 color: textColor,
//                 fontSize: 15,
//                 fontWeight: FontWeight.w400,
//                 height: 1.5,
//               ),
//               h1: TextStyle(
//                 color: textColor,
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//               h2: TextStyle(
//                 color: textColor,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//               h3: TextStyle(
//                 color: textColor,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//               code: TextStyle(
//                 backgroundColor: Colors.grey[100],
//                 color: Colors.red,
//                 fontSize: 14,
//               ),
//               codeblockPadding: const EdgeInsets.all(8),
//               codeblockDecoration: BoxDecoration(
//                 color: Colors.grey[100],
//                 borderRadius: BorderRadius.circular(4),
//               ),
//             ),
//             onTapLink: (text, href, title) {
//               if (href != null) {
//                 _launchUrl(Uri.parse(href));
//               }
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   // 提取通用的边框半径设置
//   BorderRadius _getBorderRadius(bool isMe) {
//     return BorderRadius.only(
//       topLeft: const Radius.circular(18),
//       topRight: const Radius.circular(18),
//       bottomLeft: Radius.circular(isMe ? 18 : 4),
//       bottomRight: Radius.circular(isMe ? 4 : 18),
//     );
//   }

//   // 进度指示器
//   Widget _buildProgressIndicator() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 4),
//       child: Row(
//         children: [
//           Container(
//             width: 120,
//             height: 4,
//             decoration: BoxDecoration(
//               color: Colors.blue[100],
//               borderRadius: BorderRadius.circular(2),
//             ),
//             child: FractionallySizedBox(
//               alignment: Alignment.centerLeft,
//               widthFactor: message.progress,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF3A70E2),
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Text(
//             "${(message.progress! * 100).toInt()}%",
//             style: const TextStyle(color: Colors.black87, fontSize: 15),
//           ),
//         ],
//       ),
//     );
//   }

//   // 实现AI消息操作按钮（添加复制回调）
//   Widget _buildAIActions(ChatMessage message) {
//     // 注意添加message参数
//     return Padding(
//       padding: const EdgeInsets.only(top: 6),
//       child: Row(
//         children: [
//           _iconButton(
//             'assets/chat/stop.png',
//             onPressed: () =>
//                 _convertTextToSpeech(message.messageId!, message.fullText),
//           ),
//           const SizedBox(width: 15),
//           // 复制按钮添加点击事件
//           _iconButton(
//             'assets/chat/copy.png',
//             onPressed: () => _copyToClipboard(message.fullText),
//           ),
//           const SizedBox(width: 15),
//           _iconButton('assets/chat/update.png'),
//           const SizedBox(width: 15),
//           _iconButton('assets/chat/share.png'),
//         ],
//       ),
//     );
//   }

//   // 根据messageId获取消息内容并请求语音转换
//   Future<void> _convertTextToSpeech(String messageId, String fulltext) async {
//     await TokenManager().init();
//     final token = TokenManager().getToken();

//     debugPrint('id$messageId$fulltext');
//     final message = await http.post(
//       'chat/api_server/api/tts',
//       data: {"message_id": messageId, "text": fulltext},
//     );
//     // debugPrint('message$message');
//     // final audiopir = await http.get('voice/audio/stream/$messageId');
//     // debugPrint('message$audiopir');
//     final player = AudioPlayer();
//     final audioUrl =
//         "https://api.lengjing-ai.com/api/v1/voice/audio/stream/$messageId?token=$token";
//     await player.play(UrlSource(audioUrl));
//     // // debugPrint('messageid$messageid');
//   }

//   // 复制到剪贴板的实现方法
//   Future<void> _copyToClipboard(String text) async {
//     if (text.isEmpty) {
//       // _showToast('没有可复制的内容');
//       ToastUtil.showError('没有可复制的内容');
//       return;
//     }

//     try {
//       await FlutterClipboard.copy(text);
//       // _showToast('复制成功');
//       ToastUtil.showSuccess('复制成功');
//     } on PlatformException catch (e) {
//       ToastUtil.showError('复制失败');
//       print('复制失败: $e');
//     }
//   }

//   // 实现用户消息操作按钮（添加复制回调）
//   Widget _buildUserActions(ChatMessage message) {
//     // 注意添加message参数
//     return Padding(
//       padding: const EdgeInsets.only(top: 6),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           // 复制按钮添加点击事件
//           _iconButton(
//             'assets/chat/copy.png',
//             onPressed: () => _copyToClipboard(message.fullText),
//           ),
//           const SizedBox(width: 15),
//           _iconButton('assets/chat/share.png'),
//         ],
//       ),
//     );
//   }

//   // 链接打开
//   Future<void> _launchUrl(Uri url) async {
//     if (!await launchUrl(url)) {
//       throw Exception('Could not launch $url');
//     }
//   }

//   // 操作图标按钮
//   Widget _iconButton(String asset, {VoidCallback? onPressed}) {
//     return GestureDetector(
//       onTap: onPressed,
//       child: Container(
//         // 白色圆形背景
//         width: 25,
//         height: 25,
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           shape: BoxShape.rectangle, // 矩形形状
//           borderRadius: BorderRadius.all(Radius.circular(6)), // 圆角半径，可根据需要调整
//           // 可选：添加轻微阴影增强立体感
//           boxShadow: [
//             BoxShadow(color: Colors.black12, blurRadius: 1, spreadRadius: 0.5),
//           ],
//         ),
//         // 图标居中显示
//         child: Center(
//           child: Image.asset(
//             asset,
//             width: 15,
//             height: 15,
//             color: const Color(0xFF8E8E93),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // 底部功能图标组件
// class _BottomIcon extends StatelessWidget {
//   final String icon;
//   final String label;
//   final VoidCallback onTap;

//   const _BottomIcon({
//     required this.icon,
//     required this.label,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         children: [
//           CircleAvatar(
//             backgroundColor: Colors.white,
//             child: Image(image: AssetImage(icon)),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: const TextStyle(fontSize: 13, color: Colors.black54),
//           ),
//         ],
//       ),
//     );
//   }
// }
