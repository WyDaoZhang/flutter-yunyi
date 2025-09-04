import 'package:demo1/utils/toast.dart';
import 'package:flutter/material.dart';
import 'dart:io';
// import 'package:gallery_saver/gallery_saver.dart';
import 'package:dio/dio.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
// import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// import '../utils/toast_util.dart';

class ImageViewerPage extends StatefulWidget {
  final String imageUrl;
  final String? localImagePath;

  const ImageViewerPage({Key? key, required this.imageUrl, this.localImagePath})
    : super(key: key);

  @override
  _ImageViewerPageState createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸，用于后续设置图片缓存大小
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.download_outlined, color: Colors.white),
            onPressed: _downloadImage,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 图片显示区域
          Center(
            child: InteractiveViewer(
              // 降低最小缩放比例，增加最大缩放比例
              minScale: 0.1, // 允许缩小到原图的10%
              maxScale: 10.0, // 允许放大到原图的10倍
              // 启用边界对齐，确保图片在缩放后能够正确定位
              alignment: Alignment.center,
              panEnabled: true,
              scaleEnabled: true,
              child: widget.localImagePath != null
                  ? Image.file(
                      File(widget.localImagePath!),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high, // 设置高质量过滤
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorWidget();
                      },
                    )
                  : Image.network(
                      widget.imageUrl,
                      fit: BoxFit.contain,
                      // 根据屏幕尺寸设置缓存大小，确保清晰度
                      cacheWidth: screenWidth.toInt() * 2, // 缓存宽度设为屏幕宽度的2倍
                      cacheHeight: screenHeight.toInt() * 2, // 缓存高度设为屏幕高度的2倍
                      filterQuality: FilterQuality.high, // 设置高质量过滤
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorWidget();
                      },
                    ),
            ),
          ),
          // 下载进度指示器
          if (_isDownloading)
            Positioned(
              bottom: 50,
              left: 50,
              right: 50,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('正在下载图片...', style: TextStyle(color: Colors.white)),
                    SizedBox(height: 10),
                    LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 50),
          SizedBox(height: 16),
          Text('图片加载失败', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }

  Future<void> _downloadImage() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      // 检查存储权限
      if (await Permission.storage.request().isDenied) {
        ToastUtil.showError('需要存储权限才能下载图片');
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      // 如果是本地图片，直接保存
      if (widget.localImagePath != null) {
        final result = await GallerySaver.saveImage(widget.localImagePath!);
        if (result != null && result) {
          ToastUtil.showSuccess('图片已下载');
        } else {
          ToastUtil.showError('图片保存失败');
        }
      } else {
        // 如果是网络图片，下载后保存
        await _downloadAndSaveImage(widget.imageUrl);
      }
    } catch (e) {
      print('下载图片错误: $e');
      ToastUtil.showError('图片下载失败');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _downloadAndSaveImage(String imageUrl) async {
    try {
      // 创建临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFilePath = '${tempDir.path}/$fileName';

      // 下载图片
      final dio = Dio();
      await dio.download(imageUrl, tempFilePath);

      // 保存到相册
      final result = await GallerySaver.saveImage(tempFilePath);
      if (result != null && result) {
        ToastUtil.showSuccess('图片已保存到相册');
      } else {
        ToastUtil.showError('图片保存失败');
      }
    } catch (e) {
      print('下载网络图片错误: $e');
      throw e;
    }
  }
}
