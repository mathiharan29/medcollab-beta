import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Full-screen image preview with pinch-to-zoom.
class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({
    required this.imageUrl,
    this.title,
    super.key,
  });

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title != null ? Text(title!) : null,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(
              color: Colors.white54,
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
