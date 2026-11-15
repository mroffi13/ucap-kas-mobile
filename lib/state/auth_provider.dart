import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../data/models/auth_user.dart';
import '../data/models/workspace.dart';
import '../data/repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  guest,
  unauthenticated,
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final List<Workspace> workspaces;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.workspaces = const [],
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool clearUser = false,
    List<Workspace>? workspaces,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      workspaces: workspaces ?? this.workspaces,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return const EncryptedSecureTokenStore();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(secureTokenStoreProvider);
  return ApiClient(
    baseUrl: ApiClient.defaultBaseUrl(),
    tokenStore: store,
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return RemoteAuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(secureTokenStoreProvider),
  );
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<bool> restoreSession() async {
    final repo = ref.read(authRepositoryProvider);
    final bundle = await repo.tryRestoreSession();
    if (bundle != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: bundle.user,
        workspaces: bundle.workspaces,
      );
      return true;
    }
    if (state.status == AuthStatus.initial) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
    return false;
  }

  Future<bool> signInWithGoogle({required String selectedFocus}) async {
    if (state.isLoading) return false;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final bundle = await repo.signInWithGoogle(selectedFocus: selectedFocus);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: bundle.user,
        workspaces: bundle.workspaces,
      );
      return true;
    } on AuthCancelledException {
      state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
      return false;
    } on ApiException catch (e) {
      debugPrint('[UcapKas Auth] ApiException: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } on PlatformException catch (e) {
      debugPrint('[UcapKas Auth] GoogleSignIn PlatformException: ${e.code} | ${e.message} | ${e.details}');
      final raw = '${e.code} ${e.message ?? ''} ${e.details ?? ''}';
      String friendly = 'Gagal masuk Google (${e.code}).';
      if (raw.contains('10:') || raw.contains('10,')) {
        friendly =
            'Kode 10 Google OAuth: Pastikan SHA-1 debug & package id.ucapkas.ucapkas_app sudah sesuai di Google Cloud Console.';
      } else if (raw.contains('12500')) {
        friendly =
            'Kode 12500: Pastikan email akun Google Anda sudah didaftarkan di Test Users pada OAuth Consent Screen.';
      }
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: friendly,
      );
      return false;
    } catch (e) {
      debugPrint('[UcapKas Auth] Network/Unknown error: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Belum dapat terhubung ke server UcapKas. Periksa koneksi Anda.',
      );
      return false;
    }
  }

  void enterGuestMode() {
    state = const AuthState(
      status: AuthStatus.guest,
      workspaces: [],
    );
  }

  void updateWorkspaces(List<Workspace> workspaces) {
    if (!state.isAuthenticated || workspaces.isEmpty) return;
    state = state.copyWith(workspaces: workspaces, clearError: true);
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
