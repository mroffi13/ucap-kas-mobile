import '../../core/network/api_client.dart';
import '../models/cash_transaction.dart';
import '../models/workspace.dart';

class LedgerTransactionsResult {
  final List<CashTransaction> transactions;
  final List<Workspace> workspaces;

  const LedgerTransactionsResult({
    required this.transactions,
    required this.workspaces,
  });
}

class CreateTransactionResult {
  final CashTransaction transaction;
  final List<Workspace> workspaces;

  const CreateTransactionResult({
    required this.transaction,
    required this.workspaces,
  });
}

class WorkspaceMutationResult {
  final Workspace? workspace;
  final List<Workspace> workspaces;

  const WorkspaceMutationResult({
    required this.workspace,
    required this.workspaces,
  });
}

class WorkspaceMemberModel {
  final String userId;
  final String email;
  final String fullName;
  final String avatarUrl;
  final String role;
  final String roleLabel;
  final bool isOwner;
  final String joinedAt;

  const WorkspaceMemberModel({
    required this.userId,
    required this.email,
    required this.fullName,
    this.avatarUrl = '',
    required this.role,
    required this.roleLabel,
    required this.isOwner,
    this.joinedAt = '',
  });

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'UK';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  factory WorkspaceMemberModel.fromJson(Map<String, dynamic> json) {
    final role = (json['role'] ?? 'editor').toString();
    return WorkspaceMemberModel(
      userId: (json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Anggota').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      role: role,
      roleLabel: (json['role_label'] ?? (role == 'owner' ? 'Pemilik' : 'Admin'))
          .toString(),
      isOwner: json['is_owner'] as bool? ?? (role == 'owner'),
      joinedAt: (json['joined_at'] ?? '').toString(),
    );
  }
}

class WorkspaceInviteModel {
  final String token;
  final String inviteUrl;
  final String deepLink;
  final String role;
  final String roleLabel;
  final String expiresAt;
  final String waShareText;

  const WorkspaceInviteModel({
    required this.token,
    required this.inviteUrl,
    required this.deepLink,
    this.role = 'editor',
    this.roleLabel = 'Admin',
    required this.expiresAt,
    required this.waShareText,
  });

  factory WorkspaceInviteModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceInviteModel(
      token: (json['token'] ?? '').toString(),
      inviteUrl: (json['invite_url'] ?? '').toString(),
      deepLink: (json['deep_link'] ?? '').toString(),
      role: (json['role'] ?? 'editor').toString(),
      roleLabel: (json['role_label'] ?? 'Admin').toString(),
      expiresAt: (json['expires_at'] ?? '').toString(),
      waShareText: (json['wa_share_text'] ?? '').toString(),
    );
  }
}

class WorkspaceMembersBundle {
  final List<WorkspaceMemberModel> members;
  final int maxMembers;
  final String viewerRole;
  final WorkspaceInviteModel? activeInvite;

  const WorkspaceMembersBundle({
    this.members = const [],
    this.maxMembers = 2,
    this.viewerRole = 'owner',
    this.activeInvite,
  });

  factory WorkspaceMembersBundle.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? const [];
    final invMap = json['active_invite'];
    return WorkspaceMembersBundle(
      members: rawMembers
          .whereType<Map<String, dynamic>>()
          .map(WorkspaceMemberModel.fromJson)
          .toList(),
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 2,
      viewerRole: (json['viewer_role'] ?? 'owner').toString(),
      activeInvite: invMap is Map<String, dynamic>
          ? WorkspaceInviteModel.fromJson(invMap)
          : null,
    );
  }
}

class WorkspaceActivityLogModel {
  final String id;
  final String actorId;
  final String actorName;
  final String actorEmail;
  final String actorAvatarUrl;
  final String action;
  final String title;
  final String subtitle;
  final String timeLabel;
  final String dateGroup;
  final String createdAt;

  const WorkspaceActivityLogModel({
    required this.id,
    this.actorId = '',
    required this.actorName,
    this.actorEmail = '',
    this.actorAvatarUrl = '',
    required this.action,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    this.dateGroup = 'Hari Ini',
    this.createdAt = '',
  });

  String get actorInitials {
    final parts = actorName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'UK';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  factory WorkspaceActivityLogModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceActivityLogModel(
      id: (json['id'] ?? '').toString(),
      actorId: (json['actor_id'] ?? '').toString(),
      actorName: (json['actor_name'] ?? 'Anggota').toString(),
      actorEmail: (json['actor_email'] ?? '').toString(),
      actorAvatarUrl: (json['actor_avatar_url'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      timeLabel: (json['time_label'] ?? '').toString(),
      dateGroup: (json['date_group'] ?? 'Hari Ini').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class WorkspaceActivityLogsPage {
  final List<WorkspaceActivityLogModel> logs;
  final bool hasMore;
  final int limit;
  final int offset;
  final int nextOffset;

  const WorkspaceActivityLogsPage({
    this.logs = const [],
    this.hasMore = false,
    this.limit = 5,
    this.offset = 0,
    this.nextOffset = 0,
  });

  factory WorkspaceActivityLogsPage.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['logs'] as List<dynamic>? ?? const [];
    final parsedLogs = rawLogs
        .whereType<Map<String, dynamic>>()
        .map(WorkspaceActivityLogModel.fromJson)
        .toList();
    final offset = (json['offset'] as num?)?.toInt() ?? 0;
    return WorkspaceActivityLogsPage(
      logs: parsedLogs,
      hasMore: json['has_more'] as bool? ?? false,
      limit: (json['limit'] as num?)?.toInt() ?? 5,
      offset: offset,
      nextOffset:
          (json['next_offset'] as num?)?.toInt() ?? (offset + parsedLogs.length),
    );
  }
}

abstract class LedgerRepository {
  Future<List<Workspace>> listWorkspaces();

  Future<WorkspaceMutationResult> createWorkspace({
    required String name,
    required String shortName,
    required String focusType,
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountHolder = '',
    String logoUrl = '',
    List<String> quickCategories = const [],
  });

  Future<WorkspaceMutationResult> updateWorkspace({
    required String workspaceId,
    required String name,
    required String shortName,
    required String focusType,
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountHolder = '',
    String logoUrl = '',
    List<String> quickCategories = const [],
  });

  Future<LedgerTransactionsResult> listTransactions(String workspaceId);

  Future<CreateTransactionResult> createTransaction({
    required String workspaceId,
    required String title,
    required bool isInflow,
    required int amount,
    required String category,
    required String paymentMethod,
    String customerName = '',
    String notaRef = '',
    bool hasReceiptPhoto = false,
    String source = 'manual',
    List<TransactionLineItem> items = const [],
  });

  Future<List<Workspace>> deleteTransaction({
    required String workspaceId,
    required String transactionId,
  });

  Future<WorkspaceMembersBundle> listMembers(String workspaceId);

  Future<WorkspaceInviteModel> createInvite(String workspaceId);

  Future<WorkspaceMutationResult> joinWorkspace(String tokenOrUrl);

  Future<WorkspaceMembersBundle> removeMember({
    required String workspaceId,
    required String memberUserId,
  });

  Future<WorkspaceActivityLogsPage> listActivityLogs(
    String workspaceId, {
    int limit = 5,
    int offset = 0,
  });
}

class RemoteLedgerRepository implements LedgerRepository {
  final ApiClient _apiClient;

  RemoteLedgerRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  List<Workspace> _parseWorkspaces(dynamic rawList) {
    final list = rawList as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Workspace.fromJson)
        .toList();
  }

  @override
  Future<List<Workspace>> listWorkspaces() async {
    final data = await _apiClient.getAuthenticated('/api/v1/workspaces');
    return _parseWorkspaces(data['workspaces']);
  }

  @override
  Future<WorkspaceMutationResult> createWorkspace({
    required String name,
    required String shortName,
    required String focusType,
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountHolder = '',
    String logoUrl = '',
    List<String> quickCategories = const [],
  }) async {
    final normalizedCats = Workspace.normalizeQuickCategories(
      quickCategories,
      focusType: focusType,
    );
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces',
      body: {
        'name': name,
        'short_name': shortName,
        'focus_type': focusType,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_account_holder': bankAccountHolder,
        'logo_url': logoUrl,
        'quick_categories': normalizedCats,
      },
    );
    final wsMap = data['workspace'];
    return WorkspaceMutationResult(
      workspace: wsMap is Map<String, dynamic> ? Workspace.fromJson(wsMap) : null,
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<WorkspaceMutationResult> updateWorkspace({
    required String workspaceId,
    required String name,
    required String shortName,
    required String focusType,
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountHolder = '',
    String logoUrl = '',
    List<String> quickCategories = const [],
  }) async {
    final normalizedCats = Workspace.normalizeQuickCategories(
      quickCategories,
      focusType: focusType,
    );
    final data = await _apiClient.patchAuthenticated(
      '/api/v1/workspaces/$workspaceId',
      body: {
        'name': name,
        'short_name': shortName,
        'focus_type': focusType,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_account_holder': bankAccountHolder,
        'logo_url': logoUrl,
        'quick_categories': normalizedCats,
      },
    );
    final wsMap = data['workspace'];
    return WorkspaceMutationResult(
      workspace: wsMap is Map<String, dynamic> ? Workspace.fromJson(wsMap) : null,
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<LedgerTransactionsResult> listTransactions(String workspaceId) async {
    final data = await _apiClient.getAuthenticated(
      '/api/v1/workspaces/$workspaceId/transactions',
    );
    final rawTxs = data['transactions'] as List<dynamic>? ?? const [];
    final txs = rawTxs
        .whereType<Map<String, dynamic>>()
        .map(CashTransaction.fromJson)
        .toList();
    return LedgerTransactionsResult(
      transactions: txs,
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<CreateTransactionResult> createTransaction({
    required String workspaceId,
    required String title,
    required bool isInflow,
    required int amount,
    required String category,
    required String paymentMethod,
    String customerName = '',
    String notaRef = '',
    bool hasReceiptPhoto = false,
    String source = 'manual',
    List<TransactionLineItem> items = const [],
  }) async {
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces/$workspaceId/transactions',
      body: {
        'title': title,
        'type': isInflow ? 'inflow' : 'outflow',
        'amount': amount.abs(),
        'category': category,
        'payment_method': paymentMethod,
        'customer_name': customerName,
        'nota_ref': notaRef,
        'has_receipt_photo': hasReceiptPhoto,
        'source': source,
        'items': items.map((e) => e.toJson()).toList(),
      },
    );
    final txMap = Map<String, dynamic>.from(data['transaction'] as Map);
    return CreateTransactionResult(
      transaction: CashTransaction.fromJson(txMap),
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<List<Workspace>> deleteTransaction({
    required String workspaceId,
    required String transactionId,
  }) async {
    final data = await _apiClient.deleteAuthenticated(
      '/api/v1/workspaces/$workspaceId/transactions/$transactionId',
    );
    return _parseWorkspaces(data['workspaces']);
  }

  @override
  Future<WorkspaceMembersBundle> listMembers(String workspaceId) async {
    final data = await _apiClient.getAuthenticated(
      '/api/v1/workspaces/$workspaceId/members',
    );
    return WorkspaceMembersBundle.fromJson(data);
  }

  @override
  Future<WorkspaceInviteModel> createInvite(String workspaceId) async {
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces/$workspaceId/invites',
      body: const {},
    );
    final invMap = Map<String, dynamic>.from(data['invite'] as Map? ?? const {});
    return WorkspaceInviteModel.fromJson(invMap);
  }

  @override
  Future<WorkspaceMutationResult> joinWorkspace(String tokenOrUrl) async {
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces/join',
      body: {
        'token': tokenOrUrl.trim(),
      },
    );
    final wsMap = data['workspace'];
    return WorkspaceMutationResult(
      workspace: wsMap is Map<String, dynamic> ? Workspace.fromJson(wsMap) : null,
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<WorkspaceMembersBundle> removeMember({
    required String workspaceId,
    required String memberUserId,
  }) async {
    final data = await _apiClient.deleteAuthenticated(
      '/api/v1/workspaces/$workspaceId/members/$memberUserId',
    );
    return WorkspaceMembersBundle.fromJson(data);
  }

  @override
  Future<WorkspaceActivityLogsPage> listActivityLogs(
    String workspaceId, {
    int limit = 5,
    int offset = 0,
  }) async {
    final data = await _apiClient.getAuthenticated(
      '/api/v1/workspaces/$workspaceId/activity-logs?limit=$limit&offset=$offset',
    );
    return WorkspaceActivityLogsPage.fromJson(data);
  }
}
