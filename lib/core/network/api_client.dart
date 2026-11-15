import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

abstract class SecureTokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clearTokens();
}

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiClient {
  String _activeBaseUrl;
  final List<String> _fallbackBaseUrls;
  final SecureTokenStore tokenStore;
  final http.Client _httpClient;
  Completer<bool>? _refreshCompleter;

  ApiClient({
    required String baseUrl,
    required this.tokenStore,
    List<String>? fallbackBaseUrls,
    http.Client? httpClient,
  })  : _activeBaseUrl = baseUrl,
        _fallbackBaseUrls = fallbackBaseUrls ?? _defaultCandidateUrls(baseUrl),
        _httpClient = httpClient ?? http.Client();

  static String defaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return 'http://192.168.1.8:8080';
  }

  static List<String> _defaultCandidateUrls(String primary) {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return [envUrl];
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // 1. 192.168.1.8:8080 (works on physical phone via local Wi-Fi LAN without USB)
      // 2. 127.0.0.1:8080 (works on physical phone via `adb reverse tcp:8080 tcp:8080`)
      // 3. 10.0.2.2:8080 (works on Android Emulator)
      return const [
        'http://192.168.1.8:8080',
        'http://127.0.0.1:8080',
        'http://10.0.2.2:8080',
      ];
    }
    return [primary];
  }

  Future<http.Response> _sendWithHostFallback(
    Future<http.Response> Function(String baseUrl) requestFn,
  ) async {
    final candidates = <String>[
      _activeBaseUrl,
      for (final url in _fallbackBaseUrls)
        if (url != _activeBaseUrl) url,
    ];

    Object? lastError;
    for (final candidate in candidates) {
      try {
        final res = await requestFn(candidate);
        _activeBaseUrl = candidate;
        return res;
      } on SocketException catch (e) {
        lastError = e;
        continue;
      } on TimeoutException catch (e) {
        lastError = e;
        continue;
      } on http.ClientException catch (e) {
        lastError = e;
        continue;
      }
    }
    throw lastError ??
        const SocketException('Tidak dapat menghubungi server UcapKas');
  }

  Future<Map<String, dynamic>> postPublic(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final res = await _sendWithHostFallback((base) {
      return _httpClient
          .post(
            Uri.parse('$base$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));
    });
    return _decodeEnvelope(res);
  }

  Future<Map<String, dynamic>> getAuthenticated(String path) async {
    return _sendWithRefreshRetry((token) {
      return _sendWithHostFallback((base) {
        return _httpClient
            .get(
              Uri.parse('$base$path'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 6));
      });
    });
  }

  Future<Map<String, dynamic>> postAuthenticated(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _sendWithRefreshRetry((token) {
      return _sendWithHostFallback((base) {
        return _httpClient
            .post(
              Uri.parse('$base$path'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body ?? const <String, dynamic>{}),
            )
            .timeout(const Duration(seconds: 6));
      });
    });
  }

  Future<Map<String, dynamic>> patchAuthenticated(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _sendWithRefreshRetry((token) {
      return _sendWithHostFallback((base) {
        return _httpClient
            .patch(
              Uri.parse('$base$path'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body ?? const <String, dynamic>{}),
            )
            .timeout(const Duration(seconds: 6));
      });
    });
  }

  Future<Map<String, dynamic>> deleteAuthenticated(String path) async {
    return _sendWithRefreshRetry((token) {
      return _sendWithHostFallback((base) {
        return _httpClient
            .delete(
              Uri.parse('$base$path'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 6));
      });
    });
  }

  Future<Map<String, dynamic>> _sendWithRefreshRetry(
    Future<http.Response> Function(String accessToken) sender,
  ) async {
    final token = await tokenStore.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        code: 'NO_TOKEN',
        message: 'Sesi belum tersedia.',
      );
    }

    var res = await sender(token);
    if (res.statusCode == 401) {
      final refreshed = await _trySingleFlightRefresh();
      if (refreshed) {
        final nextToken = await tokenStore.readAccessToken();
        if (nextToken != null && nextToken.isNotEmpty) {
          res = await sender(nextToken);
        }
      }
    }
    return _decodeEnvelope(res);
  }

  Future<bool> _trySingleFlightRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final refreshToken = await tokenStore.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await tokenStore.clearTokens();
        completer.complete(false);
        return false;
      }
      final res = await _sendWithHostFallback((base) {
        return _httpClient
            .post(
              Uri.parse('$base/api/v1/auth/refresh'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 6));
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final data = Map<String, dynamic>.from(decoded['data'] as Map);
        await tokenStore.saveTokens(
          accessToken: data['access_token'].toString(),
          refreshToken: data['refresh_token'].toString(),
        );
        completer.complete(true);
        return true;
      }

      await tokenStore.clearTokens();
      completer.complete(false);
      return false;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Map<String, dynamic> _decodeEnvelope(http.Response res) {
    Map<String, dynamic> parsed = const {};
    if (res.body.isNotEmpty) {
      try {
        parsed = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // Non-JSON upstream error fallback
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = parsed['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return const {};
    }

    final errObj = parsed['error'];
    if (errObj is Map) {
      throw ApiException(
        statusCode: res.statusCode,
        code: (errObj['code'] ?? 'API_ERROR').toString(),
        message: (errObj['message'] ?? 'Terjadi kendala pada server.').toString(),
      );
    }
    throw ApiException(
      statusCode: res.statusCode,
      code: 'HTTP_${res.statusCode}',
      message: 'Gagal terhubung ke server (${res.statusCode}).',
    );
  }
}
