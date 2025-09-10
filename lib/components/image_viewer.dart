import 'package:demo1/utils/toast.dart';
import 'package:flutter/material.dart';
import 'dart:io';
// import 'package:gallery_saver/gallery_saver.dart';
import 'package:dio/dio.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
// import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            child: PhotoView(
              imageProvider: widget.localImagePath != null
                  ? FileImage(File(widget.localImagePath!))
                  : NetworkImage(widget.imageUrl),
              minScale: PhotoViewComputedScale.contained * 0.1, // 允许缩小到原图的10%
              maxScale: PhotoViewComputedScale.covered * 10.0, // 允许放大到原图的10倍
              initialScale: PhotoViewComputedScale.contained,
              loadingBuilder: (context, event) {
                if (event == null) return Container();
                return Center(
                  child: CircularProgressIndicator(
                    value: event.expectedTotalBytes != null
                        ? event.cumulativeBytesLoaded /
                              (event.expectedTotalBytes ?? 1)
                        : null,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorWidget();
              },
              backgroundDecoration: BoxDecoration(color: Colors.transparent),
              enableRotation: false, // 可选：禁用旋转功能
              heroAttributes: PhotoViewHeroAttributes(
                tag: widget.imageUrl,
              ), // 可选：添加hero动画
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
