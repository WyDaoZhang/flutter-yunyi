import 'package:demo1/pages/home/sinkaf.dart';
import 'package:demo1/pages/login/enroll.dart';
import 'package:demo1/pages/home/index.dart';
import 'package:demo1/pages/login/login.dart';
import 'package:demo1/pages/setting/email.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(routes: {'/': (context) => ChatPage()}, initialRoute: '/'),
  );
}
