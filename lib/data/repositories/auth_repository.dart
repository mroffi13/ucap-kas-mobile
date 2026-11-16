import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../models/auth_user.dart';
import '../models/workspace.dart';

class EncryptedSecureTokenStore implements SecureTokenStore {
  static const String _kAccessToken = 'ucapkas_access_token_v1';
  static const String _kRefreshToken = 'ucapkas_refresh_token_v1';

  final FlutterSecureStorage _storage;

  const EncryptedSecureTokenStore([
    FlutterSecureStorage? storage,
  ]) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

abstract class AuthRepository {
  Future<AuthSessionBundle?> tryRestoreSession();
  Future<AuthSessionBundle> signInWithGoogle({required String selectedFocus});
  Future<void> signOut();
}

class RemoteAuthRepository implements AuthRepository {
  final ApiClient apiClient;
  final SecureTokenStore tokenStore;
  final GoogleSignIn _googleSignIn;

  RemoteAuthRepository({
    required this.apiClient,
    required this.tokenStore,
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              serverClientId: AppConfig.googleServerClientId.isEmpty
                  ? null
                  : AppConfig.googleServerClientId,
            );

  @override
  Future<AuthSessionBundle?> tryRestoreSession() async {
    final existingRefresh = await tokenStore.readRefreshToken();
    if (existingRefresh == null || existingRefresh.isEmpty) {
      return null;
    }
    try {
      final meData = await apiClient.getAuthenticated('/api/v1/auth/me');
      final accessToken = await tokenStore.readAccessToken() ?? '';
      final refreshToken = await tokenStore.readRefreshToken() ?? '';
      final rawWorkspaces = (meData['workspaces'] as List<dynamic>? ?? const []);
      return AuthSessionBundle(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: 900,
        user: AuthUser.fromJson(
          Map<String, dynamic>.from(meData['user'] as Map? ?? const {}),
        ),
        workspaces: rawWorkspaces
            .map((w) => Workspace.fromJson(Map<String, dynamic>.from(w as Map)))
            .toList(),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await tokenStore.clearTokens();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthSessionBundle> signInWithGoogle({
    required String selectedFocus,
  }) async {
    String? idToken;
    String? photoUrl;

    const useDevMockGoogle = bool.fromEnvironment('USE_DEV_MOCK_GOOGLE');
    if (kDebugMode && useDevMockGoogle) {
      idToken = 'dev_mock:budi.usaha@gmail.com:Budi Santoso';
    } else {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthCancelledException();
      }
      photoUrl = account.photoUrl;
      final auth = await account.authentication;
      idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          statusCode: 400,
          code: 'MISSING_GOOGLE_ID_TOKEN',
          message:
              'Token identitas Google belum tersedia. Pastikan GOOGLE_SERVER_CLIENT_ID sudah dikonfigurasi.',
        );
      }
    }

    final data = await apiClient.postPublic(
      '/api/v1/auth/google',
      body: {
        'id_token': idToken,
        'selected_focus': selectedFocus,
        'device_name': defaultTargetPlatform.name,
        if (photoUrl != null && photoUrl.isNotEmpty) 'avatar_url': photoUrl,
      },
    );

    final bundle = AuthSessionBundle.fromJson(data);
    await tokenStore.saveTokens(
      accessToken: bundle.accessToken,
      refreshToken: bundle.refreshToken,
    );
    return bundle;
  }

  @override
  Future<void> signOut() async {
    final refreshToken = await tokenStore.readRefreshToken();
    try {
      await apiClient.postAuthenticated(
        '/api/v1/auth/logout',
        body: {
          if (refreshToken != null) 'refresh_token': refreshToken,
        },
      );
    } catch (_) {
      // Tetap lanjut hapus kredensial lokal meskipun jaringan sedang offline
    } finally {
      await tokenStore.clearTokens();
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }
}
