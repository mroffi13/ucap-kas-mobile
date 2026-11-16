import 'workspace.dart';

class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String avatarUrl;
  final String planTier;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl = '',
    this.planTier = 'starter',
  });

  bool get isPro => planTier == 'umkm_pro' || planTier == 'keluarga_pro';

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'UK';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  String get shortPlanBadge {
    switch (planTier) {
      case 'umkm_pro':
        return 'Paket Usaha Pro';
      case 'keluarga_pro':
        return 'Paket Keluarga Pro';
      default:
        return 'Paket Starter';
    }
  }

  String get planLabel {
    switch (planTier) {
      case 'umkm_pro':
        return 'Paket Usaha Pro · Tanpa Batas';
      case 'keluarga_pro':
        return 'Paket Kas Rumah Tangga Pro';
      default:
        return 'Paket Starter Gratis · AI 4x/mgg (15x/bln)';
    }
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      planTier: (json['plan_tier'] ?? 'starter').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'plan_tier': planTier,
      };
}

class AuthSessionBundle {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AuthUser user;
  final List<Workspace> workspaces;

  const AuthSessionBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
    required this.workspaces,
  });

  factory AuthSessionBundle.fromJson(Map<String, dynamic> json) {
    final rawWorkspaces = (json['workspaces'] as List<dynamic>? ?? const []);
    return AuthSessionBundle(
      accessToken: (json['access_token'] ?? '').toString(),
      refreshToken: (json['refresh_token'] ?? '').toString(),
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 900,
      user: AuthUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? const {}),
      ),
      workspaces: rawWorkspaces
          .map((item) => Workspace.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
