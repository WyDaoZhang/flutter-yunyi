
import 'package:demo1/pages/login/word_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AgreementPage extends StatefulWidget {
  const AgreementPage({super.key});

  @override
  State<AgreementPage> createState() => _AgreementPageState();
}

class _AgreementPageState extends State<AgreementPage> {
  String title = '';
  String markData = '';

  @override
  void initState() {
    super.initState();
    // 获取路由参数
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)?.settings.arguments as Map?;
      if (arguments != null) {
        setState(() {
          title = arguments['title'] ?? '';
          // 根据标题选择不同内容
          markData = title == '用户协议'
              ? WordData.data['data1']!
              : WordData.data['data2']!;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 计算rpx转换 (1rpx ≈ 0.5px)
    final double rpx = MediaQuery.of(context).size.width / 750;

    // 定义统一字体大小常量
    final double baseFontSize = 24 * rpx;
    final double h1FontSize = 32 * rpx;
    final double h2FontSize = 28 * rpx;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/login/3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Container(
            padding: EdgeInsets.only(top: 50 * rpx),
            child: Column(
              children: [
                // 顶部导航栏
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48 * rpx),
                  child: Row(
                    children: [
                      // 返回按钮
                      GestureDetector(
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

                      // 标题
                      Expanded(
                        child: Center(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 32 * rpx,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 80 * rpx),
                    ],
                  ),
                ),
                SizedBox(height: 32 * rpx),

                // 协议内容区域
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48 * rpx),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 32 * rpx),
                      child: Markdown(
                        data: markData,
                        styleSheet: MarkdownStyleSheet(
                          // p: TextStyle(fontSize: baseFontSize, height: 1.5),
                          h1: TextStyle(
                            fontSize: h1FontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          h2: TextStyle(
                            fontSize: h2FontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          // 其他元素使用baseFontSize
                          listBullet: TextStyle(
                            fontSize: baseFontSize,
                            height: 1.5,
                          ),
                          // margin: EdgeInsets.symmetric(vertical: 16 * rpx),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
