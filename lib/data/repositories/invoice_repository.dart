import 'dart:typed_data';
import '../../core/network/api_client.dart';
import '../models/cash_transaction.dart';
import '../models/nota_invoice.dart';
import '../models/workspace.dart';

class InvoiceListResult {
  final List<NotaInvoice> invoices;
  final List<Workspace> workspaces;

  const InvoiceListResult({
    required this.invoices,
    required this.workspaces,
  });
}

class CreateInvoiceResult {
  final NotaInvoice invoice;
  final List<Workspace> workspaces;

  const CreateInvoiceResult({
    required this.invoice,
    required this.workspaces,
  });
}

class MarkInvoicePaidResult {
  final NotaInvoice invoice;
  final CashTransaction? transaction;
  final List<Workspace> workspaces;

  const MarkInvoicePaidResult({
    required this.invoice,
    required this.transaction,
    required this.workspaces,
  });
}

abstract class InvoiceRepository {
  Future<InvoiceListResult> listInvoices(String workspaceId, {String? status});

  Future<CreateInvoiceResult> createInvoice({
    required String workspaceId,
    String invoiceNumber = '',
    required String clientName,
    String clientContact = '',
    String subtitle = '',
    String dueDateLabel = '',
    DateTime? dueAt,
    required int amount,
    String notes = '',
    List<TransactionLineItem> items = const [],
  });

  Future<MarkInvoicePaidResult> markInvoicePaid({
    required String workspaceId,
    required String invoiceId,
    String paymentMethod = 'Transfer',
  });

  Future<CreateInvoiceResult> updateInvoice({
    required String workspaceId,
    required String invoiceId,
    String? clientName,
    String? clientContact,
    String? subtitle,
    String? dueDateLabel,
    String? status,
    String? notes,
  });

  Future<List<Workspace>> deleteInvoice({
    required String workspaceId,
    required String invoiceId,
  });

  Future<Uint8List> downloadInvoicePdf({
    required String workspaceId,
    required String invoiceId,
  });
}

class RemoteInvoiceRepository implements InvoiceRepository {
  final ApiClient _apiClient;

  RemoteInvoiceRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  List<Workspace> _parseWorkspaces(dynamic rawList) {
    final list = rawList as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Workspace.fromJson)
        .toList();
  }

  @override
  Future<InvoiceListResult> listInvoices(
    String workspaceId, {
    String? status,
  }) async {
    final query = (status != null && status.isNotEmpty) ? '?status=$status' : '';
    final data = await _apiClient.getAuthenticated(
      '/api/v1/workspaces/$workspaceId/invoices$query',
    );
    final rawList = data['invoices'] as List<dynamic>? ?? const [];
    final invoices = rawList
        .whereType<Map<String, dynamic>>()
        .map(NotaInvoice.fromJson)
        .toList();
    return InvoiceListResult(
      invoices: invoices,
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<CreateInvoiceResult> createInvoice({
    required String workspaceId,
    String invoiceNumber = '',
    required String clientName,
    String clientContact = '',
    String subtitle = '',
    String dueDateLabel = '',
    DateTime? dueAt,
    required int amount,
    String notes = '',
    List<TransactionLineItem> items = const [],
  }) async {
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces/$workspaceId/invoices',
      body: {
        if (invoiceNumber.isNotEmpty) 'invoice_number': invoiceNumber,
        'client_name': clientName,
        'client_contact': clientContact,
        'subtitle': subtitle,
        'due_date_label': dueDateLabel,
        if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
        'amount': amount.abs(),
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      },
    );
    final invMap = Map<String, dynamic>.from(data['invoice'] as Map);
    return CreateInvoiceResult(
      invoice: NotaInvoice.fromJson(invMap),
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<MarkInvoicePaidResult> markInvoicePaid({
    required String workspaceId,
    required String invoiceId,
    String paymentMethod = 'Transfer',
  }) async {
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces/$workspaceId/invoices/$invoiceId/mark-paid',
      body: {
        'payment_method': paymentMethod,
      },
    );
    final invMap = Map<String, dynamic>.from(data['invoice'] as Map);
    final rawTx = data['transaction'];
    return MarkInvoicePaidResult(
      invoice: NotaInvoice.fromJson(invMap),
      transaction: rawTx is Map<String, dynamic>
          ? CashTransaction.fromJson(rawTx)
          : null,
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<CreateInvoiceResult> updateInvoice({
    required String workspaceId,
    required String invoiceId,
    String? clientName,
    String? clientContact,
    String? subtitle,
    String? dueDateLabel,
    String? status,
    String? notes,
  }) async {
    final data = await _apiClient.patchAuthenticated(
      '/api/v1/workspaces/$workspaceId/invoices/$invoiceId',
      body: {
        if (clientName != null) 'client_name': clientName,
        if (clientContact != null) 'client_contact': clientContact,
        if (subtitle != null) 'subtitle': subtitle,
        if (dueDateLabel != null) 'due_date_label': dueDateLabel,
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      },
    );
    final invMap = Map<String, dynamic>.from(data['invoice'] as Map);
    return CreateInvoiceResult(
      invoice: NotaInvoice.fromJson(invMap),
      workspaces: _parseWorkspaces(data['workspaces']),
    );
  }

  @override
  Future<List<Workspace>> deleteInvoice({
    required String workspaceId,
    required String invoiceId,
  }) async {
    final data = await _apiClient.deleteAuthenticated(
      '/api/v1/workspaces/$workspaceId/invoices/$invoiceId',
    );
    return _parseWorkspaces(data['workspaces']);
  }

  @override
  Future<Uint8List> downloadInvoicePdf({
    required String workspaceId,
    required String invoiceId,
  }) {
    return _apiClient.getBytesAuthenticated(
      '/api/v1/workspaces/$workspaceId/invoices/$invoiceId/pdf',
    );
  }
}
