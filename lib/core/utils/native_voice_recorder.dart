import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Lightweight native AAC/M4A voice recorder using Android's built-in
/// MediaRecorder via MethodChannel (zero external KGP plugin warnings).
class NativeVoiceRecorder {
  static const MethodChannel _channel =
      MethodChannel('id.ucapkas.app/audio_recorder');

  Future<bool> hasPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> start() async {
    try {
      return await _channel.invokeMethod<String>('start');
    } catch (_) {
      return null;
    }
  }

  Future<String?> stopAndEncodeBase64() async {
    try {
      final path = await _channel.invokeMethod<String>('stop');
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          try {
            await file.delete();
          } catch (_) {}
          if (bytes.isNotEmpty) {
            return base64Encode(bytes);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  void dispose() {
    cancel();
  }
}
