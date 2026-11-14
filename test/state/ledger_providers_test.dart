import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucapkas_app/data/models/cash_transaction.dart';
import 'package:ucapkas_app/data/models/nota_invoice.dart';
import 'package:ucapkas_app/state/ledger_providers.dart';

void main() {
  test('initial seeded state matches Bengkel Jaya FigCraft numbers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ws = container.read(activeWorkspaceProvider);
    expect(ws.name, 'Bengkel Jaya (UMKM)');
    expect(ws.balance, 14850000);

    final txs = container.read(transactionsProvider);
    expect(txs.length, greaterThanOrEqualTo(6));
    expect(txs.first.title, 'Servis AC Mobil Avanza');
  });

  test('adding transaction updates list and marking nota paid changes status to lunas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(transactionsProvider.notifier).addTransaction(
          const CashTransaction(
            id: 'tx-new',
            title: 'Ganti Oli Beat & Busi',
            category: 'Jasa Servis',
            paymentMethod: 'Kas Tunai',
            timeLabel: '15:10',
            dateGroup: 'HARI INI • RABU, 11 NOV 2026',
            amount: 55000,
            customerName: 'Pak Joko',
          ),
        );

    expect(container.read(transactionsProvider).first.id, 'tx-new');

    container.read(notaListProvider.notifier).markAsPaid('NOTA/2026/1104');
    final updatedNota = container
        .read(notaListProvider)
        .firstWhere((n) => n.number == 'NOTA/2026/1104');
    expect(updatedNota.status, NotaStatus.lunas);
  });
}
