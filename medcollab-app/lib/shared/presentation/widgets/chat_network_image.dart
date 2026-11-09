import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';

/// Chat image with stable layout (avoids list jump) and optional local bytes.
class ChatNetworkImage extends StatefulWidget {
  const ChatNetworkImage({
    super.key,
    required this.imageUrl,
    this.localBytes,
    this.width = 220,
    this.height = 140,
    this.fit = BoxFit.cover,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final String imageUrl;
  final Uint8List? localBytes;
  final double width;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  State<ChatNetworkImage> createState() => _ChatNetworkImageState();
}

class _ChatNetworkImageState extends State<ChatNetworkImage> {
  static final Map<String, Uint8List> _memoryCache = {};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 45),
      responseType: ResponseType.bytes,
    ),
  );

  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ChatNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.localBytes != widget.localBytes) {
      _resolve();
    }
  }

  void _resolve() {
    final local = widget.localBytes;
    if (local != null && local.isNotEmpty) {
      setState(() {
        _bytes = local;
        _loading = false;
      });
      return;
    }

    final cached = _memoryCache[widget.imageUrl];
    if (cached != null) {
      setState(() {
        _bytes = cached;
        _loading = false;
      });
      return;
    }

    _loadNetwork();
  }

  Future<void> _loadNetwork() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _loading = false;
        _bytes = null;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await _dio.get<List<int>>(widget.imageUrl);
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw StateError('Empty image');
      }
      final bytes = Uint8List.fromList(data);
      _memoryCache[widget.imageUrl] = bytes;
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _bytes = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: _buildBody(),
      ),
    );

    if (widget.onTap == null) return child;
    return GestureDetector(onTap: widget.onTap, child: child);
  }

  Widget _buildBody() {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    if (_loading) {
      return ColoredBox(
        color: AppColors.surfaceVariant,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _loadNetwork,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}