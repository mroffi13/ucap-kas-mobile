import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucapkas_app/core/utils/invoice_pdf_generator.dart';
import 'package:ucapkas_app/data/models/cash_transaction.dart';
import 'package:ucapkas_app/data/models/nota_invoice.dart';
import 'package:ucapkas_app/data/models/workspace.dart';
import 'package:ucapkas_app/data/repositories/invoice_repository.dart';
import 'package:ucapkas_app/state/ledger_providers.dart';

class _FakeInvoiceRepository implements InvoiceRepository {
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
    return CreateInvoiceResult(
      invoice: NotaInvoice(
        id: 'inv-server-1',
        number: invoiceNumber.isEmpty ? 'NOTA/2026/1101' : invoiceNumber,
        clientName: clientName,
        clientContact: clientContact,
        subtitle: subtitle,
        dateIssued: '16 Nov 2026',
        dueDateLabel: dueDateLabel,
        amount: amount,
        status: NotaStatus.menunggu,
        notes: notes,
        items: items,
      ),
      workspaces: const [],
    );
  }

  @override
  Future<List<Workspace>> deleteInvoice({
    required String workspaceId,
    required String invoiceId,
  }) async =>
      const [];

  @override
  Future<InvoiceListResult> listInvoices(String workspaceId,
          {String? status}) async =>
      const InvoiceListResult(invoices: [], workspaces: []);

  @override
  Future<MarkInvoicePaidResult> markInvoicePaid({
    required String workspaceId,
    required String invoiceId,
    String paymentMethod = 'Transfer',
  }) async {
    return MarkInvoicePaidResult(
      invoice: NotaInvoice(
        id: invoiceId,
        number: 'NOTA/2026/1101',
        clientName: 'Pak Reza',
        clientContact: '0812-8890-3344',
        subtitle: 'NOTA/2026/1101 • Lunas ($paymentMethod)',
        dateIssued: '16 Nov 2026',
        dueDateLabel: 'Tempo: 12 November 2026',
        amount: 900000,
        status: NotaStatus.lunas,
      ),
      transaction: const CashTransaction(
        id: 'tx-sync-1',
        title: 'Pelunasan Pak Reza',
        category: 'Pelunasan Invoice',
        paymentMethod: 'Transfer',
        timeLabel: '05:45',
        dateGroup: 'Hari Ini',
        amount: 900000,
        notaRef: 'NOTA/2026/1101',
        source: 'nota_sync',
      ),
      workspaces: const [],
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
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> downloadInvoicePdf({
    required String workspaceId,
    required String invoiceId,
  }) async {
    return Uint8List.fromList(ascii.encode('%PDF-1.4\n%%EOF\n'));
  }
}

void main() {
  test('NotaInvoice fromJson and toJson round-trip preserves fields and items',
      () {
    final inv = NotaInvoice.fromJson({
      'id': 'inv-123',
      'number': 'NOTA/2026/1109',
      'client_name': 'Pak Reza',
      'client_contact': '0812-8890-3344',
      'subtitle': 'NOTA/2026/1109 • Tempo: 12 Nov',
      'date_issued': '16 Nov 2026',
      'due_date_label': 'Tempo: 12 Nov',
      'amount': 900000,
      'status': 'jatuh_tempo',
      'notes': 'DP sudah masuk',
      'items': [
        {'name': 'Kursi Kerja', 'quantity': 3, 'unit_price': 100000},
        {'name': 'Meja', 'quantity': 3, 'unit_price': 200000},
      ],
    });

    expect(inv.id, 'inv-123');
    expect(inv.number, 'NOTA/2026/1109');
    expect(inv.status, NotaStatus.jatuhTempo);
    expect(inv.amount, 900000);
    expect(inv.notes, 'DP sudah masuk');
    expect(inv.items.length, 2);
    expect(inv.items.first.subtotal, 300000);

    final json = inv.toJson();
    expect(json['status'], 'jatuh_tempo');
    expect(json['invoice_number'], 'NOTA/2026/1109');
    expect((json['items'] as List).length, 2);
  });

  test('markAsPaid in guest mode updates status and syncs cash transaction',
      () async {
    final container = ProviderContainer(
      overrides: [
        invoiceRepositoryProvider.overrideWithValue(_FakeInvoiceRepository()),
      ],
    );
    addTearDown(container.dispose);

    final initialTxCount = container.read(transactionsProvider).length;
    final ok = await container
        .read(notaListProvider.notifier)
        .markAsPaid('NOTA/2026/1104', paymentMethod: 'QRIS');

    expect(ok, isTrue);
    final updated = container
        .read(notaListProvider)
        .firstWhere((n) => n.number == 'NOTA/2026/1104');
    expect(updated.status, NotaStatus.lunas);
    expect(updated.subtitle, contains('QRIS'));

    final txs = container.read(transactionsProvider);
    expect(txs.length, initialTxCount + 1);
    expect(txs.first.source, 'nota_sync');
    expect(txs.first.notaRef, 'NOTA/2026/1104');
  });

  test('InvoicePdfGenerator generates valid A4 PDF 1.4 bytes', () {
    final res = InvoicePdfGenerator.generate(
      nota: const NotaInvoice(
        id: 'inv-1',
        number: 'NOTA/2026/1109',
        clientName: 'Pak Reza',
        clientContact: '0812-8890-3344',
        subtitle: 'NOTA/2026/1109 • Tempo: 7 Hari Lagi',
        dateIssued: '16 Nov 2026',
        dueDateLabel: 'Tempo: 7 Hari Lagi',
        amount: 900000,
        status: NotaStatus.menunggu,
        items: [
          TransactionLineItem(
            name: 'Kursi Kerja',
            quantity: 3,
            unitPrice: 300000,
          ),
        ],
      ),
      workspace: const Workspace(
        id: 'ws-1',
        name: 'Toko Berkah',
        shortName: 'TB',
        balance: 0,
        monthlyInflow: 0,
        monthlyOutflow: 0,
      ),
    );

    expect(res.filename, 'NOTA-2026-1109.pdf');
    final pdfStr = ascii.decode(res.bytes);
    expect(pdfStr, startsWith('%PDF-1.4\n'));
    expect(pdfStr, contains('NOTA/2026/1109'));
    expect(pdfStr, contains('Pak Reza'));
    expect(pdfStr, contains('%%EOF'));
  });
}
