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

abstract class LedgerRepository {
  Future<List<Workspace>> listWorkspaces();

  Future<WorkspaceMutationResult> createWorkspace({
    required String name,
    required String shortName,
    required String focusType,
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountHolder = '',
  });

  Future<WorkspaceMutationResult> updateWorkspace({
    required String workspaceId,
    required String name,
    required String shortName,
    required String focusType,
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountHolder = '',
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
  }) async {
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces',
      body: {
        'name': name,
        'short_name': shortName,
        'focus_type': focusType,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_account_holder': bankAccountHolder,
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
  }) async {
    final data = await _apiClient.patchAuthenticated(
      '/api/v1/workspaces/$workspaceId',
      body: {
        'name': name,
        'short_name': shortName,
        'focus_type': focusType,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_account_holder': bankAccountHolder,
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
}
