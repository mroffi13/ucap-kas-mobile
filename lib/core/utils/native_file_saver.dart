import 'dart:io';

import 'package:flutter/services.dart';

class SavedPdfResult {
  final String filePath;
  final String displayLocation;
  final String? contentUri;

  const SavedPdfResult({
    required this.filePath,
    required this.displayLocation,
    this.contentUri,
  });
}

/// Saves, opens, and shares generated/downloaded PDF files via the native
/// `id.ucapkas.app/file_saver` MethodChannel, with a pure-Dart filesystem
/// fallback for desktop/test environments.
class NativeFileSaver {
  NativeFileSaver._();

  static const MethodChannel _channel = MethodChannel(
    'id.ucapkas.app/file_saver',
  );

  static Future<SavedPdfResult> savePdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'savePdf',
        {
          'bytes': bytes,
          'filename': filename,
        },
      );
      if (result != null && result['filePath'] != null) {
        return SavedPdfResult(
          filePath: result['filePath'] as String,
          displayLocation:
              (result['displayLocation'] as String?) ?? 'Folder Download',
          contentUri: result['contentUri'] as String?,
        );
      }
    } catch (_) {
      // Fall through to pure-Dart file write on desktop/test platforms.
    }

    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return SavedPdfResult(
      filePath: file.path,
      displayLocation: file.path,
    );
  }

  static Future<bool> openPdf(SavedPdfResult saved) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openPdf', {
        'filePath': saved.filePath,
        'contentUri': saved.contentUri,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sharePdf({
    required SavedPdfResult saved,
    required String text,
    required String title,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('sharePdf', {
        'filePath': saved.filePath,
        'contentUri': saved.contentUri,
        'text': text,
        'title': title,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> shareText({
    required String text,
    String title = 'Kirim Undangan via WhatsApp',
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('sharePdf', {
        'text': text,
        'title': title,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> pickLogoImage() async {
    try {
      final dataUri = await _channel.invokeMethod<String>('pickLogoImage');
      if (dataUri != null && dataUri.trim().isNotEmpty) {
        return dataUri.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
