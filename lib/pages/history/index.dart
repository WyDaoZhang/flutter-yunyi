import 'package:flutter/material.dart';

/// 历史对话数据模型
class HistoryItem {
  final String id; // 对话ID，用于后续精准跳转
  final String title; // 对话标题
  final String content; // 对话内容预览
  final String time; // 对话时间

  HistoryItem({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
  });
}

/// 历史对话页面
/// 展示用户的历史对话列表，支持点击跳转功能
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // 模拟历史对话数据
  final List<HistoryItem> _historyItems = [
    HistoryItem(
      id: '1',
      title: '学信网功能及使用场景介绍',
      content: '学信网功能及使用场景介绍，包括学籍学历查询认证及相关服务。',
      time: '近一周',
    ),
    HistoryItem(
      id: '2',
      title: '用户提问模糊',
      content: '用户提问模糊，系统请求更清晰的信息以提供帮助。',
      time: '近一周',
    ),
    // 可以添加更多模拟数据
  ];

  // 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 跳转到主页
  /// [id] 对话ID，用于后续精准跳转
  void _navigateToHome(String id) {
    // 当前仅跳转到主页，后续可根据id参数实现精准跳转
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (context) => const HomePage()),
    // );
    // 实际应用中可使用命名路由并传递参数
    // Navigator.pushReplacementNamed(context, '/home', arguments: {'id': id});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 设置背景图片
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/login/3.png'), // 使用项目统一背景图
            fit: BoxFit.cover, // 图片覆盖整个容器
          ),
        ),
        // 使用Stack实现层叠布局
        child: SafeArea(
          child: Stack(
            children: [
              // 返回按钮
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.black54,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),

              // 主内容区域
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20), // 内边距
                child: Column(
                  children: [
                    // 页面标题
                    const Text(
                      '历史对话',
                      style: TextStyle(
                        fontSize: 24, // 标题文字大小
                        fontWeight: FontWeight.bold, // 加粗
                        color: Colors.black, // 文字颜色
                      ),
                    ),

                    const SizedBox(height: 20), // 间距
                    // 搜索栏和筛选
                    Row(
                      children: [
                        // 搜索框
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white, // 白色背景
                              borderRadius: BorderRadius.circular(30), // 圆角
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2), // 阴影颜色
                                  blurRadius: 5, // 模糊半径
                                  offset: const Offset(0, 2), // 阴影偏移
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController, // 搜索控制器
                              decoration: InputDecoration(
                                hintText: '搜索', // 提示文字
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                ), // 提示文字样式
                                border: InputBorder.none, // 无边框
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey[400],
                                ), // 搜索图标
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ), // 内边距
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10), // 间距
                        // 筛选下拉框
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white, // 白色背景
                            borderRadius: BorderRadius.circular(30), // 圆角
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2), // 阴影颜色
                                blurRadius: 5, // 模糊半径
                                offset: const Offset(0, 2), // 阴影偏移
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              value: '全部', // 当前选中值
                              items: const [
                                DropdownMenuItem(
                                  value: '全部',
                                  child: Text('全部'),
                                ),
                                DropdownMenuItem(
                                  value: '近一周',
                                  child: Text('近一周'),
                                ),
                                DropdownMenuItem(
                                  value: '近一月',
                                  child: Text('近一月'),
                                ),
                                DropdownMenuItem(
                                  value: '近一年',
                                  child: Text('近一年'),
                                ),
                              ],
                              onChanged: (value) {}, // 选择事件
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.black,
                              ), // 下拉图标
                              style: const TextStyle(
                                color: Colors.black, // 文字颜色
                                fontSize: 14, // 文字大小
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20), // 间距
                    // 历史对话列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: _historyItems.length, // 列表项数量
                        itemBuilder: (context, index) {
                          final item = _historyItems[index]; // 获取当前项数据
                          return _buildHistoryItem(item); // 构建列表项
                        },
                      ),
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

  /// 构建历史对话列表项
  Widget _buildHistoryItem(HistoryItem item) {
    return GestureDetector(
      onTap: () => _navigateToHome(item.id), // 点击跳转到主页
      child: Container(
        margin: const EdgeInsets.only(bottom: 15), // 底部外边距
        padding: const EdgeInsets.all(15), // 内边距
        decoration: BoxDecoration(
          color: Colors.white, // 白色背景
          borderRadius: BorderRadius.circular(10), // 圆角
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2), // 阴影颜色
              blurRadius: 3, // 模糊半径
              offset: const Offset(0, 2), // 阴影偏移
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
          children: [
            // 对话标题
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16, // 标题文字大小
                fontWeight: FontWeight.bold, // 加粗
                color: Colors.black, // 文字颜色
              ),
              maxLines: 1, // 最多显示1行
              overflow: TextOverflow.ellipsis, // 超出部分省略号
            ),

            const SizedBox(height: 8), // 间距
            // 对话内容预览
            Text(
              item.content,
              style: const TextStyle(
                fontSize: 14, // 内容文字大小
                color: Colors.grey, // 文字颜色
              ),
              maxLines: 2, // 最多显示2行
              overflow: TextOverflow.ellipsis, // 超出部分省略号
            ),

            const SizedBox(height: 8), // 间距
            // 时间
            Align(
              alignment: Alignment.centerRight, // 右对齐
              child: Text(
                item.time,
                style: const TextStyle(
                  fontSize: 12, // 时间文字大小
                  color: Colors.grey, // 文字颜色
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
