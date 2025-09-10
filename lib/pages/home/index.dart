import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
// import 'package:audioplayers/audioplayers.dart';
import 'package:clipboard/clipboard.dart';
import 'package:demo1/components/image_viewer.dart';
import 'package:demo1/pages/login/login.dart';
import 'package:demo1/utils/audio.dart';
import 'package:demo1/utils/config.dart';
import 'package:demo1/utils/evntbus.dart';
import 'package:demo1/utils/http.dart';
import 'package:demo1/utils/httpd.dart';
import 'package:demo1/utils/recorder.dart';
import 'package:demo1/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../utils/token.dart';
import '../history/index.dart';
import '../setting/index.dart';
import '../../utils/toast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

// 聊天页面的主入口
class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

// 任务模型
// 更新后的Task类
class Task {
  final String name; // 任务名称
  final String status; // 任务状态（SUCCESS/其他）
  final String? detail; // 任务详情
  final String datetime; // 任务时间
  final String messageId; // 任务ID
  final double progress; // 进度（0-1）
  final List<TaskFile>? files; // 关联文件

  Task({
    required this.name,
    required this.status,
    this.detail,
    required this.datetime,
    required this.messageId,
    required this.progress,
    this.files,
  });
}

// 更新TaskFile类以匹配文件数据
class TaskFile {
  final String name; // 文件名
  final String size; // 文件大小
  final String type; // 文件类型
  final String createTime; // 创建时间

  TaskFile({
    required this.name,
    required this.size,
    required this.type,
    required this.createTime,
  });
}

// WebSocket管理类
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isReconnecting = false;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer; // 心跳定时器
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> connect() async {
    if (_isConnected) {
      await disconnect();
      return;
    }
    try {
      await TokenManager().init();
      final token = TokenManager().getToken() ?? '';
      _channel = WebSocketChannel.connect(
        Uri.parse(
          // 'ws://192.168.1.127:12111/api/v1/chat/api_server/api/ws?token=$token',
          ApiConfig.getWebSocketUrl(token),
        ),
      );

      _isConnected = true;
      print('WebSocket连接成功');
      // 若当前是重连状态，连接成功后重置状态
      if (_isReconnecting) {
        ToastUtil.showSuccess('WebSocket重连成功');
        _isReconnecting = false;
      }
      _startHeartbeat();
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
          _stopHeartbeat();
          _messageController.addError(error);
          _scheduleReconnect();
          // 若未在重连中且未连接，触发重连
          if (!_isReconnecting && !_isConnected) {
            _scheduleReconnect();
          }
        },
        onDone: () {
          print('WebSocket连接关闭');
          _isConnected = false;
          _stopHeartbeat(); // 连接关闭时停止心跳
          // 若未在重连中且未连接，触发重连
          if (!_isReconnecting && !_isConnected) {
            _scheduleReconnect();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('WebSocket连接失败: $e');
      _isConnected = false;
      _isReconnecting = false; // 连接失败时重置重连状态
      _scheduleReconnect();
      rethrow;
    }
  }

  // 启动心跳定时器，每10秒发送一次心跳包
  void _startHeartbeat() {
    // 先停止可能存在的旧定时器
    _stopHeartbeat();

    // 启动新的心跳定时器，延迟0秒执行第一次，之后每10秒执行一次
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _sendHeartbeat();
    });
  }

  // 发送心跳包
  void _sendHeartbeat() {
    if (!_isConnected || _channel == null) {
      print('WebSocket未连接，无法发送心跳');
      _stopHeartbeat();
      return;
    }

    try {
      final heartbeat = json.encode({"action": "heartbeat", "data": "PING"});
      _channel?.sink.add(heartbeat);
      print('发送心跳包成功');
    } catch (e) {
      print('发送心跳包失败: $e');
      _stopHeartbeat();
      // 心跳发送失败时触发重连
      if (_isConnected) {
        _scheduleReconnect();
      }
    }
  }

  // 停止心跳定时器
  void _stopHeartbeat() {
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  void _scheduleReconnect() {
    // 若已有重连定时器、正在重连或已连接，则不重复调度
    if (_reconnectTimer != null || _isReconnecting || _isConnected) return;

    _isReconnecting = true; // 标记为正在重连
    print('调度重连，5秒后尝试...');

    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      _reconnectTimer?.cancel(); // 清除定时器
      _reconnectTimer = null;

      try {
        await connect(); // 执行重连
      } catch (e) {
        print('重连失败: $e');
        _isReconnecting = false; // 重连失败，重置状态
        _scheduleReconnect(); // 继续调度下一次重连
      }
    });
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
    _stopHeartbeat(); // 断开连接时停止心跳
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  bool get isReconnecting => _isReconnecting;
  bool get isConnected => _isConnected;
}

// 聊天页面状态类 - 实现WidgetsBindingObserver以监听键盘状态
class _ChatPageState extends State<ChatPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final WebSocketManager _wsManager = WebSocketManager();

  final List<Task> _taskList = [];

  File? _selectedImage;

  // bool _isLoading = false; // 新增：控制加载状态的变量
  // 状态变量
  bool isRecording = false;
  bool _isReleasing = false;
  Timer? _recordTimer;
  int _recordingDuration = 0; // 录音时长（秒）
  // 新增：跟踪当前正在处理的message_id
  String? _currentProcessingMessageId;

  // 新增: 键盘状态和输入内容状态变量
  // bool _isKeyboardVisible = false; // 键盘是否可见
  bool _hasInputContent = false; // 输入框是否有内容

  // 用户信息
  Map userInfo = {"id": "", "avatar": null, "nickName": null};
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  // 聊天消息列表
  final List<ChatMessage> messages = [];
  // 临时消息索引（AI流式回复用）
  int? _tempAIMessageIndex;

  String? _firstMessageId; // 新增：存储第一次发送消息的message_id
  // 定义加载状态变量（在类中声明）
  bool _isLoading = false;

  // 控制器
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 功能状态
  bool showFunctions = false;
  bool isVoiceMode = false;

  // 首先在类中添加存储聊天历史的列表
  List<Map<String, dynamic>> _chatHistoryTasks = [];

  // 创建录音器实例
  final _recorderas = AudioRecorder();
  // 创建音频播放器实例
  final _player = AudioPlayer();
  // 存储录音文件路径
  String? _filePath;
  // 录音状态标志
  bool _isRecording = false;

  //用户userID
  String userId = '';

  //用户头像
  String avatar = '';
  bool _isMultiSelectMode = false; // 是否处于多选模式
  List<String> _selectedMessageIds = []; // 存储选中的消息ID

  Map<String, dynamic>? _knowledgeData; // 直接用Map存储数据，无需创建模型类

  // 消息监听订阅
  StreamSubscription? _messageSubscription;
  // 添加PageController控制页面滑动
  final PageController _pageController = PageController(
    initialPage: 1,
  ); // 是否是第一次下拉加载更多
  // 添加变量存储最早消息的ID，用于获取更早的历史
  String? _earliestMessageId;
  // 添加变量判断是否还有更多消息可加载
  bool _hasMoreMessages = true;

  // 流订阅对象，用于监听分享事件
  late StreamSubscription _intentSub;
  // 存储接收的共享文件路径列表
  List<String> _sharedFilePaths = [];

  bool _isPlaying = false; // 跟踪当前是否正在播放

  // 新增：标记是否正在检索知识库（根据实际业务逻辑控制）
  // bool _isRetrieving = true;

  double? _savedScrollOffset;
  // 当前活动的页面索引
  int _currentPageIndex = 1;

  // 新增：录音相关变量
  bool _isVoiceRecording = false;
  bool _isVoiceCancel = false;
  int _recordingSeconds = 0;
  Timer? _voiceTimer;
  String? _voiceFilePath;
  Offset? _startTouchOffset;

  // 新增: 记录是否有未完成的AI回复
  bool _hasPendingAIResponse = false;
  String? _pendingMessageId;

  final Set<String> _processingFileIdentifiers = {};

  @override
  bool get wantKeepAlive => true; // 保持页面状态不被销毁

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _getuserinfo();

    // 从本地加载历史消息
    _loadLocalHistoryMessages();

    // 添加页面切换监听器
    _pageController.addListener(() {
      // 保存当前页面索引
      final newPageIndex = _pageController.page?.round() ?? 1;
      if (_currentPageIndex != newPageIndex) {
        // 当页面切换前，保存主页面的滚动位置
        if (_currentPageIndex == 1) {
          _saveScrollPosition();
        }
        _currentPageIndex = newPageIndex;
      }
    });

    // 添加头像更新事件监听
    eventBus.on<AvatarUpdatedEvent>().listen((event) {
      setState(() {
        userInfo['avatar'] = event.avatarPath;
      });
    });

    _player;

    // 新增: 初始化时添加监听器
    WidgetsBinding.instance.addObserver(this);

    // 新增: 监听输入框内容变化
    _controller.addListener(_onInputChanged);

    // 初始化分享监听
    _setupShareListener();

    // 监听滚动事件，实时保存滚动位置
    _scrollController.addListener(() {
      if (_currentPageIndex == 1) {
        _saveScrollPosition();
      }
    });
    // 页面初始化完成后恢复滚动位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });

    //注册跳转到登录页的通知接受
    // eventBus.on<LogoutEvent>().listen((event) {
    //   Navigator.pushNamed(context, '/login');
    // });
    //注册跳转到登录页的通知接受 - 增强版
    _messageSubscription = eventBus.on<LogoutEvent>().listen((event) {
      // 确保在UI线程中执行导航
      if (mounted) {
        print('收到退出登录事件，准备跳转到登录页');
        // 清空分享相关状态变量
        _sharedFilePaths.clear();
        // _processingFileIdentifiers.clear();
        // 使用Future.delayed确保在当前事件循环结束后执行导航
        Future.delayed(Duration.zero, () {
          if (mounted) {
            // 清空所有路由栈并跳转到登录页
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (Route<dynamic> route) => false,
            );
          }
        });
      }
    });

    // 标记当前是否有未完成的AI回复（在应用启动时）
    _checkPendingResponses();
  }

  // 保存滚动位置的方法
  void _saveScrollPosition() {
    if (_scrollController.hasClients) {
      _savedScrollOffset = _scrollController.offset;
    }
  }

  // 恢复滚动位置的方法
  void _restoreScrollPosition() {
    if (_currentPageIndex == 1) {
      // 在下一帧中恢复滚动位置，确保列表已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollToBottom();
          // 确保滚动位置在有效范围内
          final maxOffset = _scrollController.position.maxScrollExtent;

          // 检查是否是从后台恢复的情况，或者消息列表发生了较大变化
          // 如果是这些情况，直接滚动到底部
          bool shouldScrollToBottom = false;

          // 检查当前是否有历史消息，如果有并且应用刚从后台恢复，应该滚动到底部
          if (messages.isNotEmpty && _hasPendingAIResponse) {
            shouldScrollToBottom = true;
          }

          // 如果保存的位置超出范围，或者需要直接滚动到底部
          if (_savedScrollOffset! > maxOffset || shouldScrollToBottom) {
            _scrollToBottom();
          } else {
            // 否则恢复到之前的位置
            _scrollController.jumpTo(_savedScrollOffset!);
          }
        }
      });
    } else if (_currentPageIndex == 1) {
      // 如果没有保存的滚动位置，直接滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    // 移除页面切换监听器
    _pageController.removeListener(() {});
    _messageSubscription?.cancel();
    _wsManager.disconnect();
    _controller.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _pageController.dispose();
    _player.dispose();
    _savedScrollOffset = _scrollController.offset;
    // 取消订阅，防止内存泄漏
    _intentSub.cancel();
    _sharedFilePaths.clear();
    // 保存滚动位置
    _saveScrollPosition();
    // 新增: 移除监听器
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // 新增: 处理应用生命周期变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('应用生命周期变化: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // 应用进入后台
        // 检查是否有未完成的AI回复
        _checkPendingResponses();
        _saveHistoryToLocal();
        break;

      case AppLifecycleState.resumed:
        // 应用返回前台
        // 确保WebSocket连接正常
        if (!_wsManager.isConnected && !_wsManager.isReconnecting) {
          print('应用返回前台，重新连接WebSocket...');
          _reconnectWebSocket();
        }

        // 如果有未完成的AI回复，检查是否需要重新获取
        if (_hasPendingAIResponse && _pendingMessageId != null) {
          print('检查未完成的AI回复: $_pendingMessageId');
          _checkAndResumeAIResponse(_pendingMessageId!);
        }

        // 应用从后台恢复，滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        break;

      case AppLifecycleState.inactive:
        // 应用处于非活动状态
        break;

      case AppLifecycleState.detached:
        // 应用即将退出
        break;

      default:
        break;
    }
  }

  @override
  void deactivate() {
    // 保存滚动位置
    _saveScrollPosition();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    // 页面重新可见时恢复滚动位置
    _restoreScrollPosition();
    // 额外确保滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _checkPendingResponses() {
    bool hasPending = messages.any((msg) => !msg.isMe && msg.isGenerating);
    if (hasPending) {
      _hasPendingAIResponse = true;
      // 获取第一个未完成的AI回复的messageId
      final pendingMsg = messages.firstWhere(
        (msg) => !msg.isMe && msg.isGenerating,
        orElse: () => ChatMessage(text: '', isMe: false),
      );
      _pendingMessageId = pendingMsg.messageId;
    }
  }

  Future<void> _reconnectWebSocket() async {
    try {
      await _wsManager.connect();
      // 重新建立消息监听
      if (_messageSubscription == null || _messageSubscription!.isPaused) {
        _messageSubscription?.cancel();
        _messageSubscription = _wsManager.messageStream.listen(
          (message) => _handleServerMessage(message),
          onError: (error) => ToastUtil.showError('正在连接.....'),
        );
      }
    } catch (e) {
      print('WebSocket重连失败: $e');
    }
  }

  void _checkAndResumeAIResponse(String messageId) {
    // 这里可以添加逻辑来检查服务器上该消息的状态
    // 或者简单地提示用户，让他们知道可能需要重新发送请求

    // 例如，检查是否有未完成的生成状态的消息
    final aiMsgIndex = messages.indexWhere(
      (m) => !m.isMe && m.messageId == messageId && m.isGenerating,
    );

    if (aiMsgIndex != -1) {
      // 提示用户AI回复可能已中断
      ToastUtil.showInfo('AI回复可能因应用在后台而中断，请尝试重新发送');

      // 重置生成状态，允许用户重新发送
      setState(() {
        messages[aiMsgIndex].isGenerating = false;
        _hasPendingAIResponse = false;
        _pendingMessageId = null;
      });
    }
  }

  // 设置分享监听
  void _setupShareListener() {
    bool _isProcessingShare = false;
    // 增加一个标志来跟踪是否正在处理从后台唤醒的分享
    bool _isProcessingInitialShare = false;

    // 1. 监听应用在前台时的实时分享
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        // 防止与初始分享同时处理
        if (_isProcessingShare || _isProcessingInitialShare) return;
        _isProcessingShare = true;
        ToastUtil.showInfo("收到实时分享文件: ${files.length}个");
        // 提取文件路径并更新UI
        final filePaths = files.map((file) => file.path ?? "未知路径").toList();

        // 检查是否已经处理过这些文件路径（避免重复）
        final newPaths = filePaths
            .where((path) => !_sharedFilePaths.contains(path))
            .toList();
        if (newPaths.isNotEmpty) {
          _handleSharedFiles(newPaths);
          // 将新处理的路径添加到已处理列表
          _sharedFilePaths.addAll(newPaths);
        }
        _isProcessingShare = false; // 处理完成后重置标志
      },
      onError: (err) {
        print("分享监听错误: $err");
        _isProcessingShare = false; // 发生错误时也要重置标志
      },
    );

    // 2. 获取应用从关闭状态被唤醒时的初始分享内容
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> files,
    ) {
      // 避免重复处理空列表或正在处理中的情况
      if (files.isEmpty || _isProcessingShare || _isProcessingInitialShare) {
        // 无论如何都要重置初始分享状态
        ReceiveSharingIntent.instance.reset();
        return;
      }

      _isProcessingInitialShare = true;
      final filePaths = files.map((file) => file.path ?? "未知路径").toList();

      if (filePaths.isNotEmpty) {
        // 检查是否已经处理过这些文件路径（避免重复）
        final newPaths = filePaths
            .where((path) => !_sharedFilePaths.contains(path))
            .toList();
        if (newPaths.isNotEmpty) {
          _handleSharedFiles(newPaths);
          // 将处理的路径添加到已处理列表
          _sharedFilePaths.addAll(newPaths);
        }
      }
      // 重置初始分享状态
      ReceiveSharingIntent.instance.reset();
      _isProcessingInitialShare = false; // 处理完成后重置标志
    });
  }

  // 新增: 加载更多消息的方法
  Future<void> _loadMoreMessages() async {
    // 检查是否有消息正在加载中（AI正在回复）
    bool isAISResponding = messages.any((msg) => msg.isMe && msg.loading);

    if (isAISResponding) {
      ToastUtil.showInfo('AI正在回复，请稍后再加载历史消息');
      return;
    }
    // 防止重复加载或没有更多消息时继续加载
    if (_isLoading || !_hasMoreMessages) return;
    final currentOffset = _scrollController.offset;
    final preLoadItemCount = messages.length;
    setState(() {
      _isLoading = true; // 标记为加载中
    });
    try {
      // 下拉时触发加载历史的方法
      await _lishixin();

      // 标记用户已下拉加载历史消息
      await StorageUtil.saveHasPulledDownHistory(true);
      // 等待列表渲染完成后再调整滚动位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final offset =
            _scrollController.position.maxScrollExtent -
            _scrollController.position.minScrollExtent;
        if (offset > 0) {
          _scrollController.jumpTo(offset);
        }

        if (_scrollController.hasClients) {
          // 计算新增加的消息数量
          final addedItemsCount = messages.length - preLoadItemCount;
          if (addedItemsCount > 0) {
            // 延迟计算以确保ListView已经更新了布局
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_scrollController.hasClients) {
                // 计算新增内容的高度
                final itemExtent =
                    _scrollController.position.extentTotal / messages.length;
                final addedHeight = addedItemsCount * itemExtent;

                // 设置新的滚动位置，保持用户浏览位置不变
                // 这样新加载的历史消息会出现在当前内容的上方
                final newOffset = currentOffset + addedHeight;
                _scrollController.jumpTo(newOffset);
                _savedScrollOffset = newOffset;
              }
            });
          }
        }
      });
    } catch (e) {
      print('下拉加载失败: $e');
      // 可添加错误提示，如ToastUtil.showError('加载失败，请重试')
    } finally {
      setState(() {
        _isLoading = false; // 加载完成/失败都重置状态
      });
    }
  }

  // 添加从本地加载历史消息的方法
  // 添加从本地加载历史消息的方法
  Future<void> _loadLocalHistoryMessages() async {
    try {
      // 检查用户是否已下拉加载过历史消息
      bool hasPulledDown = await StorageUtil.getHasPulledDownHistory();

      if (hasPulledDown) {
        // 如果用户已下拉过，删除本地消息
        print('用户已下拉过历史消息，清空本地消息重新自动加载历史');
        await StorageUtil.saveMessages([]); // 清空保存的完整消息

        // 自动调用下拉加载历史信息的方法，不需要用户手动下拉
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _loadMoreMessages();
          });
        });
        return;
      }

      // 优先尝试加载完整的消息列表
      final savedMessages = await StorageUtil.getMessages();
      final localEarliestMessageId = await StorageUtil.getEarliestMessageId();
      final pendingInfo = await StorageUtil.getPendingResponseInfo();

      if (savedMessages != null && savedMessages.isNotEmpty) {
        // 有保存的完整消息，直接加载到界面
        setState(() {
          // 清空现有消息
          messages.clear();

          // 转换回ChatMessage对象并添加
          for (var savedMsg in savedMessages) {
            messages.add(
              ChatMessage(
                text: savedMsg['text'] ?? '',
                isMe: savedMsg['isMe'] ?? false,
                progress: savedMsg['progress'] as double?,
                imageUrl: savedMsg['imageUrl'] as String?,
                localImagePath: savedMsg['localImagePath'] as String?,
                messageId: savedMsg['messageId'] as String?,
                fileInfo: savedMsg['fileInfo'] as Map<String, dynamic>?,
                loading: savedMsg['loading'] ?? false,
                isGenerating: savedMsg['isGenerating'] ?? false,
                timestamp: savedMsg['timestamp'] as String?,
              ),
            );
          }

          _earliestMessageId = localEarliestMessageId;

          // 恢复未完成的AI回复状态
          if (pendingInfo != null) {
            _hasPendingAIResponse = pendingInfo['hasPending'] ?? false;
            _pendingMessageId = pendingInfo['pendingMessageId'] as String?;
          }
        });

        print('成功加载保存的完整消息列表，共${savedMessages.length}条');

        // 加载完成后滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            _scrollToBottom();
          });
        });
      } else {
        // 如果没有保存的完整消息，再尝试加载历史消息数据
        final localHistory = await StorageUtil.getHistoryMessages();

        if (localHistory != null && localHistory.isNotEmpty) {
          // 有本地历史消息，加载到界面
          await _loadHistoryFromServer(localHistory, prepend: true);
          _earliestMessageId = localEarliestMessageId;
          print('成功加载本地历史消息');
        } else {
          // 没有本地历史消息，从服务器加载最新消息
          print('没有本地历史消息，将从服务器加载');
        }

        // 确保滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (messages.isNotEmpty) {
              _scrollToBottom();
            }
          });
        });
      }
    } catch (e) {
      print('加载本地历史消息失败: $e');

      // 出错时也尝试滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (messages.isNotEmpty) {
            _scrollToBottom();
          }
        });
      });
    }
  }

  // 添加保存历史消息到本地的方法
  Future<void> _saveHistoryToLocal() async {
    try {
      // 这里需要实现将当前messages列表转换为可存储的格式
      // 由于我们已经在_lishixin方法中保存了从服务器获取的原始数据
      // 这里可以再次保存最新的earliestMessageId
      await StorageUtil.saveEarliestMessageId(_earliestMessageId);
      print('应用进入后台，已保存最新的earliestMessageId');
    } catch (e) {
      print('保存历史消息失败: $e');
    }
  }

  Future<void> _lishixin() async {
    String baseUrl = 'chat/api_server/api/get_slide_history';
    Map<String, dynamic> requestData = {};
    if (_earliestMessageId != null) {
      baseUrl += '?message_id=${Uri.encodeComponent(_earliestMessageId!)}';
    }

    final fasr = await http.post(baseUrl); // 假设http.post返回Map
    print('返回信息内容 $fasr');

    if (fasr != null &&
        fasr['history_list'] != null &&
        fasr['history_list'] is List) {
      List<dynamic> historyList = fasr['history_list'] as List;

      if (historyList.isNotEmpty) {
        _earliestMessageId = historyList[0]['message_id']?.toString();
        // 等待历史消息加载完成（关键：确保顺序）
        await _loadHistoryFromServer(historyList, prepend: true);
        final localHistory = await StorageUtil.getHistoryMessages();
        List<dynamic> mergedHistory = [];
        if (localHistory != null && localHistory.isNotEmpty) {
          // 合并新消息和本地已有消息
          mergedHistory = [...historyList, ...localHistory];
        } else {
          // 如果本地没有历史消息，直接使用新消息
          mergedHistory = historyList;
        }
        // 保存合并后的历史消息到本地
        await StorageUtil.saveHistoryMessages(mergedHistory);
        await StorageUtil.saveEarliestMessageId(_earliestMessageId);
      } else {
        print('没有更多历史消息了');
        _hasMoreMessages = false;
      }
    } else {
      print('没有获取到历史消息数据');
    }
  }

  // 新增: 监听输入框内容变化
  void _onInputChanged() {
    final hasContent = _controller.text.trim().isNotEmpty;
    if (_hasInputContent != hasContent) {
      setState(() {
        _hasInputContent = hasContent;
      });
    }
  }

  // 在 _ChatPageState 类中添加停止AI回复的方法
  void _stopAIResponse(String messageId) {
    if (!_wsManager.isConnected) {
      print('WebSocket未连接，无法发送停止请求');
      ToastUtil.showError('连接已断开，无法停止回复');
      return;
    }

    try {
      final message = json.encode({
        "action": "stop",
        "data": {"message_id": messageId},
      });
      _wsManager._channel?.sink.add(message);
      print('停止请求发送成功: $messageId');
      ToastUtil.showSuccess('已停止AI回复');
      // 立即在本地查找并更新对应消息的isGenerating状态
      final int aiMsgIndex = messages.indexWhere(
        (m) => !m.isMe && m.messageId == messageId,
      );

      if (aiMsgIndex != -1) {
        setState(() {
          messages[aiMsgIndex].isGenerating = false;

          // 清除未完成的AI回复标记
          _hasPendingAIResponse = false;
          _pendingMessageId = null;
          // 同步更新左侧任务列表中对应任务的isRetrieving状态
          final int taskIndex = _chatHistoryTasks.indexWhere(
            (task) => task['message_id'] == messageId,
          );
          if (taskIndex != -1) {
            _chatHistoryTasks[taskIndex]['isRetrieving'] = false;
          }
        });
      }
    } catch (e) {
      print('停止请求发送失败: $e');
      ToastUtil.showError('停止回复失败');
    }
  }

  void _handleUpdateMessage() {
    // 查找用户最后发送的消息
    ChatMessage? lastUserMessage;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isMe) {
        // 用户发送的消息
        lastUserMessage = messages[i];
        break;
      }
    }

    if (lastUserMessage == null) {
      ToastUtil.showError('没有可重写的用户消息');
      return;
    }

    // // 创建一条新的用户消息（重发的消息）
    // final newUserMessage = ChatMessage(
    //   text: lastUserMessage.fullText,
    //   isMe: true,
    //   loading: true, // 标记为加载中
    // );

    // // 添加到消息列表
    // setState(() {
    //   messages.add(newUserMessage);
    // });

    // 直接发送消息，不预先添加到列表中
    final success = _wsManager.sendMessage(
      lastUserMessage.fullText,
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
      _showError('重发失败，请检查网络连接');
    }
  }

  // 新增: 监听应用生命周期和键盘状态变化
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    // 计算当前窗口的可见区域
    final window = WidgetsBinding.instance.window;
    final bottomInset = window.viewInsets.bottom;

    // 当底部内边距变化时，如果是键盘弹出且在主聊天页面，自动滚动到底部
    if (bottomInset > 0 && _currentPageIndex == 1) {
      // 延迟一小段时间确保输入框已经显示
      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollToBottom();
      });
    }
  }

  // 实现播放方法
  Future<void> _playTextToSpeech(String messageId, String fulltext) async {
    await TokenManager().init();
    final token = TokenManager().getToken();

    debugPrint('id$messageId$fulltext');
    final message = await http.post(
      'chat/api_server/api/tts',
      data: {"message_id": messageId, "text": fulltext},
    );

    final audioUrl =
        // "http://192.168.1.127:12111/api/v1/voice/audio/stream/$messageId?token=$token";
        ApiConfig.getAudioStreamUrl(messageId, token.toString());
    await _player?.play(UrlSource(audioUrl));
    setState(() {
      _isPlaying = true;
    });

    // 监听播放完成
    _player?.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  // 实现停止方法
  void _stopTextToSpeech() {
    _player?.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  //用户信息
  void _getuserinfo() async {
    final info = await http.get('/getUserInfo');
    setState(() {
      userId = info['data']['user']['userId'];
      userInfo['avatar'] = info['data']['user']['avatar'];
    });

    // print('用户信息: $userInfo');
  }

  // 生成分享链接的方法（定义在类内部）
  Future<void> _generateshareurl(messageId) async {
    // 检查userId是否已获取
    if (userId.isEmpty) {
      ToastUtil.showError('用户信息未加载完成');
      return;
    }
    // final token = await TokenManager().getToken();

    final response = await http.post(
      'chat/api_server/api/generate_share_url',
      data: {
        "user_id": userId, // 直接使用类中定义的userId变量
        "message_ids": [messageId],
      },
    );
    // 处理分享链接生成结果（例如显示成功提示或复制链接）
    final shareUrl = response['url'];
    if (shareUrl != null) {
      await FlutterClipboard.copy(shareUrl);
      ToastUtil.showSuccess('分享链接已复制到剪贴板');
    }
  }

  void _initWebSocket() async {
    try {
      await _wsManager.connect();
      _messageSubscription = _wsManager.messageStream.listen(
        (message) => _handleServerMessage(message),
        onError: (error) => ToastUtil.showError('正在连接.....'),
      );
    } catch (e) {
      _showError('WebSocket初始化失败: $e');
    }
  }

  // 处理服务器消息
  void _handleServerMessage(Map<String, dynamic> message) {
    print('收到服务器消息: $message');

    // 处理query_start：获取后端生成的message_id并关联到用户消息
    // if (message['action'] == 'query_start') {
    //   final String messageId = message['message_id'] ?? '';
    //   final String content = message['content'] ?? '';
    //   if (messageId.isEmpty) return;

    //   final List<Map<String, dynamic>> updatedChatTasks = List.from(
    //     _chatHistoryTasks,
    //   );

    //   updatedChatTasks.insert(0, {
    //     "message_id": messageId,
    //     "name": content,
    //     "datetime": DateTime.now().toString(), // 可添加当前时间
    //     "isRetrieving": false, // 新增：任务默认不在检索中
    //   });

    //   setState(() {
    //     _chatHistoryTasks = updatedChatTasks;
    //   });

    //   // 查找最后一条未关联messageId的用户消息（刚发送的那条）
    //   for (int i = messages.length - 1; i >= 0; i--) {
    //     final msg = messages[i];
    //     if (msg.isMe && msg.messageId == null) {
    //       setState(() {
    //         messages[i].messageId = messageId; // 关联后端返回的ID
    //         if (_firstMessageId == null) {
    //           _firstMessageId = messageId;
    //           print('第一次发送消息的message_id：$_firstMessageId');
    //         }
    //       });
    //       break;
    //     }
    //   }
    //   return;
    // }

    if (message['action'] == 'query_start') {
      final String messageId = message['message_id'] ?? '';
      final String content = message['content'] ?? '';
      print('处理query_start消息: messageId=$messageId, content=$content');

      if (messageId.isNotEmpty && content.isNotEmpty) {
        // 创建用户消息气泡
        setState(() {
          messages.add(
            ChatMessage(
              text: content,
              isMe: true,
              messageId: messageId,
              loading: true, // 添加加载状态，显示AI正在回复
            ),
          );
        });

        // 滚动到底部显示新消息
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        // 创建聊天历史任务项
        final List<Map<String, dynamic>> updatedChatTasks = List.from(
          _chatHistoryTasks,
        );

        updatedChatTasks.insert(0, {
          "message_id": messageId,
          "name": content,
          "datetime": DateTime.now().toString(),
          "isRetrieving": false,
        });

        setState(() {
          _chatHistoryTasks = updatedChatTasks;
        });

        // 记录第一次发送消息的ID
        if (_firstMessageId == null) {
          _firstMessageId = messageId;
          print('第一次发送消息的message_id：$_firstMessageId');
        }
      }
      return;
    }

    // 收到响应消息时关闭加载状态
    if (message['action'] == 'response' || message['action'] == 'system_info') {
      final String messageId = message['message_id'] ?? '';
      if (messageId.isNotEmpty) {
        // 查找对应的用户消息
        for (int i = 0; i < messages.length; i++) {
          final msg = messages[i];
          if (msg.isMe && msg.messageId == messageId) {
            setState(() {
              messages[i].loading = false;
            });
            break;
          }
        }
      }
    }
    if (message['action'] == 'system_info' && message['progress'] == 1) {
      // existing code...

      // 查找对应的AI消息并标记为生成完成
      final String messageId = message['message_id'] ?? '';
      final int aiMsgIndex = messages.indexWhere(
        (m) => !m.isMe && m.messageId == messageId,
      );

      if (aiMsgIndex != -1) {
        setState(() {
          messages[aiMsgIndex].isGenerating = false;
        });
      }
    }
    // 新增处理knowledge_info类型消息
    if (message['action'] == 'knowledge_info') {
      if (message['message'] is Map<String, dynamic>) {
        setState(() {
          _knowledgeData = message['message']; // 直接存储原始Map
        });
        // 提取export_time并更新最近的消息
        String? exportTime = message['message']['export_time'];
        if (exportTime != null && messages.isNotEmpty) {
          // 查找最近一条未设置时间戳的用户消息
          int recentUserMessageIndex = -1;
          for (int i = messages.length - 1; i >= 0; i--) {
            if (messages[i].isMe && messages[i].timestamp == null) {
              recentUserMessageIndex = i;
              break;
            }
          }

          if (recentUserMessageIndex != -1) {
            setState(() {
              messages[recentUserMessageIndex].timestamp = exportTime;
            });
          }
        }
      }
      return;
    }
    // {action: query_start, message_id: 689d403a0de3404f55b6b9ce, content: 您好}
    if (message['action'] == 'response') {
      // 处理正常响应消息（保持不变）
      final String segment = message['content'] ?? '';
      final String messageId = message['message_id'] ?? ''; // 提取message_id
      if (segment.isEmpty || messageId.isEmpty) return;
      // if (_tempAIMessageIndex != null &&
      //     _tempAIMessageIndex! < messages.length) {
      //   messages[_tempAIMessageIndex!].appendText(segment);
      //   setState(() {});
      // } else {
      //   final newMessage = ChatMessage(text: segment, isMe: false);
      //   setState(() {
      //     messages.add(newMessage);
      //     _tempAIMessageIndex = messages.length - 1;
      //   });
      // }

      // 查找对应的用户消息（持有相同messageId的用户消息）
      final int userMsgIndex = messages.indexWhere(
        (m) => m.isMe && m.messageId == messageId,
      );
      // 查找已存在的对应AI回复
      final int aiMsgIndex = messages.indexWhere(
        (m) => !m.isMe && m.messageId == messageId,
      );
      if (aiMsgIndex != -1) {
        // 追加到已存在的AI回复
        messages[aiMsgIndex].appendText(segment);
        // 保持生成状态为true
        messages[aiMsgIndex].isGenerating = true;
        setState(() {});
      } else {
        // 创建新的AI回复，关联相同的messageId
        final newAiMessage = ChatMessage(
          text: segment,
          isMe: false,
          messageId: messageId, // 绑定到用户消息的ID
          isGenerating: true, // 新消息设置为生成中
        );

        setState(() {
          // 修改：不再设置全局_isRetrieving，而是更新对应任务项
          int taskIndex = _chatHistoryTasks.indexWhere(
            (task) => task['message_id'] == messageId,
          );
          if (taskIndex != -1) {
            _chatHistoryTasks[taskIndex]['isRetrieving'] = true;
          }

          if (userMsgIndex != -1) {
            // 插入到对应用户消息的后面
            messages.insert(userMsgIndex + 1, newAiMessage);
          } else {
            // 找不到对应用户消息时添加到末尾（降级处理）
            messages.add(newAiMessage);
          }
        });
      }
      // 修复：只在用户在底部附近时才自动滚动到底部
      if (_scrollController.hasClients) {
        final currentOffset = _scrollController.offset;
        final maxOffset = _scrollController.position.maxScrollExtent;
        // 只有当用户在底部100像素范围内时，才自动滚动到底部
        if (maxOffset - currentOffset <= 100) {
          _scrollToBottom();
        }
      }
      _hasPendingAIResponse = true;
      _pendingMessageId = messageId;
      return;

      // // 情况1：当前没有正在处理的消息，或收到新的message_id
      // if (_currentProcessingMessageId == null ||
      //     _currentProcessingMessageId != messageId) {
      //   // 创建新消息，绑定messageId
      //   final newMessage = ChatMessage(
      //     text: segment,
      //     isMe: false,
      //     messageId: messageId, // 关联ID
      //   );
      //   setState(() {
      //     messages.add(newMessage);
      //     _tempAIMessageIndex = messages.length - 1;
      //     _currentProcessingMessageId = messageId; // 更新当前处理的ID
      //   });
      // }
      // // 情况2：同一个message_id的分块内容，继续追加
      // else if (_tempAIMessageIndex != null &&
      //     _tempAIMessageIndex! < messages.length) {
      //   messages[_tempAIMessageIndex!].appendText(segment);
      //   setState(() {});
      // }

      // _scrollToBottom();
      // return;
    }
    if (message['action'] == 'response_end') {
      // 假设存在这个结束标记
      final String messageId = message['message_id'] ?? '';
      if (messageId.isEmpty) return;

      final int aiMsgIndex = messages.indexWhere(
        (m) => !m.isMe && m.messageId == messageId,
      );

      if (aiMsgIndex != -1) {
        setState(() {
          // 修改：不再设置全局_isRetrieving，而是更新对应任务项
          int taskIndex = _chatHistoryTasks.indexWhere(
            (task) => task['message_id'] == messageId,
          );
          if (taskIndex != -1) {
            _chatHistoryTasks[taskIndex]['isRetrieving'] = false;
          }

          if (aiMsgIndex != -1) {
            messages[aiMsgIndex].isGenerating = false;
          }
        });
      }
      // 清除未完成的AI回复标记
      _hasPendingAIResponse = false;
      _pendingMessageId = null;
      return;
    }

    if (message['action'] == 'task_data') {
      final List<dynamic>? taskDataList = message['task_data'];
      if (taskDataList != null) {
        _parseAndUpdateTasks(taskDataList);
      }
      return;
    }
    if (message['action'] == 'system_info') {
      // 提取消息中的关键信息
      final String messageId = message['message_id'] ?? '';
      final String status = message['status'] ?? '';
      final double progress = message['progress'] ?? 0.0;
      final String info = message['content'] ?? '';
      final List<dynamic>? filesData = message['value'];
      final String theme = message['theme'] ?? ''; // 提取主题信息

      // 对于进度为0的初始消息，特殊处理确保100%出现且只出现一次

      bool isDuplicateTask = false;
      if (_taskList.isNotEmpty) {
        // 检查是否有相同文件名和进度的任务
        if (filesData != null && filesData.isNotEmpty) {
          String fileName = '';
          if (filesData[0] is Map<String, dynamic>) {
            fileName = filesData[0]['filename'] ?? '';
          }

          if (fileName.isNotEmpty) {
            isDuplicateTask = _taskList.any(
              (task) =>
                  task.detail?.contains(fileName) == true &&
                  task.progress == progress,
            );
          }
        }
      }

      // 如果是重复任务，直接返回，不进行处理
      if (isDuplicateTask) {
        print('检测到重复任务，忽略处理');
        return;
      }
      // if (progress == 0.0) {
      //   final newMessage = ChatMessage(
      //     text: info,
      //     isMe: false,
      //     messageId: messageId,
      //     // timestamp: getCurrentFormattedTimestamp(),?
      //   );
      //   setState(() {
      //     messages.add(newMessage);
      //     _tempAIMessageIndex = messages.length - 1;
      //   });
      //   _scrollToBottom();
      // }

      // 解析文件列表
      final List<TaskFile> taskFiles = [];
      if (filesData != null) {
        for (var file in filesData) {
          if (file is Map<String, dynamic>) {
            taskFiles.add(
              TaskFile(
                name: file['filename'] ?? '未知文件',
                size: file['size_readable'] ?? '0B',
                type: file['media_type'] ?? 'file',
                createTime: file['create_time'] ?? '',
              ),
            );
          }
        }
      }

      // 处理状态文本
      String statusText;
      switch (status.toUpperCase()) {
        case 'SUCCESS':
          statusText = '已完成';
          break;
        case 'PENDING':
          statusText = '已接受';
          break;
        case 'STARTED':
          statusText = '处理中';
          break;
        default:
          statusText = '失败';
      }

      // 任务名称优先使用theme字段，如果没有则使用默认名称
      String taskName = theme.isNotEmpty ? theme : '文件处理';
      if (taskName.isEmpty && filesData != null && filesData.isNotEmpty) {
        final firstFile = filesData[0];
        if (firstFile is Map<String, dynamic>) {
          taskName = firstFile['filename'] ?? '';
        }
      }
      // 如果还是为空，尝试使用content
      if (taskName.isEmpty) {
        taskName = info.isNotEmpty ? info : '文件处理';
      }

      // 检查是否已存在相同messageId的任务
      int existingTaskIndex = -1;
      if (messageId.isNotEmpty) {
        existingTaskIndex = _taskList.indexWhere(
          (task) => task.messageId == messageId,
        );
      }

      if (existingTaskIndex != -1) {
        // 更新现有任务
        setState(() {
          if (progress == 0.5) {
            // 检查是否已经为该messageId创建过初始消息
            bool hasInitialMessage = messages.any(
              (msg) => !msg.isMe && msg.messageId == messageId,
            );

            if (!hasInitialMessage) {
              final newMessage = ChatMessage(
                text: info,
                isMe: false,
                messageId: messageId,
                // timestamp: getCurrentFormattedTimestamp(),
              );
              setState(() {
                messages.add(newMessage);
                _tempAIMessageIndex = messages.length - 1;
              });
              // _scrollToBottom();
            }
          }
          _taskList[existingTaskIndex] = Task(
            name: taskName,
            status: statusText,
            detail: info,
            datetime: _taskList[existingTaskIndex].datetime, // 保留原创建时间
            messageId: messageId,
            progress: progress,
            files: taskFiles.isNotEmpty
                ? taskFiles
                : _taskList[existingTaskIndex].files,
          );
        });
      } else {
        // 创建新任务
        final newTask = Task(
          name: taskName,
          status: statusText,
          detail: info,
          datetime: DateTime.now().toString(),
          messageId: messageId,
          progress: progress,
          files: taskFiles.isNotEmpty ? taskFiles : null,
        );

        setState(() {
          _taskList.add(newTask);
        });
      }
      // 无论进度如何，都返回不再继续处理
      return;
    }
    if (message['action'] == 'history_data') {
      // 处理历史消息数据
      final List<dynamic>? history = message['history_data'];
      if (history != null) {
        _loadHistoryFromServer(history);
      }
    } else {
      print('未处理的消息类型: ${message['action']}');
    }
  }

  //原来文件返回信息
  // else if (message['action'] == 'system_info') {
  //     if (message['progress'] == 1) {
  //       final String info = message['content'] ?? '';
  //       // 提取;号后面的文字
  //       String contentAfterSemicolon = info; // 默认使用原始内容

  //       // 检查是否包含;号
  //       if (info.contains('；')) {
  //         // 分割字符串并获取;号后面的部分
  //         List<String> parts = info.split('；');
  //         if (parts.length > 1) {
  //           // 拼接所有;号后面的内容（处理多个;的情况）
  //           contentAfterSemicolon = parts.sublist(1).join('；').trim();
  //         }
  //       }
  //       final newMessage = ChatMessage(
  //         text: contentAfterSemicolon,
  //         isMe: false,
  //       );
  //       setState(() {
  //         messages.add(newMessage);
  //         _tempAIMessageIndex = messages.length - 1;
  //       });
  //       _scrollToBottom();
  //     }
  //   }

  // 新增：解析任务数据并更新列表
  void _parseAndUpdateTasks(List<dynamic> taskDataList) {
    final List<Task> newTasks = [];

    for (var item in taskDataList) {
      if (item is Map<String, dynamic>) {
        // 解析文件列表
        final List<dynamic>? filesData = item['value'];
        final List<TaskFile> taskFiles = [];
        if (filesData != null) {
          for (var file in filesData) {
            if (file is Map<String, dynamic>) {
              taskFiles.add(
                TaskFile(
                  name: file['filename'] ?? '未知文件',
                  size: file['size_readable'] ?? '0B',
                  type: file['media_type'] ?? 'file',
                  createTime: file['create_time'] ?? '',
                ),
              );
            }
          }
        }
        String statusText;
        String status = item['status'] ?? '';
        switch (status.toUpperCase()) {
          case 'SUCCESS':
            statusText = '已完成';
            break;
          case 'FAILURE':
            statusText = '失败';
            break;
          default:
            statusText = '处理中'; // 默认或其他状态都显示为待处理
        }

        // 获取任务名称，确保不为空
        String taskName = item['content'] ?? '';
        // 如果content为空，尝试从files中获取文件名
        if (taskName.isEmpty && filesData != null && filesData.isNotEmpty) {
          final firstFile = filesData[0];
          if (firstFile is Map<String, dynamic>) {
            taskName = firstFile['filename'] ?? '';
          }
        }
        // 如果还是为空，使用默认名称
        if (taskName.isEmpty) {
          taskName = '未命名任务';
        }

        // 创建Task对象
        newTasks.add(
          Task(
            name: taskName,
            status: statusText,
            detail: item['content'] ?? '', // 可根据需要截取详情
            datetime: item['datetime'] ?? '',
            messageId: item['message_id'] ?? '',
            progress: (item['progress'] as num?)?.toDouble() ?? 0,
            files: taskFiles.isNotEmpty ? taskFiles : null,
          ),
        );
      }
    }

    // 更新任务列表
    setState(() {
      _taskList.clear();
      _taskList.addAll(newTasks);
    });
  }

  // 从服务器加载历史消息并筛选不同类型
  Future<void> _loadHistoryFromServer(
    List<dynamic> historyList, {
    bool prepend = false,
  }) async {
    final List<ChatMessage> newMessages = [];
    final List<Map<String, dynamic>> newChatTasks = [];

    // 异步遍历，逐个处理item，确保顺序
    for (var item in historyList) {
      if (item is Map<String, dynamic>) {
        final String action = item['action'] ?? '';
        final String datetime = item['datetime'] ?? '未知时间';
        final String messageId = item['message_id'] ?? '';

        // 添加检查：如果消息ID已存在，则跳过此消息
        bool messageExists = messages.any((msg) => msg.messageId == messageId);
        if (messageExists) {
          print('消息ID $messageId 已存在，跳过添加');
          continue;
        }

        if (action == 'process_files') {
          // 等待文件消息处理完成，再添加到列表（保证顺序）
          final fileMessages = await _handleProcessFilesHistory(
            item,
            datetime,
            messageId,
          );
          newMessages.addAll(fileMessages);
        } else if (action == 'chat') {
          // 同步处理chat消息，直接添加到列表
          final List<ChatMessage> chatMessages = [];
          final String query = item['query'] ?? '';
          if (query.isNotEmpty) {
            chatMessages.add(
              ChatMessage(
                text: query,
                isMe: true,
                messageId: messageId,
                timestamp: datetime,
              ),
            );
          }
          final String response = item['response'] ?? '';
          if (response.isNotEmpty) {
            chatMessages.add(
              ChatMessage(
                text: response,
                isMe: false,
                messageId: messageId,
                timestamp: datetime,
              ),
            );
          }
          newMessages.addAll(chatMessages);

          // 构建聊天历史任务项
          newChatTasks.add({
            'name': query.isNotEmpty ? query : '系统回复',
            'messageId': messageId,
            'datetime': datetime,
            'children': [],
            'isRetrieving': false, // 新增：历史任务默认不在检索中
          });
        }
      }
    }

    // 所有消息按原始顺序收集完成后，一次性更新状态
    setState(() {
      if (prepend) {
        messages.insertAll(0, newMessages); // 历史消息添加到前面
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   if (_scrollController.hasClients) {
        //     _scrollController.jumpTo(
        //       _scrollController.position.maxScrollExtent,
        //     );
        //   }
        // });
      } else {
        messages.clear();
        messages.addAll(newMessages); // 初始加载
      }
      // 更新聊天历史任务列表
      if (prepend) {
        _chatHistoryTasks = [...newChatTasks.reversed, ..._chatHistoryTasks];
      } else {
        _chatHistoryTasks = newChatTasks.reversed.toList();
      }
    });

    // 只有在初始加载时滚动到底部，加载历史消息时不滚动
    if (!prepend && messages.isNotEmpty) {
      // 延迟滚动，确保UI已经更新
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  // 处理文件处理类型的历史记录
  Future<List<ChatMessage>> _handleProcessFilesHistory(
    Map<String, dynamic> item,
    String datetime,
    String messageId,
  ) async {
    final List<ChatMessage> fileMessages = [];

    // 1. 先添加系统提示消息（保持顺序）

    // 2. 处理文件列表（异步获取URL，但消息顺序已在列表中固定）
    final List<dynamic> files = item['files'] ?? [];
    for (var file in files) {
      if (file is Map<String, dynamic>) {
        String filename = file['filename'] ?? '未知文件';
        String filetype = file['media_type'] ?? 'file';
        // 获取文件在线地址（异步操作）
        var fileUrlResp = await http.post(
          'chat/api_server/api/get_file_path',
          data: {"filetype": filetype, "filename": filename},
        );
        String fileUrl = fileUrlResp ?? '';

        bool isImage = filetype.startsWith('image/');
        if (isImage) {
          fileMessages.add(
            ChatMessage(
              imageUrl: fileUrl,
              isMe: true,
              messageId: messageId,
              timestamp: datetime,
            ),
          );
        } else {
          fileMessages.add(
            ChatMessage(
              isMe: true,
              messageId: messageId,
              timestamp: datetime,
              fileInfo: {
                'name': filename,
                'path': fileUrl,
                'status': 'success',
                'type': filetype,
                'size': file['size_readable'] ?? '',
                'url': fileUrl,
              },
              text: filename,
            ),
          );
        }
      }
    }

    String content = '[${datetime}] 上传了文件: ';
    final String response = item['action_response'] ?? '';
    String contentAfterSemicolon = response;
    if (response.contains('；')) {
      List<String> parts = response.split('；');
      if (parts.length > 1) {
        contentAfterSemicolon = parts.sublist(1).join('；').trim();
      }
    }
    if (response.isNotEmpty) {
      content += contentAfterSemicolon;
    }
    // fileMessages.add(
    //   ChatMessage(text: content, isMe: false, messageId: messageId),
    // );

    return fileMessages; // 返回收集的消息列表
  }

  // 处理聊天类型的历史记录
  void _handleChatHistory(Map<String, dynamic> item) {
    // 用户发送的查询
    final String query = item['query'] ?? '';
    final String messageId = item['message_id'] ?? '';
    if (query.isNotEmpty) {
      messages.add(ChatMessage(text: query, isMe: true, messageId: messageId));
    }

    // AI的回复
    final String response = item['response'] ?? '';
    if (response.isNotEmpty) {
      messages.add(
        ChatMessage(text: response, isMe: false, messageId: messageId),
      );
    }
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
    FocusScope.of(context).unfocus();

    // 先添加用户消息到列表（此时messageId为null，等待后端返回）
    // final userMessage = ChatMessage(text: text, isMe: true, loading: true);
    // setState(() {
    //   messages.add(userMessage);
    //   // _isLoading = true;
    // });

    _controller.clear();
    // _scrollToBottom();

    // _tempAIMessageIndex = null; // 清除AI临时消息索引
    // // _addMessage(text, isMe: true); // 添加用户消息
    // _controller.clear();
    // // 发送消息前设置加载状态为true
    // setState(() {
    //   messages.add(userMessage);
    //   _isLoading = true;
    //   _scrollToBottom();
    // });
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
      // 发送失败时也需要关闭加载状态
      // setState(() {
      //   messages.remove(userMessage); // 发送失败移除临时消息
      //   // _isLoading = false;
      // });
    }
  }

  // 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 检查是否已经在底部附近，避免不必要的滚动
        final currentOffset = _scrollController.offset;
        final maxOffset = _scrollController.position.maxScrollExtent;

        // 如果距离底部超过50像素，才执行滚动
        if (maxOffset - currentOffset > 50) {
          _scrollController.animateTo(
            maxOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          // 距离底部较近时，直接跳到最底部
          _scrollController.jumpTo(maxOffset);
        }
        // 同时更新保存的滚动位置
        _savedScrollOffset = maxOffset;
      });
    }
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

  //开始播放
  Future<void> _toggle(StateSetter setState) async {
    if (await Permission.microphone.request().isDenied) return;

    if (_isRecording) {
      final path = await _recorderas.stop();
      setState(() {
        _filePath = path;
        _isRecording = false;
      });
    } else {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorderas.start(
        RecordConfig(encoder: AudioEncoder.opus, sampleRate: 16000),
        path: path,
      );
      setState(() => _isRecording = true);
      debugPrint('录音成功$path');
    }
  }

  // 播放录音的方法
  Future<void> _play() async {
    // 如果存在录音文件路径，则播放录音
    if (_filePath != null) {
      await _player.play(DeviceFileSource(_filePath!));
    }
  }

  //发送录音文件到聊天服务器
  Future<void> _sendAudioMessage() async {
    if (_filePath == null) {
      _showToast('没有录音文件可发送');
      return;
    }

    // 关闭录音弹窗
    Navigator.of(context).pop();

    // 获取录音文件信息
    final file = File(_filePath!);
    if (!await file.exists()) {
      _showToast('录音文件不存在');
      return;
    }

    // 获取文件大小
    final fileSizeInBytes = await file.length();
    final fileSizeInKB = (fileSizeInBytes / 1024).round();

    // 获取录音时长（需要添加audio_session依赖来获取时长）
    // 简化处理：这里不实际获取时长，仅作为示例
    final duration = "未知时长";

    // 在聊天列表中添加临时消息
    int messageIndex = -1;
    setState(() {
      messages.add(
        ChatMessage(
          isMe: true,
          text: '正在发送录音...',
          fileInfo: {
            'name': path.basename(_filePath!),
            'path': _filePath!,
            'status': 'uploading',
            'type': 'audio',
            'duration': duration,
            'size': fileSizeInKB,
          },
        ),
      );
      messageIndex = messages.length - 1;
    });
    _scrollToBottom();

    try {
      // 1. 请求上传URL
      final fileName = path.basename(_filePath!);
      final uploadUrlResponse = await http.post(
        'file/uploadUrl',
        data: {
          "files": [
            {"contentType": 'audio/m4a', "fileName": fileName},
          ],
        },
      );

      if (uploadUrlResponse['code'] != 200 ||
          !(uploadUrlResponse['data'] is List) ||
          uploadUrlResponse['data'].isEmpty) {
        _updateFileMessageStatus(messageIndex, 'failed', '获取上传地址失败');
        return;
      }

      // 提取上传URL
      final uploadUrl = uploadUrlResponse['data'][0]['url'] ?? '';
      if (uploadUrl.isEmpty) {
        _updateFileMessageStatus(messageIndex, 'failed', '上传地址无效');
        return;
      }

      // 2. 上传录音文件
      final dio = Dio();
      final response = await dio.put(
        uploadUrl,
        data: await file.readAsBytes(),
        options: Options(
          contentType: 'audio/m4a',
          headers: {'Content-Length': fileSizeInBytes.toString()},
        ),
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).round();
          _updateFileMessageStatus(
            messageIndex,
            'uploading',
            '正在上传: $progress%',
          );
        },
      );

      if (response.statusCode == 200) {
        // 3. 通知服务器文件已上传
        await http.post(
          'chat/api_server/api/upload_file_remind',
          data: {
            "files": [
              {
                "file_type": 'audio/m4a',
                "filename": fileName,
                "size_readable": fileSizeInKB,
              },
            ],
          },
        );

        // 获取文件在线访问路径
        final fileUrlResponse = await http.post(
          'chat/api_server/api/get_file_path',
          data: {"filetype": 'audio/m4a', "filename": fileName},
        );

        // 更新消息为上传成功状态
        _updateFileMessageStatus(
          messageIndex,
          'success',
          '录音发送成功',
          fileUrl: fileUrlResponse ?? '',
        );

        _showToast('录音发送成功');

        // 清空录音文件路径，准备下次录音
        setState(() {
          _filePath = null;
        });
      } else {
        _updateFileMessageStatus(
          messageIndex,
          'failed',
          '上传失败，状态码: ${response.statusCode}',
        );
      }
    } catch (e) {
      _updateFileMessageStatus(messageIndex, 'failed', '上传异常: ${e.toString()}');
      print('录音上传异常: $e');
    }
  }

  // 发送图片消息
  void _sendImageMessage(String imagePath) async {
    int messageIndex;
    setState(() {
      messages.add(
        ChatMessage(
          isMe: true,
          localImagePath: imagePath, // 先显示本地图片
          text: '上传中...', // 显示上传状态
        ),
      );
      messageIndex = messages.length - 1; // 保存当前消息索引
    });
    _scrollToBottom();

    String fileName = path.basename(imagePath);
    //获取图片文件
    File imageFile = File(imagePath);
    //获取文件大小（大小）
    int fileSizeInBytes = await imageFile.length();
    //转kb
    int fileSizeInKBInt = (fileSizeInBytes / 1024).round();

    final mimeType = await _getMimeType(fileName);
    final res = await http.post(
      'file/uploadUrl',
      data: {
        "files": [
          {"contentType": mimeType, "fileName": fileName},
        ],
      },
    );

    if (res['code'] == 200) {
      if (res['data'] is List && res['data'].isNotEmpty) {
        //提取临时的上传链接
        String imageUrl = res['data'][0]['url'] ?? '';
        if (imageUrl.isNotEmpty) {
          debugPrint('临时连接$imageUrl');
          try {
            // 读取图片文件
            File imageFile = File(imagePath);
            List<int> imageBytes = await imageFile.readAsBytes();

            // 创建Dio实例并配置
            Dio dio = Dio();
            Response response = await dio.put(
              imageUrl,
              data: imageBytes,
              options: Options(
                contentType: mimeType, // 设置正确的内容类型
                headers: {
                  'Content-Length': imageBytes.length.toString(), // 设置内容长度
                },
              ),
            );
            // 检查上传结果
            if (response.statusCode == 200) {
              debugPrint('图片上传成功');
              // debugPrint('上传结果$res');
              final age = await http.post(
                'chat/api_server/api/upload_file_remind',
                data: {
                  "files": [
                    {
                      "file_type": mimeType,
                      "filename": fileName,
                      "size_readable": fileSizeInKBInt,
                    },
                  ],
                },
              );
              final ages = await http.post(
                'chat/api_server/api/get_file_path',
                data: {"filetype": mimeType, "filename": fileName},
              );
              String onlineImageUrl = ages ?? '';
              debugPrint('返回浏览结果$ages');
              debugPrint('通知ws$age');
              setState(() {
                // messages.add(ChatMessage(isMe: true, imageUrl: ages));
              });
              _scrollToBottom();
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
  }

  //获取当前时间
  String getCurrentFormattedTimestamp() {
    // 获取当前时间
    DateTime now = DateTime.now();

    // 格式化时间为指定格式：yyyy-MM-dd HH:mm:ss
    String year = now.year.toString();
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');
    String hour = now.hour.toString().padLeft(2, '0');
    String minute = now.minute.toString().padLeft(2, '0');
    String second = now.second.toString().padLeft(2, '0');

    // 拼接成指定格式
    return '$year-$month-$day $hour:$minute:$second';
  }

  // 拍照功能处理
  void _handleCameraTap() async {
    var status = await Permission.camera.status;
    setState(() => showFunctions = false);

    // 检查相机权限
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        _showError('需要相机权限才能使用相机功能');
        return;
      }
    }

    // 对于视频，还需要存储权限
    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }

    try {
      // 显示选择对话框：拍照或录像
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('拍照'),
                onTap: () async {
                  Navigator.pop(context);
                  await _takePhoto();
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam),
                title: Text('录制视频'),
                onTap: () async {
                  Navigator.pop(context);
                  await _recordVideo();
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showError('相机功能出错: $e');
      print('相机异常: $e');
    } finally {
      setState(() => showFunctions = true);
    }
    // var status = await Permission.camera.status;
    // setState(() => showFunctions = false);
    // if (!status.isGranted) {
    //   status = await Permission.camera.request();
    //   if (!status.isGranted) {
    //     _showError('需要相机权限才能使用拍照功能');
    //     return;
    //   }
    // }

    // try {
    //   final picker = ImagePicker();
    //   final pickedFile = await picker.pickImage(
    //     source: ImageSource.camera,
    //     imageQuality: 80,
    //     maxWidth: 800,
    //   );

    //   if (pickedFile != null) {
    //     _sendImageMessage(pickedFile.path);
    //     showFunctions = true;
    //   } else {
    //     _showToast('未选择图片');
    //   }
    // } catch (e) {
    //   _showError('拍照失败: $e');
    //   print('拍照异常: $e');
    // }
  }

  // 拍照功能
  Future<void> _takePhoto() async {
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
  }

  // 录制视频功能
  Future<void> _recordVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: Duration(seconds: 30), // 限制最长录制时间
    );

    if (pickedFile != null) {
      _sendVideoMessage(pickedFile.path); // 需要实现视频发送方法
    } else {
      _showToast('未录制视频');
    }
  }

  // 需要新增视频发送方法
  void _sendVideoMessage(String videoPath) async {
    // 实现视频消息发送逻辑
    // 类似图片发送，但需要处理视频文件
    // 获取文件MIME类型
    // 获取选择的文件路径
    final filePath = videoPath;
    if (filePath == null || filePath.isEmpty) {
      _showToast('文件路径无效');
      return;
    }

    // 2. 在聊天列表中添加一个临时消息，显示上传状态
    int? messageIndex;
    final fileName = path.basename(filePath);
    setState(() {
      messages.add(
        ChatMessage(
          isMe: true,
          text: '正在上传文件: $fileName',
          fileInfo: {'name': fileName, 'path': filePath, 'status': 'uploading'},
        ),
      );
      messageIndex = messages.length - 1;
    });
    _scrollToBottom();

    // 3. 获取文件信息并上传
    final file = File(filePath);
    if (!await file.exists()) {
      _updateFileMessageStatus(messageIndex!, 'failed', '文件不存在');
      return;
    }

    // 获取文件大小
    final fileSizeInBytes = await file.length();
    final fileSizeInKB = (fileSizeInBytes / 1024).round();

    // 获取文件MIME类型
    final mimeType = await _getMimeType(filePath);

    // 4. 先请求上传URL（与现有图片上传逻辑类似）
    final uploadUrlResponse = await http.post(
      'file/uploadUrl',
      data: {
        "files": [
          {
            "contentType": mimeType ?? 'application/octet-stream',
            "fileName": fileName,
          },
        ],
      },
    );

    if (uploadUrlResponse['code'] != 200 ||
        !(uploadUrlResponse['data'] is List) ||
        uploadUrlResponse['data'].isEmpty) {
      _updateFileMessageStatus(messageIndex!, 'failed', '获取上传地址失败');
      return;
    }

    // 提取上传URL
    final uploadUrl = uploadUrlResponse['data'][0]['url'] ?? '';
    if (uploadUrl.isEmpty) {
      _updateFileMessageStatus(messageIndex!, 'failed', '上传地址无效');
      return;
    }

    // 5. 上传文件到获取的URL
    try {
      final dio = Dio();
      final response = await dio.put(
        uploadUrl,
        data: await file.readAsBytes(),
        options: Options(
          contentType: mimeType ?? 'application/octet-stream',
          headers: {'Content-Length': fileSizeInBytes.toString()},
        ),
        // 可以添加上传进度监听
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).round();
          _updateFileMessageStatus(
            messageIndex!,
            'uploading',
            '正在上传: $progress%',
          );
        },
      );

      if (response.statusCode == 200) {
        // 6. 上传成功，通知服务器并更新消息状态
        await http.post(
          'chat/api_server/api/upload_file_remind',
          data: {
            "files": [
              {
                "file_type": mimeType ?? 'unknown',
                "filename": fileName,
                "size_readable": fileSizeInKB,
              },
            ],
          },
        );

        // 获取文件在线访问路径
        final fileUrlResponse = await http.post(
          'chat/api_server/api/get_file_path',
          data: {"filetype": mimeType ?? 'unknown', "filename": fileName},
        );

        // 更新消息为上传成功状态
        _updateFileMessageStatus(
          messageIndex!,
          'success',
          '文件上传成功',
          fileUrl: fileUrlResponse ?? '',
        );

        _showToast('文件上传成功');
      } else {
        _updateFileMessageStatus(
          messageIndex!,
          'failed',
          '上传失败，状态码: ${response.statusCode}',
        );
      }
    } catch (e) {
      _updateFileMessageStatus(
        messageIndex!,
        'failed',
        '上传异常: ${e.toString()}',
      );
      print('文件上传异常: $e');
    }
    // print('发送视频: $videoPath');
    // 这里添加你的视频处理和发送代码
  }

  // 相册功能处理
  void _handleGalleryTap() async {
    try {
      setState(() => showFunctions = false);

      // 显示选择对话框：选择图片或选择视频
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo),
                title: Text('选择图片'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImagesFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.video_library),
                title: Text('选择视频'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickVideoFromGallery();
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showError('选择媒体文件失败: $e');
      print('相册选择异常: $e');
    }
  }

  // 从相册选择图片
  Future<void> _pickImagesFromGallery() async {
    final picker = ImagePicker();
    // 使用pickMultiImage替代pickImage以支持多选
    final List<XFile>? pickedFiles = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 800,
    );

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      // 遍历选中的所有图片并发送
      for (var file in pickedFiles) {
        _sendImageMessage(file.path);
      }
      // 显示选中的图片数量
      _showToast('已选择 ${pickedFiles.length} 张图片');
    } else {
      _showToast('未选择图片');
    }
  }

  // 从相册选择视频
  Future<void> _pickVideoFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: Duration(seconds: 60), // 限制最长视频时间
    );

    if (pickedFile != null) {
      _sendVideoMessage(pickedFile.path);
    } else {
      _showToast('未选择视频');
    }
  }

  // 文件功能处理
  void _handleFileTap() {
    // setState(() => showFunctions = false);
    _showUploadOptionDialog();
  }

  void _showUploadOptionDialog() async {
    // 显示选择对话框：文件上传或文件夹上传
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择上传类型'),
        content: const Text('请选择是上传文件还是文件夹'),
        actions: [
          // 文件夹上传选项
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭对话框
              _handleFolderUpload(); // 处理文件夹上传
            },
            child: const Text('文件夹上传'),
          ),
          // 文件上传选项
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭对话框
              _handleMultipleFileUpload(); // 处理文件上传（支持多选）
            },
            child: const Text('文件上传'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkFolderPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ 需单独请求媒体权限
      if (await Permission.photos.isDenied ||
          await Permission.videos.isDenied ||
          await Permission.audio.isDenied) {
        // 发起权限请求
        final statuses = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
        // 检查是否全部授权
        return statuses[Permission.photos] == PermissionStatus.granted &&
            statuses[Permission.videos] == PermissionStatus.granted &&
            statuses[Permission.audio] == PermissionStatus.granted;
      }
      return true;
    }
    // iOS 无需特殊权限（但受沙盒限制）
    return true;
  }

  // 处理文件夹上传（无需多选）
  void _handleFolderUpload() async {
    try {
      // 1. 权限检查（添加日志）
      final hasPermission = await _checkFolderPermission();
      // print('权限检查结果：${hasPermission ? "已授权" : "未授权"}');
      if (!hasPermission) {
        _showToast('请授予文件访问权限');
        return;
      }

      // 隐藏功能菜单
      setState(() => showFunctions = false);

      // 2. 选择文件夹（添加路径日志）
      String? directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择要上传的文件夹',
      );
      // print('选择的文件夹路径：$directoryPath');

      if (directoryPath == null) {
        _showToast('未选择文件夹');
        return;
      }

      // 3. 验证文件夹是否存在
      Directory directory = Directory(directoryPath);
      bool dirExists = await directory.exists();
      // print('文件夹是否存在：$dirExists');
      if (!dirExists) {
        _showToast('文件夹不存在或已被删除');
        return;
      }

      // 4. 递归遍历文件夹（捕获遍历异常，添加详细日志）
      List<FileSystemEntity> entities = [];
      try {
        // 遍历所有实体（文件+目录）
        entities = await directory.list(recursive: true).toList();
        // print('遍历完成，实体总数：${entities.length}');
      } catch (e) {
        // print('文件夹遍历失败：$e（可能是权限不足或路径不可访问）');
        _showToast('无法读取文件夹内容，请选择其他文件夹');
        return;
      }

      // 5. 筛选文件并验证路径（排除无效文件）
      List<String> allFilePaths = [];
      for (var entity in entities) {
        // print('遍历到实体：${entity.path}，类型：${entity.runtimeType}');
        if (entity is File) {
          // 验证文件是否可访问
          bool fileExists = await entity.exists();
          if (fileExists) {
            allFilePaths.add(entity.path);
          } else {
            // print('文件不存在或不可访问：${entity.path}');
          }
        }
      }

      // print('有效文件总数：${allFilePaths.length}');
      if (allFilePaths.isEmpty) {
        _showToast('所选文件夹中无有效文件（可能是权限不足或文件被保护）');
        return;
      }

      // 6. 批量上传（添加上传进度日志）
      _showToast('将上传 ${allFilePaths.length} 个文件');
      for (int i = 0; i < allFilePaths.length; i++) {
        String filePath = allFilePaths[i];
        print('开始上传第 ${i + 1}/${allFilePaths.length} 个文件：$filePath');
        try {
          await _uploadSingleFile(filePath);
          print('第 ${i + 1} 个文件上传成功');
        } catch (e) {
          print('第 ${i + 1} 个文件上传失败：$e');
          // 可选：是否继续上传其他文件
          _showToast('部分文件上传失败：${path.basename(filePath)}');
        }
      }

      _showToast('所有文件上传完成');
    } catch (e) {
      _showError('文件夹处理失败: $e');
      print('文件夹上传总异常: $e');
    }
  }

  // 处理文件上传（支持多选）
  void _handleMultipleFileUpload() async {
    try {
      // 隐藏功能菜单
      setState(() => showFunctions = false);

      // 1. 使用file_picker选择多个文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true, // 支持多选文件
        withData: false,
        allowCompression: false,
      );

      // 检查是否选择了文件
      if (result == null) {
        _showToast('未选择文件');
        return;
      }

      // 收集所有选择的文件路径
      List<String> allFilePaths = [];
      for (PlatformFile file in result.files) {
        final path = file.path;
        if (path != null && await File(path).exists()) {
          allFilePaths.add(path);
        }
      }

      if (allFilePaths.isEmpty) {
        _showToast('未找到有效文件');
        return;
      }

      // 2. 批量上传所有文件
      _showToast('将上传 ${allFilePaths.length} 个文件');
      for (String filePath in allFilePaths) {
        await _uploadSingleFile(filePath);
      }
    } catch (e) {
      _showError('文件处理失败: $e');
      print('文件选择/上传异常: $e');
    }
  }

  // 上传单个文件的方法（复用原有逻辑）
  Future<void> _uploadSingleFile(String filePath) async {
    try {
      // 在聊天列表中添加临时上传状态消息
      int? messageIndex;
      final fileName = path.basename(filePath);
      setState(() {
        messages.add(
          ChatMessage(
            isMe: true,
            text: '正在上传: $fileName',
            fileInfo: {
              'name': fileName,
              'path': filePath,
              'status': 'uploading',
            },
          ),
        );
        messageIndex = messages.length - 1;
      });
      _scrollToBottom();

      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        _updateFileMessageStatus(messageIndex!, 'failed', '文件不存在');
        return;
      }

      // 获取文件大小
      final fileSizeInBytes = await file.length();
      final fileSizeInKB = (fileSizeInBytes / 1024).round();

      // 获取文件MIME类型
      final mimeType = await _getMimeType(filePath);
      print('图片格式: $mimeType');

      // 请求上传URL
      final uploadUrlResponse = await http.post(
        'file/uploadUrl',
        data: {
          "files": [
            {"contentType": mimeType, "fileName": fileName},
          ],
        },
      );

      if (uploadUrlResponse['code'] != 200 ||
          !(uploadUrlResponse['data'] is List) ||
          uploadUrlResponse['data'].isEmpty) {
        _updateFileMessageStatus(messageIndex!, 'failed', '获取上传地址失败');
        return;
      }

      // 提取上传URL
      final uploadUrl = uploadUrlResponse['data'][0]['url'] ?? '';
      if (uploadUrl.isEmpty) {
        _updateFileMessageStatus(messageIndex!, 'failed', '上传地址无效');
        return;
      }

      // 上传文件到获取的URL
      try {
        final dio = Dio();
        final response = await dio.put(
          uploadUrl,
          data: await file.readAsBytes(),
          options: Options(
            contentType: mimeType,
            headers: {'Content-Length': fileSizeInBytes.toString()},
          ),
          // 上传进度监听
          onSendProgress: (sent, total) {
            final progress = (sent / total * 100).round();
            _updateFileMessageStatus(
              messageIndex!,
              'uploading',
              '正在上传: $progress%',
            );
          },
        );

        if (response.statusCode == 200) {
          // 上传成功，通知服务器
          await http.post(
            'chat/api_server/api/upload_file_remind',
            data: {
              "files": [
                {
                  "file_type": mimeType,
                  "filename": fileName,
                  "size_readable": fileSizeInKB,
                },
              ],
            },
          );

          // 获取文件在线访问路径
          final fileUrlResponse = await http.post(
            'chat/api_server/api/get_file_path',
            data: {"filetype": mimeType ?? 'unknown', "filename": fileName},
          );

          // 更新消息为上传成功状态
          _updateFileMessageStatus(
            messageIndex!,
            'success',
            '文件上传成功',
            fileUrl: fileUrlResponse ?? '',
          );

          _showToast('文件上传成功');
        } else {
          _updateFileMessageStatus(
            messageIndex!,
            'failed',
            '上传失败，状态码: ${response.statusCode}',
          );
        }
      } catch (e) {
        _updateFileMessageStatus(
          messageIndex!,
          'failed',
          '上传异常: ${e.toString()}',
        );
        print('文件上传异常: $e');
      }
    } catch (e) {
      print('单个文件上传失败: $e');
    }
  }

  //接受分享文件
  void _handleSharedFiles(List<String> filePaths) async {
    // 创建一个基于时间戳的批次ID
    String batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}';

    for (var filePath in filePaths) {
      // 增加文件处理的唯一标识符，结合文件路径和批次ID
      String fileIdentifier = '${filePath}_$batchId';

      // 检查该文件是否正在被处理或已经处理过
      if (_sharedFilePaths.contains(filePath) ||
          _processingFileIdentifiers.contains(fileIdentifier)) {
        print('跳过重复处理的文件: $filePath');
        continue;
      }

      // 标记文件正在处理中
      _processingFileIdentifiers.add(fileIdentifier);

      final fileName = path.basename(filePath);
      ToastUtil.showInfo("正在处理分享文件: $fileName");

      int? messageIndex;
      setState(() {
        messages.add(
          ChatMessage(
            isMe: true,
            text: '正在上传文件: $fileName',
            fileInfo: {
              'name': fileName,
              'path': filePath,
              'status': 'uploading',
              'batchId': batchId, // 添加批次ID
            },
          ),
        );
        messageIndex = messages.length - 1;
      });
      _scrollToBottom();

      try {
        // 3. 获取文件信息并上传
        final file = File(filePath);
        if (!await file.exists()) {
          _updateFileMessageStatus(messageIndex!, 'failed', '文件不存在');
          continue;
        }

        // 获取文件大小
        final fileSizeInBytes = await file.length();
        final fileSizeInKB = (fileSizeInBytes / 1024).round();

        // 获取文件MIME类型
        final mimeType = await _getMimeType(filePath);

        // 4. 先请求上传URL（与现有图片上传逻辑类似）
        final uploadUrlResponse = await http.post(
          'file/uploadUrl',
          data: {
            "files": [
              {
                "contentType": mimeType ?? 'application/octet-stream',
                "fileName": fileName,
              },
            ],
          },
        );
        ToastUtil.showError('第一步$uploadUrlResponse');
        if (uploadUrlResponse['code'] != 200 ||
            !(uploadUrlResponse['data'] is List) ||
            uploadUrlResponse['data'].isEmpty) {
          _updateFileMessageStatus(messageIndex!, 'failed', '获取上传地址失败');
          continue;
        }

        // 提取上传URL
        final uploadUrl = uploadUrlResponse['data'][0]['url'] ?? '';
        if (uploadUrl.isEmpty) {
          _updateFileMessageStatus(messageIndex!, 'failed', '上传地址无效');
          continue;
        }

        final dio = Dio();
        final response = await dio.put(
          uploadUrl,
          data: await file.readAsBytes(),
          options: Options(
            contentType: mimeType ?? 'application/octet-stream',
            headers: {'Content-Length': fileSizeInBytes.toString()},
          ),
          // 添加上传进度监听
          onSendProgress: (sent, total) {
            final progress = (sent / total * 100).round();
            _updateFileMessageStatus(
              messageIndex!,
              'uploading',
              '正在上传: $progress%',
            );
          },
        );
        if (response.statusCode == 200) {
          // 6. 上传成功，通知服务器并更新消息状态
          await http.post(
            'chat/api_server/api/upload_file_remind',
            data: {
              "files": [
                {
                  "file_type": mimeType ?? 'unknown',
                  "filename": fileName,
                  "size_readable": fileSizeInKB,
                },
              ],
            },
          );

          // 获取文件在线访问路径
          final fileUrlResponse = await http.post(
            'chat/api_server/api/get_file_path',
            data: {"filetype": mimeType ?? 'unknown', "filename": fileName},
          );

          // 更新消息为上传成功状态
          _updateFileMessageStatus(
            messageIndex!,
            'success',
            '文件上传成功',
            fileUrl: fileUrlResponse ?? '',
          );

          // 将文件路径添加到已处理列表，防止再次处理
          _sharedFilePaths.add(filePath);
          _showToast('文件上传成功');
        }
      } catch (e) {
        _updateFileMessageStatus(
          messageIndex!,
          'failed',
          '上传失败: ${e.toString()}',
        );
      } finally {
        // 无论成功失败，都移除正在处理的标记
        _processingFileIdentifiers.remove(fileIdentifier);

        if (!_sharedFilePaths.contains(filePath)) {
          _sharedFilePaths.add(filePath);
        }
      }
    }
  }

  // 辅助方法：格式化文件大小显示
  // String _formatFileSize(int bytes) {
  //   if (bytes <= 0) return "0 B";
  //   const suffixes = ["B", "KB", "MB", "GB", "TB"];
  //   final i = (log(bytes) / log(1024)).floor();
  //   return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  // }

  // 更新文件消息状态
  void _updateFileMessageStatus(
    int messageIndex,
    String status,
    String text, {
    String fileUrl = '',
  }) {
    if (messageIndex >= 0 && messageIndex < messages.length) {
      setState(() {
        // 更新消息文本
        messages[messageIndex].text = text;
        // 更新文件信息状态
        if (messages[messageIndex].fileInfo != null) {
          messages[messageIndex].fileInfo!['status'] = status;
          if (fileUrl.isNotEmpty) {
            messages[messageIndex].fileInfo!['url'] = fileUrl;
          }
        }
      });
      _scrollToBottom();
    }
  }

  // 获取文件MIME类型
  Future<String?> _getMimeType(String filePath) async {
    // 简单根据文件扩展名判断MIME类型
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      case '.txt':
        return 'text/plain';
      case '.jpg':
        return 'image/jpeg';
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.mp3':
        return 'audio/mpeg';
      case '.aac':
        return 'audio/aac';
      case '.mp4':
        return 'video/mp4';
      case '.avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream'; // 未知类型
    }
  }

  // 录音功能处理
  void _handleAudioTap() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showError('需要麦克风权限才能使用录音功能');
        return;
      }
    }
    _showRecordingBottomSheet(); // 显示底部弹窗
  }

  // 显示录音底部弹窗
  void _showRecordingBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) =>
            _buildRecordingSheetContent(context, setState),
      ),
    );
  }

  Widget _buildRecordingSheetContent(
    BuildContext context,
    StateSetter setState,
  ) {
    return Scaffold(
      appBar: AppBar(title: const Text(' 录音')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 录音/停止按钮
            ElevatedButton(
              onPressed: () => _toggle(setState),
              child: Text(_isRecording ? '停止录音' : '开始录音'),
            ),
            const SizedBox(height: 12), // 间距
            // 当不在录音且存在录音文件时，显示文件信息和播放按钮
            if (!_isRecording && _filePath != null) ...[
              // 显示录音文件名（仅显示文件名，不显示完整路径）
              Text('已保存: ${_filePath!.split('/').last}'),
              // 播放按钮
              ElevatedButton(onPressed: _play, child: const Text('播放')),
              ElevatedButton(
                onPressed: _sendAudioMessage,
                child: const Text('发送'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _filePath = null);
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 多选分享对话框
  Future<void> _showMultiShareDialog([String? preselectedId]) async {
    // 切换到多选模式
    setState(() {
      _isMultiSelectMode = true;
      _selectedMessageIds.clear();

      // 如果有预选ID，选中它
      if (preselectedId != null &&
          messages.any((m) => m.messageId == preselectedId)) {
        _selectedMessageIds.add(preselectedId);
      }
    });
    // // 筛选出有messageId的消息
    // final shareableMessages = messages
    //     .where((msg) => msg.messageId != null)
    //     .toList();
    // if (shareableMessages.isEmpty) {
    //   ToastUtil.showError('没有可分享的内容');
    //   return;
    // }

    // // 存储选中的messageId
    // List<String> selectedMessageIds = [];
    // if (preselectedId != null &&
    //     shareableMessages.any((m) => m.messageId == preselectedId)) {
    //   selectedMessageIds.add(preselectedId);
    // }

    // await showDialog(
    //   context: context,
    //   builder: (context) => StatefulBuilder(
    //     builder: (context, setState) => AlertDialog(
    //       title: const Text('选择要分享的内容'),
    //       content: SizedBox(
    //         width: double.maxFinite,
    //         height: 300,
    //         child: ListView.builder(
    //           itemCount: shareableMessages.length,
    //           itemBuilder: (context, index) {
    //             final msg = shareableMessages[index];
    //             final isSelected = selectedMessageIds.contains(msg.messageId);

    //             return CheckboxListTile(
    //               title: Text(
    //                 msg.fullText.length > 20
    //                     ? '${msg.fullText.substring(0, 20)}...'
    //                     : msg.fullText,
    //                 style: TextStyle(
    //                   color: msg.isMe ? Colors.blue : Colors.black87,
    //                 ),
    //               ),
    //               subtitle: Text(msg.isMe ? '我发送的消息' : 'AI回复'),
    //               value: isSelected,
    //               onChanged: (value) {
    //                 setState(() {
    //                   if (value == true && msg.messageId != null) {
    //                     selectedMessageIds.add(msg.messageId!);
    //                   } else {
    //                     selectedMessageIds.remove(msg.messageId);
    //                   }
    //                 });
    //               },
    //             );
    //           },
    //         ),
    //       ),
    //       actions: [
    //         TextButton(
    //           onPressed: () => Navigator.pop(context),
    //           child: const Text('取消'),
    //         ),
    //         TextButton(
    //           onPressed: selectedMessageIds.isEmpty
    //               ? null
    //               : () {
    //                   Navigator.pop(context);
    //                   _generateMultiShareUrl(selectedMessageIds);
    //                 },
    //           child: const Text('确定分享'),
    //         ),
    //       ],
    //     ),
    //   ),
    // );
  }

  // 新增：退出多选模式
  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedMessageIds.clear();
    });
  }

  // 新增：切换消息选中状态
  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  // 生成多个消息的分享链接
  Future<void> _generateMultiShareUrl(List<String> messageIds) async {
    if (userId.isEmpty) {
      ToastUtil.showError('用户信息未加载完成');
      return;
    }

    try {
      final response = await http.post(
        'chat/api_server/api/generate_share_url',
        data: {
          "user_id": userId,
          "message_ids": messageIds, // 传递消息ID列表，包括文件消息
        },
      );

      final shareUrl = response['url'];
      if (shareUrl != null) {
        await FlutterClipboard.copy(shareUrl);
        ToastUtil.showSuccess('已成功复制${messageIds.length}条内容的分享链接');
        // 退出多选模式
        _exitMultiSelectMode();
      } else {
        ToastUtil.showError('生成分享链接失败');
      }
    } catch (e) {
      print('生成分享链接错误: $e');
      ToastUtil.showError('生成分享链接失败: $e');
    }
  }

  // 录音相关方法
  void _startVoiceRecording(Offset startOffset) async {
    _startTouchOffset = startOffset;
    _isVoiceCancel = false;
    _recordingSeconds = 0;
    setState(() => _isVoiceRecording = true);

    // 权限检查
    await _checkPermissions();

    // 开始录音
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.opus';
    try {
      await _recorderas.start(
        RecordConfig(encoder: AudioEncoder.opus, sampleRate: 16000),
        path: filePath,
      );
      _voiceFilePath = filePath;
      debugPrint('录音开始: $filePath');

      // 计时器
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });
      });
    } catch (e) {
      _showToast('录音失败，请重试');
      setState(() {
        _isVoiceRecording = false;
        _isVoiceCancel = false;
      });
    }
  }

  void _updateVoiceRecording(Offset moveOffset) {
    // 判断是否手指上滑超过一定距离，则取消发送
    if (_startTouchOffset == null) return;
    double dy = moveOffset.dy - _startTouchOffset!.dy;
    // 比如向上滑动超过60像素则取消
    bool shouldCancel = dy < -60;
    if (shouldCancel != _isVoiceCancel) {
      setState(() {
        _isVoiceCancel = shouldCancel;
      });
    }
  }

  void _stopVoiceRecording(Offset endOffset) async {
    _voiceTimer?.cancel();
    setState(() {
      _isVoiceRecording = false;
    });

    // 停止录音
    String? filePath;
    try {
      filePath = await _recorderas.stop();
    } catch (e) {
      filePath = _voiceFilePath;
    }

    if (_isVoiceCancel) {
      _showToast('已取消发送语音');
      return;
    }

    if (filePath == null) {
      _showToast('录音文件无效');
      return;
    }
    // 添加录音时长检查：小于1秒不发送
    if (_recordingSeconds < 1) {
      _showToast('录音时间太短,');
      // 可选：删除太短的录音文件以节省存储空间
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('删除短录音文件失败: $e');
      }
      return;
    }
    // 发送语音消息到聊天列表
    _sendAudioToChat(filePath);
    _voiceFilePath = null;
    _recordingSeconds = 0;
  }

  // 语音消息添加到聊天列表（你原有的接口发送逻辑可以在这里调用）
  void _sendAudioToChat(String filePath) async {
    int? messageIndex;
    final fileName = path.basename(filePath);

    // 1. 读取aac文件
    final file = File(filePath);
    if (!await file.exists()) {
      _showToast('语音文件不存在');
      return;
    }
    final bytes = await file.readAsBytes();

    // 2. 二进制转base64字符串
    final base64Audio = base64Encode(bytes);
    print('录音格式: $base64Audio');
    // setState(() {
    //   messages.add(
    //     ChatMessage(
    //       isMe: true,
    //       text: '正在发送语音...',
    //       fileInfo: {
    //         'name': fileName,
    //         'path': filePath,
    //         'status': 'uploading',
    //         'type': 'audio',
    //       },
    //     ),
    //   );
    //   messageIndex = messages.length - 1;
    // });
    _scrollToBottom();

    // /// 读取音频文件内容并转为 base64
    // final file = File(filePath);
    // if (!await file.exists()) {
    //   _updateFileMessageStatus(messageIndex!, 'failed', '语音文件不存在');
    //   return;
    // }
    // final bytes = await file.readAsBytes();
    // final base64Audio = base64Encode(bytes);

    // 构造接口参数
    final msg = {
      "action": "audio",
      "data": {"audio": base64Audio},
    };

    try {
      if (!_wsManager.isConnected || _wsManager._channel == null) {
        _showToast('连接已断开，请重新发送');
        // 可以选择自动尝试重连
        if (!_wsManager.isReconnecting) {
          _showToast('正在尝试重新连接...');
          _reconnectWebSocket();
        }
        return;
      }
      // 通过 WebSocket 发送消息（假设你的 wsManager 已连接）
      _wsManager._channel?.sink.add(jsonEncode(msg));
      // 成功后可以更新 UI 状态
      // _updateFileMessageStatus(messageIndex!, 'success', '语音发送成功');
      _showToast('语音发送成功');
    } catch (e) {
      // _updateFileMessageStatus(messageIndex!, 'failed', '语音发送失败: $e');
      _showToast('语音发送失败');

      _showToast('连接已断开，请重新发送');
      // 尝试重新连接
      if (!_wsManager.isReconnecting) {
        _reconnectWebSocket();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用super
    return Scaffold(
      resizeToAvoidBottomInset: true, // 确保键盘弹出时自动调整视图
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          // 禁止页面无限滚动
          physics: const ClampingScrollPhysics(),
          // 添加页面切换完成回调
          onPageChanged: (int pageIndex) {
            _currentPageIndex = pageIndex;
            // 如果切换回主页面，恢复滚动位置
            if (pageIndex == 1) {
              _restoreScrollPosition();
            } else {
              // 离开主页面时保存滚动位置
              _saveScrollPosition();
            }
          },
          children: [
            // 左滑页面
            _buildLeftScreen(),
            // 中间主聊天页面
            _buildMainChatScreen(),
            // 右滑页面
            _buildRightScreen(),
          ],
        ),
      ),
    );
  }

  // 主聊天界面（原有内容）
  Widget _buildMainChatScreen() {
    return Stack(
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
            // 消息列表
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMoreMessages,
                child: ListView.builder(
                  key: const PageStorageKey<String>('chatMessagesList'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemCount: messages.isEmpty ? 1 : messages.length,
                  itemBuilder: (context, index) {
                    // 处理空列表的情况，显示提示信息
                    if (messages.isEmpty) {
                      return const Center(
                        heightFactor: 30, // 增加高度，方便下拉操作
                        child: Text(
                          '下拉加载消息',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    final message = messages[index];
                    bool isLastMessage = index == messages.length - 1;
                    return KeyedSubtree(
                      key: ValueKey(message.messageId ?? 'msg_$index'),
                      child: Column(
                        children: [
                          // 添加时间提示
                          if (message.isMe) // 只在用户消息上方显示时间
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    message.timestamp ??
                                        getCurrentFormattedTimestamp(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ChatBubble(
                            message: message,
                            onShare: (messageId) =>
                                _generateshareurl(messageId),
                            onShowShareDialog: _showMultiShareDialog,
                            onPlayTextToSpeech: _playTextToSpeech,
                            onStopTextToSpeech: _stopTextToSpeech,
                            isPlaying: _isPlaying,
                            isLastMessage: isLastMessage,
                            onStop: _stopAIResponse, // 传递停止回调
                            onUpdate: isLastMessage
                                ? _handleUpdateMessage
                                : null,
                            isMultiSelectMode: _isMultiSelectMode, // 传递多选模式状态
                            isSelected: _selectedMessageIds.contains(
                              message.messageId,
                            ), // 传递选中状态
                            onToggleSelect:
                                _toggleMessageSelection, // 传递切换选中状态的方法
                          ),
                          // 如果是用户消息且处于加载状态，显示加载指示器
                          if (message.isMe && message.loading)
                            const ChatLoadingIndicator(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // 新增：多选模式底部操作栏
            if (_isMultiSelectMode)
              Container(
                height: 60,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _exitMultiSelectMode,
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: _selectedMessageIds.isEmpty
                          ? null
                          : () {
                              _generateMultiShareUrl(_selectedMessageIds);
                            },
                      child: Text(
                        '分享 (${_selectedMessageIds.length})',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
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
                    '以上内容由云奕AI生成',
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                ),
              ),
            ),
          ],
        ),
        // if (isRecording) _buildRecordingOverlay(),
      ],
    );
  }

  // 左滑页面内容
  Widget _buildLeftScreen() {
    final stats = _knowledgeData?['statistics'] ?? {};
    final fileBreakdown = stats['file_breakdown'] ?? {};
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360; // 小型屏幕适配标记
    // final exportTime = _knowledgeData?['export_time'] ?? '未导出';
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text(''),
      //   automaticallyImplyLeading: false, // 去除返回按钮
      // ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/chat/bg1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和导出按钮 Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '用户数据信息',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    // 增加文字阴影，在背景图上更清晰
                    // shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 表格内容，使用带透明背景的Container包裹，提升可读性
              Container(
                color: Colors.white.withOpacity(0.85),
                child: Table(
                  border: TableBorder.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                  children: [
                    _buildTableRow(
                      '对话数量',
                      (stats['history_count'] ?? 0).toString(),
                    ),
                    _buildTableRow(
                      '记忆数量',
                      (stats['memory_count'] ?? 0).toString(),
                    ),
                    _buildTableRow(
                      '上传文件数量',
                      (stats['uploaded_file_count'] ?? 0).toString(),
                    ),
                    _buildTableRow(
                      '输出报告数',
                      (stats['report_count'] ?? 0).toString(),
                    ),
                    _buildTableRow(
                      '知识向量数',
                      (stats['total_vectors'] ?? 0).toString(),
                    ),
                    _buildTableRow(
                      '文档数量',
                      (fileBreakdown['document_count'] ?? 0).toString(),
                    ),
                    _buildTableRow(
                      '音频数量',
                      (fileBreakdown['audio_count'] ?? 0).toString(),
                    ),
                    _buildTableRow(
                      '图片数量',
                      (fileBreakdown['image_count'] ?? 0).toString(),
                    ),
                    _buildTableRow(
                      '视频数量',
                      (fileBreakdown['video_count'] ?? 0).toString(),
                    ),
                  ],
                ),
              ),

              // 修改列表渲染部分，使用聊天历史作为父项
              Expanded(
                child: _chatHistoryTasks.isEmpty
                    ? Center(
                        child: Text(
                          '暂无聊天记录',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(top: isSmallScreen ? 8 : 10),
                        itemCount: _chatHistoryTasks.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                          indent: isSmallScreen ? 12 : 16,
                          endIndent: isSmallScreen ? 12 : 16,
                        ),
                        itemBuilder: (context, index) {
                          Widget _buildTaskItem(
                            Map<String, dynamic> task, {
                            bool isChild = false,
                          }) {
                            final marginHorizontal = isChild
                                ? (isSmallScreen ? 20 : 28)
                                : (isSmallScreen ? 4 : 8);

                            // 构建右侧的"正在检索知识库"和暂停按钮
                            Widget _buildTrailing() {
                              // 修改：使用任务项自己的isRetrieving状态
                              bool isRetrieving = task['isRetrieving'] ?? false;

                              if (isRetrieving) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '正在检索知识库',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 13,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 12),
                                    IconButton(
                                      icon: Icon(
                                        Icons.pause_circle_outline,
                                        size: isSmallScreen ? 18 : 22,
                                        color: Colors.grey[500],
                                      ),
                                      onPressed: () {
                                        // 暂停按钮点击事件
                                        setState(() {
                                          // 修改：更新任务项自己的isRetrieving状态
                                          task['isRetrieving'] = false;
                                          _stopAIResponse(task['message_id']);
                                        });
                                        // 这里可以添加实际的暂停检索逻辑
                                        print('停止检索知识库');
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                    ),
                                  ],
                                );
                              } else {
                                // AI回复完毕或已停止，显示下拉图标
                                return Icon(
                                  Icons.expand_more,
                                  size: isSmallScreen ? 18 : 22,
                                  color: Colors.grey[500],
                                );
                              }
                            }

                            return Container(
                              margin: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 3 : 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: isSmallScreen ? 1 : 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),

                              child: ExpansionTile(
                                title: Text(
                                  task['name'],
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: task['datetime'] != null
                                    ? Text(
                                        task['datetime'],
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 13,
                                          color: Colors.grey[500],
                                        ),
                                      )
                                    : null,
                                // 只在父项显示右侧的状态和按钮
                                trailing: !isChild ? _buildTrailing() : null,
                                children: [
                                  if (task['detail'] != null &&
                                      task['detail'].isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        isSmallScreen ? 12 : 16,
                                        isSmallScreen ? 4 : 6,
                                        isSmallScreen ? 12 : 16,
                                        isSmallScreen ? 12 : 16,
                                      ),
                                      child: Text(
                                        task['detail'],
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 13 : 14,
                                          color: Colors.grey[700],
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  if (task['children'] != null &&
                                      task['children'].isNotEmpty)
                                    Column(
                                      children:
                                          (task['children'] as List<dynamic>)
                                              .map(
                                                (child) => _buildTaskItem(
                                                  child,
                                                  isChild: true,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                ],
                              ),
                            );
                          }

                          return _buildTaskItem(_chatHistoryTasks[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 辅助函数，构建表格的每一行
  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey.shade100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Container(padding: const EdgeInsets.all(8), child: Text(value)),
      ],
    );
  }

  // 右滑页面内容
  Widget _buildRightScreen() {
    // 移除本地模拟数据，使用解析后的_taskList
    // 注意：_taskList应该是类的成员变量，在状态中维护

    // 获取屏幕尺寸信息，用于响应式布局
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360; // 小型屏幕适配标记

    // 文件点击处理方法
    void _onFileTap(TaskFile file) async {
      print("点击了文件: ${file}");
      // 可以添加文件点击后的实际处理逻辑
      var sage = await http.post(
        'chat/api_server/api/get_file_path',
        data: {'filename': file.name, 'filetype': file.type},
      );
      // launch(sage);
      await launchUrl(Uri.parse(sage));
    }

    // 任务状态颜色映射
    Color _getStatusColor(String status) {
      switch (status) {
        case "已完成":
          return Colors.green;
        case "处理中":
          return Colors.blue;
        case "已接受":
          return Colors.blue;
        case "失败":
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/chat/bg1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 任务池标题栏
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 8.0 : 12.0,
                  horizontal: isSmallScreen ? 12.0 : 16.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '任务池',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 12 : 16),

              // 任务列表 - 使用解析后的_taskList
              Expanded(
                child: _taskList.isEmpty
                    ? Center(
                        child: Text(
                          '暂无任务数据',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(top: isSmallScreen ? 8 : 10),
                        itemCount: _taskList.length, // 使用实际数据长度
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                          indent: isSmallScreen ? 12 : 16,
                          endIndent: isSmallScreen ? 12 : 16,
                        ),
                        itemBuilder: (context, index) {
                          Task task = _taskList[index]; // 使用实际数据
                          Color statusColor = _getStatusColor(task.status);

                          return Container(
                            margin: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 2 : 4,
                              horizontal: isSmallScreen ? 4 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: isSmallScreen ? 1 : 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ExpansionTile(
                              title: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: screenWidth * 0.6,
                                ),
                                child: Text(
                                  task.name,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              subtitle: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 6 : 8,
                                      vertical: isSmallScreen ? 2 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      task.status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                // 任务详情
                                if (task.detail != null &&
                                    task.detail!.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.all(
                                      isSmallScreen ? 8.0 : 12.0,
                                    ),
                                    child: Text(
                                      task.detail!,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13 : 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),

                                // 文件列表标题
                                if (task.files != null &&
                                    task.files!.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: isSmallScreen ? 12 : 16,
                                      top: isSmallScreen ? 4 : 8,
                                      bottom: isSmallScreen ? 4 : 8,
                                    ),
                                    child: Text(
                                      "相关文件 (${task.files!.length})",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13 : 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),

                                // 文件列表
                                if (task.files != null &&
                                    task.files!.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 8 : 12,
                                      vertical: isSmallScreen ? 4 : 8,
                                    ),
                                    child: Column(
                                      children: task.files!.map((file) {
                                        return InkWell(
                                          onTap: () => _onFileTap(file),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isSmallScreen
                                                  ? 8
                                                  : 12,
                                              vertical: isSmallScreen ? 6 : 10,
                                            ),
                                            margin: EdgeInsets.only(
                                              bottom: isSmallScreen ? 4 : 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.grey[200]!,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                // 文件名
                                                Expanded(
                                                  child: Text(
                                                    file.name,
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen
                                                          ? 13
                                                          : 14,
                                                      color: Colors.blueAccent,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // 文件大小
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                    left: isSmallScreen
                                                        ? 8
                                                        : 12,
                                                  ),
                                                  child: Text(
                                                    file.size,
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen
                                                          ? 12
                                                          : 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 顶部导航栏
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 5, right: 10, left: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // 个人资料页面跳转
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfilePageCustom(),
                ),
              );
            },
            child: Hero(
              tag: 'userAvatar', // 添加Hero标签，实现平滑过渡
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50.0),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: _buildAvatarWidget(), // 提取头像构建逻辑到单独方法
                ),
              ),
            ),
          ),
          const Spacer(),
          // GestureDetector(

          //   onTap: () {
          //     // 历史记录页面跳转
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => const HistoryPage()),
          //     );
          //   },
          //   child: const Image(
          //     image: AssetImage('assets/chat/history.png'),
          //     width: 30,
          //   ),
          // ),
        ],
      ),
    );
  }

  // 新增：提取头像构建逻辑到单独方法
  Widget _buildAvatarWidget() {
    // 用户头像数据没有变化时，确保返回相同的Widget实例
    if (userInfo['avatar'] != null &&
        userInfo['avatar'].toString().isNotEmpty) {
      if (userInfo['avatar'].toString().startsWith('data:image')) {
        // 对于Base64图片，可以考虑缓存解码后的字节数据
        try {
          return Image.memory(
            base64Decode(userInfo['avatar'].toString().split(',')[1]),
            fit: BoxFit.cover,
            gaplessPlayback: true, // 关键属性：切换图片时不显示空白
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/chat/tx.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          );
        } catch (e) {
          // 解码失败时显示默认头像
          print('头像解码失败: $e');
          return Image.asset(
            'assets/chat/tx.png',
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
      } else {
        return Image.network(
          userInfo['avatar'],
          fit: BoxFit.cover,
          gaplessPlayback: true, // 关键属性：切换图片时不显示空白
          cacheWidth: 40, // 缓存小尺寸图片，减少内存使用
          cacheHeight: 40,
          errorBuilder: (context, error, stackTrace) {
            // 网络图片加载失败时显示默认头像
            print('头像加载失败: $error');
            return Image.asset(
              'assets/chat/tx.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          },
        );
      }
    } else {
      // 使用本地资源图片时也添加gaplessPlayback属性
      return Image.asset(
        'assets/chat/tx.png',
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
  }

  // 输入栏 - 已修改以实现动态图标切换
  Widget _buildInputBar() {
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
          // 主输入容器
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!),
              ),
              constraints: const BoxConstraints(minHeight: 60),
              child: Stack(
                children: [
                  // 文本输入模式
                  Offstage(
                    offstage: isVoiceMode,
                    child: TextField(
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
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  // 语音输入模式
                  Offstage(
                    offstage: !isVoiceMode,
                    child: Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        // 长按开始录音
                        onLongPressStart: (details) {
                          _startVoiceRecording(details.globalPosition);
                        },
                        // 长按结束（松开）发送语音
                        onLongPressEnd: (details) {
                          _stopVoiceRecording(details.globalPosition);
                        },
                        // 手指移动时，判断是否取消
                        onLongPressMoveUpdate: (details) {
                          _updateVoiceRecording(details.globalPosition);
                        },
                        child: Container(
                          height: 50, // 可以适当加大
                          width: double.infinity, // 横向撑满
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.transparent, // 背景色透明
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.transparent, // 边框色透明
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _isVoiceRecording
                                ? (_isVoiceCancel ? '松开取消发送' : '松开发送语音')
                                : '按住说话',
                            style: TextStyle(
                              color: _isVoiceRecording
                                  ? (_isVoiceCancel ? Colors.red : Colors.blue)
                                  : Colors.grey,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
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
          // 右侧图标 - 根据键盘状态和输入内容动态切换
          if (!isVoiceMode) _buildRightIcon(),
          if (isVoiceMode)
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

  // 新增: 根据键盘状态和输入内容构建右侧图标
  Widget _buildRightIcon() {
    // 逻辑:
    // 1. 键盘弹出时，显示功能菜单切换图标
    // 2. 键盘未弹出但有输入内容时，显示发送图标(fson.svg)
    // 3. 其他情况显示功能菜单切换图标

    if (_hasInputContent) {
      // 键盘未弹出且有输入内容，显示发送图标
      return GestureDetector(
        onTap: () => _sendMessage(_controller.text),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: Image(
            width: 30,
            height: 30,
            image: const AssetImage('assets/chat/fs.png'), // 发送图标
          ),
        ),
      );
    } else {
      // 其他情况显示功能菜单切换图标
      return GestureDetector(
        onTap: () => setState(() => showFunctions = !showFunctions),
        child: Container(
          margin: const EdgeInsets.only(bottom: 13.5),
          child: Image(
            width: 30,
            height: 30,
            image: AssetImage(
              showFunctions ? 'assets/chat/14.png' : 'assets/chat/5.png',
            ),
          ),
        ),
      );
    }
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
}

// 5. 创建加载指示器组件
class ChatLoadingIndicator extends StatelessWidget {
  const ChatLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // AI消息在左侧
        children: [
          // AI头像
          // Container(
          //   width: 40,
          //   height: 40,
          //   decoration: const BoxDecoration(
          //     shape: BoxShape.circle,
          //     color: Colors.grey,
          //     image: DecorationImage(
          //       image: AssetImage('assets/chat/ai_avatar.png'), // 替换为你的AI头像
          //       fit: BoxFit.cover,
          //     ),
          //   ),
          // ),
          const SizedBox(width: 10),
          // 加载指示器和文字
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: const [
                Text(
                  "正在思考中...",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 聊天消息模型
class ChatMessage {
  String text; // 直接存储完整文本
  final bool isMe;
  final double? progress;
  final String? imageUrl;
  final String? localImagePath; // 本地图片路径（用于上传过程中显示）
  String? messageId; // 新增：存储消息唯一ID
  final Map<String, dynamic>? fileInfo; // 新增：用于存储文件信息
  String _fullText;
  bool loading; // 新增：加载状态
  bool isGenerating; // 新增：标识AI是否正在生成回复
  String? timestamp; // 新增：用于存储消息的时间戳

  // 构造方法
  ChatMessage({
    this.text = '',
    required this.isMe,
    this.progress,
    this.imageUrl,
    this.localImagePath,
    this.messageId,
    this.fileInfo, // 新增参数
    this.loading = false, // 默认为false
    this.isGenerating = false,
    this.timestamp,
  }) : _fullText = text;

  // 添加文本（AI流式回复用）
  void appendText(String text) {
    this.text += text;
  }

  // 获取完整文本
  String get fullText => text;
  // 新增：用于更新消息状态的复制方法
  ChatMessage copyWith({
    String? text,
    bool? isMe,
    double? progress,
    String? messageId,
    String? imageUrl,
    String? localImagePath,
    String? timestamp, // 新增参数
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isMe: isMe ?? this.isMe,
      progress: progress ?? this.progress,
      imageUrl: imageUrl ?? this.imageUrl,
      messageId: messageId ?? this.messageId, // 复制时携带ID
      localImagePath: localImagePath ?? this.localImagePath,
      timestamp: timestamp ?? this.timestamp, // 复制时携带时间戳
    );
  }
}

// 聊天气泡组件
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  // final VoidCallback? onShare;
  final Function(String messageId)? onShare;
  final bool isLastMessage;
  final VoidCallback? onUpdate; // 新增：update按钮点击回调
  final Function(String messageId)? onStop; // 新增停止回调
  final Future<void> Function(String?) onShowShareDialog;
  final Function(String messageId, String fullText)? onPlayTextToSpeech;
  final Function()? onStopTextToSpeech;
  final bool isPlaying;
  final bool isMultiSelectMode; // 新增：是否处于多选模式
  final bool isSelected; // 新增：当前消息是否被选中
  final Function(String messageId) onToggleSelect; // 新增：切换选中状态的方法
  ChatBubble({
    super.key,
    required this.message,
    this.onShare,
    this.isLastMessage = false,
    this.onUpdate,
    this.onStop,
    required this.onShowShareDialog,
    this.onPlayTextToSpeech,
    this.onStopTextToSpeech,
    this.isPlaying = false,
    this.isMultiSelectMode = false, // 新增：默认不是多选模式
    this.isSelected = false, // 新增：默认未选中
    required this.onToggleSelect, // 新增：必须提供切换选中状态的方法
  });

  @override
  Widget build(BuildContext context) {
    // 处理文件消息
    if (message.fileInfo != null) {
      return Column(
        crossAxisAlignment: message.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _buildFileMessage(context),
          // 文件操作按钮
          if (!isMultiSelectMode) _buildFileActions(),
        ],
      );
    }
    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI消息：复选框在左侧，内容在右侧
          if (isMultiSelectMode && !isMe && message.messageId != null)
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onToggleSelect(message.messageId!),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(width: 2, color: Colors.blue),
                        color: isSelected ? Colors.blue : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
                _bubbleContent(context),
              ],
            ),

          // 用户消息：内容在左侧，复选框在右侧
          if (isMultiSelectMode && isMe && message.messageId != null)
            Row(
              children: [
                _bubbleContent(context),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => onToggleSelect(message.messageId!),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(width: 2, color: Colors.blue),
                        color: isSelected ? Colors.blue : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          // 非多选模式下或没有messageId时，正常显示气泡内容
          if (!isMultiSelectMode || message.messageId == null)
            _bubbleContent(context),
        ],
      ),
    );
  }

  // 添加文件消息操作按钮方法
  Widget _buildFileActions() {
    if (message.fileInfo?['status'] != 'success') return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: message.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // 复制按钮
          // _iconButton('assets/chat/copy.png', onPressed: () => _copyFileInfo()),
          // const SizedBox(width: 15),
          // 分享按钮
          _iconButton(
            'assets/chat/share.png',
            onPressed: () => onShowShareDialog(message.messageId),
          ),
        ],
      ),
    );
  }

  // 复制文件信息到剪贴板
  // Future<void> _copyFileInfo() async {
  //   final fileName = message.fileInfo?['name'] ?? '未知文件';
  //   final fileSize = message.fileInfo?['size'] ?? '未知大小';
  //   final fileType = message.fileInfo?['type'] ?? '未知类型';

  //   final fileInfoText = '$fileName ($fileType, ${fileSize}KB)';

  //   try {
  //     await FlutterClipboard.copy(fileInfoText);
  //     ToastUtil.showSuccess('文件信息已复制');
  //   } on PlatformException catch (e) {
  //     ToastUtil.showError('复制失败');
  //     print('复制失败: $e');
  //   }
  // }

  Widget _bubbleContent(BuildContext context) {
    final isMe = message.isMe;
    final bubbleColor = isMe ? const Color(0xFF3A70E2) : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    const double maxWidth = 320;

    // 图片消息处理（优先显示本地图片，没有则显示在线图片）
    if (message.localImagePath != null || message.imageUrl != null) {
      return Container(
        width: 270,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: _getBorderRadius(isMe),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _buildImageWidget(context), // 新增图片显示逻辑
        ),
      );
    }

    // 文本消息处理（保持不变）
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        // 进度条和操作按钮（保持不变）
        if (message.progress != null) _buildProgressIndicator(),
        if (!message.isMe) _buildAIActions(message),
        if (message.isMe) _buildUserActions(message),
      ],
    );
  }

  // 构建文件消息UI
  Widget _buildFileMessage(BuildContext context) {
    final fileInfo = message.fileInfo!;
    final fileName = fileInfo['name'] ?? '未知文件';
    final status = fileInfo['status'] ?? 'unknown';
    final fileUrl = fileInfo['url'] ?? '';

    // 根据状态选择图标
    IconData fileIcon;
    Color iconColor = Colors.grey;

    switch (status) {
      case 'uploading':
        fileIcon = Icons.cloud_upload;
        iconColor = Colors.blue;
        break;
      case 'success':
        fileIcon = Icons.insert_drive_file;
        iconColor = Colors.green;
        break;
      case 'failed':
        fileIcon = Icons.error;
        iconColor = Colors.red;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: message.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // AI文件消息：复选框在左侧，内容在右侧
          if (isMultiSelectMode && !message.isMe && message.messageId != null)
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onToggleSelect(message.messageId!),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(width: 2, color: Colors.blue),
                        color: isSelected ? Colors.blue : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
                _buildFileContent(context, fileInfo, fileName, status, fileUrl),
              ],
            ),

          // 用户文件消息：内容在左侧，复选框在右侧
          if (isMultiSelectMode && message.isMe && message.messageId != null)
            Row(
              children: [
                _buildFileContent(context, fileInfo, fileName, status, fileUrl),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => onToggleSelect(message.messageId!),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(width: 2, color: Colors.blue),
                        color: isSelected ? Colors.blue : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),

          // 非多选模式下或没有messageId时，正常显示文件内容
          if (!isMultiSelectMode || message.messageId == null)
            _buildFileContent(context, fileInfo, fileName, status, fileUrl),
        ],
      ),
    );
  }

  // 提取文件内容为单独方法，便于复用
  Widget _buildFileContent(
    BuildContext context,
    Map<String, dynamic> fileInfo,
    String fileName,
    String status,
    String fileUrl,
  ) {
    IconData fileIcon;
    Color iconColor = Colors.grey;

    switch (status) {
      case 'uploading':
        fileIcon = Icons.cloud_upload;
        iconColor = Colors.blue;
        break;
      case 'success':
        fileIcon = Icons.insert_drive_file;
        iconColor = Colors.green;
        break;
      case 'failed':
        fileIcon = Icons.error;
        iconColor = Colors.red;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isMe ? Colors.blue[100] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件图标和名称
          Row(
            children: [
              Icon(fileIcon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 状态文本
          Text(
            message.text,
            style: TextStyle(
              fontSize: 12,
              color: status == 'failed' ? Colors.red : Colors.grey[600],
            ),
          ),
          // 如果上传成功且有文件URL，显示下载/打开按钮
          if (status == 'success' && fileUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => _openFile(context, fileUrl),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '打开文件',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 打开文件
  void _openFile(BuildContext context, String url) async {
    try {
      if (await canLaunch(url)) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开文件: $url')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开文件失败: ${e.toString()}')));
    }
  }

  // 新增：根据消息类型显示本地/网络图片
  Widget _buildImageWidget(BuildContext context) {
    // 优先显示本地图片（上传过程中）
    if (message.localImagePath != null) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageViewerPage(
                imageUrl: message.imageUrl ?? '',
                localImagePath: message.localImagePath,
              ),
            ),
          );
        },
        child: Image.file(
          File(message.localImagePath!),
          fit: BoxFit.cover,
          height: 200,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(height: 8),
                  Text('本地图片加载失败'),
                ],
              ),
            );
          },
        ),
      );
    }

    // 显示网络图片（上传完成后或历史消息）
    return GestureDetector(
      onTap: () {
        if (message.imageUrl != null && message.imageUrl!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ImageViewerPage(imageUrl: message.imageUrl!),
            ),
          );
        }
      },
      child: Image.network(
        message.imageUrl!,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        (loadingProgress.expectedTotalBytes ?? 1)
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(height: 8),
                Text('图片加载失败'),
              ],
            ),
          );
        },
      ),
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

  // 构建AI消息
  Widget _buildAIMessage(Color textColor) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: message.fullText,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
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
          if (message.fullText.isEmpty) const SizedBox(height: 10),
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

  // 实现AI消息操作按钮（添加复制回调）
  Widget _buildAIActions(ChatMessage message) {
    if (isMultiSelectMode) {
      return const SizedBox();
    }

    // 新增：判断AI是否正在生成回复
    bool isGenerating = message.isGenerating;
    bool isPlaying = this.isPlaying;
    Function(String messageId, String fullText)? onPlayTextToSpeech =
        this.onPlayTextToSpeech;
    Function()? onStopTextToSpeech = this.onStopTextToSpeech;

    // 保留原有判断逻辑，可根据实际需求调整
    bool isResponding = message.messageId != null && message.fullText.isEmpty;
    final bool isAIDisplaying =
        !message.loading &&
        message.messageId != null &&
        message.fullText.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          // 生成中：只显示停止按钮
          if (isGenerating)
            _iconButton(
              'assets/chat/dingzhi.png',
              onPressed: () {
                onStop?.call(message.messageId ?? '');
              },
            )
          // 生成完成：显示所有功能按钮
          else ...[
            _iconButton(
              isPlaying ? 'assets/chat/voice.png' : 'assets/chat/stop.png',
              onPressed: () {
                if (isPlaying) {
                  onStopTextToSpeech?.call();
                } else {
                  onPlayTextToSpeech?.call(
                    message.messageId!,
                    message.fullText,
                  );
                }
              },
            ),
            const SizedBox(width: 15),
            _iconButton(
              'assets/chat/copy.png',
              onPressed: () => _copyToClipboard(message.fullText),
            ),
            // 只在最后一条消息显示update图标
            if (isLastMessage) ...[
              const SizedBox(width: 15),
              _iconButton('assets/chat/update.png', onPressed: onUpdate),
            ],
            const SizedBox(width: 15),
            _iconButton(
              'assets/chat/share.png',
              onPressed: () => onShowShareDialog(message.messageId),
            ),
            // if (isLastMessage) ...[
            //   const SizedBox(width: 15),
            //   _iconButton(
            //     'assets/chat/dingzhi.png',
            //     onPressed: () => onStop?.call(message.messageId ?? ''),
            //   ),
            // ],
          ],
        ],
      ),
    );
  }

  // 根据messageId获取消息内容并请求语音转换
  // Future<void> _convertTextToSpeech(String messageId, String fulltext) async {
  //   await TokenManager().init();
  //   final token = TokenManager().getToken();

  //   debugPrint('id$messageId$fulltext');
  //   final message = await http.post(
  //     'chat/api_server/api/tts',
  //     data: {"message_id": messageId, "text": fulltext},
  //   );
  //   // debugPrint('message$message');
  //   // final audiopir = await http.get('voice/audio/stream/$messageId');
  //   // debugPrint('message$audiopir');
  //   final player = AudioPlayer();
  //   final audioUrl =
  //       "http://192.168.1.127:12111/api/v1/voice/audio/stream/$messageId?token=$token";
  //   await player.play(UrlSource(audioUrl));
  //   // // debugPrint('messageid$messageid');
  // }

  // 复制到剪贴板的实现方法
  Future<void> _copyToClipboard(String text) async {
    if (text.isEmpty) {
      // _showToast('没有可复制的内容');
      ToastUtil.showError('没有可复制的内容');
      return;
    }

    try {
      await FlutterClipboard.copy(text);
      // _showToast('复制成功');
      ToastUtil.showSuccess('复制成功');
    } on PlatformException catch (e) {
      ToastUtil.showError('复制失败');
      print('复制失败: $e');
    }
  }

  // 实现用户消息操作按钮（添加复制回调）
  Widget _buildUserActions(ChatMessage message) {
    // 注意添加message参数
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 复制按钮添加点击事件
          _iconButton(
            'assets/chat/copy.png',
            onPressed: () => _copyToClipboard(message.fullText),
          ),
          const SizedBox(width: 15),
          _iconButton(
            'assets/chat/share.png',
            onPressed: () => onShowShareDialog(message.messageId),
          ),
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
  Widget _iconButton(String asset, {VoidCallback? onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        // 白色圆形背景
        width: 25,
        height: 25,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle, // 矩形形状
          borderRadius: BorderRadius.all(Radius.circular(6)), // 圆角半径，可根据需要调整
          // 可选：添加轻微阴影增强立体感
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 1, spreadRadius: 0.5),
          ],
        ),
        // 图标居中显示
        child: Center(
          child: Image.asset(
            asset,
            width: 15,
            height: 15,
            color: const Color(0xFF8E8E93),
          ),
        ),
      ),
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
