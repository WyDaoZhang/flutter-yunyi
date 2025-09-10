import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class StorageUtil {
  static const String _HISTORY_MESSAGES_KEY = 'chat_history_messages';
  static const String _EARLIEST_MESSAGE_ID_KEY = 'earliest_message_id';
  // 添加新的存储键
  static const String _MESSAGES_KEY = 'chat_messages';
  static const String _PENDING_RESPONSE_KEY = 'pending_response_info';
  // 新增：记录用户是否已下拉加载历史消息的存储键
  static const String _HAS_PULLED_DOWN_KEY = 'has_pulled_down_history';

  // 保存历史消息到本地
  static Future<void> saveHistoryMessages(List<dynamic> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(messages);
      await prefs.setString(_HISTORY_MESSAGES_KEY, jsonString);
      print('历史消息保存成功');
    } catch (e) {
      print('保存历史消息失败: $e');
    }
  }

  // 从本地读取历史消息
  static Future<List<dynamic>?> getHistoryMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_HISTORY_MESSAGES_KEY);
      if (jsonString != null) {
        final messages = json.decode(jsonString) as List<dynamic>;
        print('从本地读取历史消息成功，共 ${messages.length} 条');
        return messages;
      }
    } catch (e) {
      print('读取历史消息失败: $e');
    }
    return null;
  }

  // 保存最早消息的ID
  static Future<void> saveEarliestMessageId(String? messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (messageId != null) {
        await prefs.setString(_EARLIEST_MESSAGE_ID_KEY, messageId);
      } else {
        await prefs.remove(_EARLIEST_MESSAGE_ID_KEY);
      }
      print('最早消息ID保存成功');
    } catch (e) {
      print('保存最早消息ID失败: $e');
    }
  }

  // 获取最早消息的ID
  static Future<String?> getEarliestMessageId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_EARLIEST_MESSAGE_ID_KEY);
    } catch (e) {
      print('获取最早消息ID失败: $e');
    }
    return null;
  }

  // 清除所有本地历史消息
  static Future<void> clearHistoryMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_HISTORY_MESSAGES_KEY);
      await prefs.remove(_EARLIEST_MESSAGE_ID_KEY);
      await prefs.remove(_MESSAGES_KEY);
      await prefs.remove(_PENDING_RESPONSE_KEY);
      await prefs.remove(_HAS_PULLED_DOWN_KEY); // 同时清除下拉标记
      print('本地历史消息已清除');
    } catch (e) {
      print('清除本地历史消息失败: $e');
    }
  }

  // 新增：保存消息列表
  static Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(messages);
      await prefs.setString(_MESSAGES_KEY, jsonString);
      print('消息列表保存成功');
    } catch (e) {
      print('保存消息列表失败: $e');
    }
  }

  // 新增：获取消息列表
  static Future<List<Map<String, dynamic>>?> getMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_MESSAGES_KEY);
      if (jsonString != null) {
        final List<dynamic> messageList = json.decode(jsonString);
        return messageList.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('获取消息列表失败: $e');
    }
    return null;
  }

  // 新增：保存未完成的AI回复信息
  static Future<void> savePendingResponseInfo(Map<String, dynamic> info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(info);
      await prefs.setString(_PENDING_RESPONSE_KEY, jsonString);
      print('未完成的AI回复信息保存成功');
    } catch (e) {
      print('保存未完成的AI回复信息失败: $e');
    }
  }

  // 新增：获取未完成的AI回复信息
  static Future<Map<String, dynamic>?> getPendingResponseInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_PENDING_RESPONSE_KEY);
      if (jsonString != null) {
        return json.decode(jsonString) as Map<String, dynamic>;
      }
    } catch (e) {
      print('获取未完成的AI回复信息失败: $e');
    }
    return null;
  }

  // 新增：保存用户已下拉加载历史消息的标记
  static Future<void> saveHasPulledDownHistory(bool hasPulledDown) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_HAS_PULLED_DOWN_KEY, hasPulledDown);
      print('下拉加载标记保存成功');
    } catch (e) {
      print('保存下拉加载标记失败: $e');
    }
  }

  // 新增：获取用户是否已下拉加载历史消息的标记
  static Future<bool> getHasPulledDownHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_HAS_PULLED_DOWN_KEY) ?? false;
    } catch (e) {
      print('获取下拉加载标记失败: $e');
    }
    return false;
  }
}
