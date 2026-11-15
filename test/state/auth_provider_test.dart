import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ucapkas_app/core/network/api_client.dart';
import 'package:ucapkas_app/data/models/auth_user.dart';
import 'package:ucapkas_app/data/models/workspace.dart';
import 'package:ucapkas_app/data/repositories/auth_repository.dart';
import 'package:ucapkas_app/state/auth_provider.dart';
import 'package:ucapkas_app/state/ledger_providers.dart';

class MemoryTokenStore implements SecureTokenStore {
  String? access;
  String? refresh;

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }
}

class FakeSuccessAuthRepository implements AuthRepository {
  String? lastSelectedFocus;
  bool signedOut = false;

  @override
  Future<AuthSessionBundle?> tryRestoreSession() async => null;

  @override
  Future<AuthSessionBundle> signInWithGoogle({
    required String selectedFocus,
  }) async {
    lastSelectedFocus = selectedFocus;
    return AuthSessionBundle(
      accessToken: 'jwt_access_123',
      refreshToken: 'rft_456',
      expiresIn: 900,
      user: const AuthUser(
        id: '01932c00-0000-7000-8000-000000000001',
        email: 'budi@bengkeljaya.id',
        fullName: 'Budi Santoso',
        planTier: 'starter',
      ),
      workspaces: [
        Workspace(
          id: '01932c00-0000-7000-8000-000000000002',
          name: selectedFocus == 'rumah_tangga'
              ? 'Dapur Rumah Tangga'
              : 'Usaha Saya (UMKM)',
          shortName:
              selectedFocus == 'rumah_tangga' ? 'Dapur Rumah' : 'Usaha Saya',
          balance: 0,
          monthlyInflow: 0,
          monthlyOutflow: 0,
          isPro: false,
          focusType: selectedFocus,
          role: 'owner',
        ),
      ],
    );
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  test('AuthNotifier signInWithGoogle updates user, workspaces, and signOut resets state', () async {
    final fakeRepo = FakeSuccessAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(authProvider.notifier)
        .signInWithGoogle(selectedFocus: 'rumah_tangga');

    expect(ok, isTrue);
    expect(fakeRepo.lastSelectedFocus, 'rumah_tangga');

    final authState = container.read(authProvider);
    expect(authState.isAuthenticated, isTrue);
    expect(authState.user?.fullName, 'Budi Santoso');
    expect(authState.user?.initials, 'BS');

    final activeWs = container.read(activeWorkspaceProvider);
    expect(activeWs.name, 'Dapur Rumah Tangga');
    expect(activeWs.focusType, 'rumah_tangga');

    await container.read(authProvider.notifier).signOut();
    expect(fakeRepo.signedOut, isTrue);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('ApiClient automatically rotates refresh_token on 401 and retries request', () async {
    final store = MemoryTokenStore()
      ..access = 'expired_jwt'
      ..refresh = 'rft_initial';

    int meCalls = 0;
    int refreshCalls = 0;

    final mockHttp = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/me') {
        meCalls++;
        if (request.headers['Authorization'] == 'Bearer expired_jwt') {
          return http.Response(
            jsonEncode({
              'error': {'code': 'TOKEN_EXPIRED', 'message': 'Expired'}
            }),
            401,
          );
        }
        if (request.headers['Authorization'] == 'Bearer rotated_jwt_new') {
          return http.Response(
            jsonEncode({
              'data': {
                'user': {
                  'id': '01932c00-0000-7000-8000-000000000001',
                  'email': 'budi@gmail.com',
                  'full_name': 'Budi Santoso',
                  'plan_tier': 'starter',
                },
                'workspaces': const [],
              }
            }),
            200,
          );
        }
      }
      if (request.url.path == '/api/v1/auth/refresh') {
        refreshCalls++;
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': 'rotated_jwt_new',
              'refresh_token': 'rft_rotated_new',
              'expires_in': 900,
            }
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    final client = ApiClient(
      baseUrl: 'http://127.0.0.1:8080',
      tokenStore: store,
      httpClient: mockHttp,
    );

    final data = await client.getAuthenticated('/api/v1/auth/me');
    expect(refreshCalls, 1);
    expect(meCalls, 2);
    expect(store.access, 'rotated_jwt_new');
    expect(store.refresh, 'rft_rotated_new');
    expect((data['user'] as Map)['email'], 'budi@gmail.com');
  });
}
