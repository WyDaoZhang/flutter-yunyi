import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastUtil {
  /// 成功的提示
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      // 提示持续时间较短。
      toastLength: Toast.LENGTH_SHORT,
      // 提示信息从屏幕底部弹出。
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.white,
      textColor: Colors.black,
      webPosition: 'center',
      webBgColor: '#5591af',
    );
  }

  /// 失败的提示
  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      webPosition: 'center',
      webBgColor: '#ff0000',
    );
  }

  /// 正常消息提示
  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
      webPosition: 'center',
      webBgColor: '#0000ff',
    );
  }
}
