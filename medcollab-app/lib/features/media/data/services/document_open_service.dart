import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Download chat documents with a real filename, then open in a PDF viewer/app.
abstract final class DocumentOpenService {
  static Future<void> open(
    BuildContext context, {
    required String url,
    String? fileName,
    String? mimeType,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast(context, 'Invalid document link');
      return;
    }

    if (kIsWeb) {
      await _launchExternal(context, uri);
      return;
    }

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Opening document…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final safeName = _safeFileName(fileName, url);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/vocle_$safeName';
      final file = File(path);

      final downloadUrl = _preferDirectCloudinaryUrl(url);
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          responseType: ResponseType.bytes,
          headers: const {'Accept': '*/*'},
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final response = await dio.get<List<int>>(downloadUrl);
      final bytes = response.data;
      final contentType =
          response.headers.value('content-type')?.toLowerCase() ?? '';
      if (bytes == null ||
          bytes.isEmpty ||
          contentType.contains('text/html') ||
          (response.statusCode != null && response.statusCode! >= 400)) {
        throw StateError('Bad download');
      }
      // PDF magic header when claiming PDF.
      if ((mimeType ?? '').contains('pdf') ||
          safeName.toLowerCase().endsWith('.pdf')) {
        final head = String.fromCharCodes(bytes.take(5));
        if (!head.startsWith('%PDF')) {
          throw StateError('Not a PDF payload');
        }
      }
      await file.writeAsBytes(bytes, flush: true);

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      final result = await OpenFilex.open(
        path,
        type: mimeType ?? _guessMime(safeName),
      );
      if (result.type != ResultType.done && context.mounted) {
        _toast(context, 'Downloaded, but no app can open this file');
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _toast(context, 'Could not open document');
      }
    }
  }

  /// Prefer raw/upload delivery URLs over broken image transforms / portals.
  static String _preferDirectCloudinaryUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (!uri.host.contains('cloudinary.com')) return url;
    final path = uri.path;
    // Rewrite .../image/upload/...pdf → .../raw/upload/...
    if (path.contains('/image/upload/') &&
        path.toLowerCase().endsWith('.pdf')) {
      return url.replaceFirst('/image/upload/', '/raw/upload/');
    }
    return url;
  }

  static String _safeFileName(String? fileName, String url) {
    var name = (fileName ?? '').trim();
    if (name.isEmpty) {
      final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
      final last = segments.isNotEmpty ? segments.last : 'document';
      name = last.contains('.') ? last : '$last.pdf';
    }
    name = name.replaceAll(RegExp(r'[^\w.\-() ]+'), '_');
    if (!name.contains('.')) name = '$name.pdf';
    if (name.length > 80) {
      final ext =
          name.contains('.') ? name.substring(name.lastIndexOf('.')) : '';
      name = '${name.substring(0, 60)}$ext';
    }
    return name;
  }

  static String? _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }

  static Future<void> _launchExternal(BuildContext context, Uri uri) async {
    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        final inApp = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        if (!inApp && context.mounted) {
          _toast(context, 'No app found to open this file');
        }
      }
    } catch (_) {
      if (context.mounted) {
        _toast(context, 'Could not open document');
      }
    }
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
