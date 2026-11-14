import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cash_transaction.dart';
import '../data/models/nota_invoice.dart';
import '../data/models/workspace.dart';
import '../data/repositories/mock_ledger_data.dart';

final workspacesProvider = Provider<List<Workspace>>((ref) {
  return MockLedgerData.workspaces;
});

final activeWorkspaceIndexProvider = StateProvider<int>((ref) => 0);

final activeWorkspaceProvider = Provider<Workspace>((ref) {
  final list = ref.watch(workspacesProvider);
  final idx = ref.watch(activeWorkspaceIndexProvider);
  return list[idx];
});

class TransactionsNotifier extends Notifier<List<CashTransaction>> {
  @override
  List<CashTransaction> build() => MockLedgerData.initialTransactions;

  void addTransaction(CashTransaction tx) {
    state = [tx, ...state];
  }
}

final transactionsProvider =
    NotifierProvider<TransactionsNotifier, List<CashTransaction>>(
  TransactionsNotifier.new,
);

class NotaListNotifier extends Notifier<List<NotaInvoice>> {
  @override
  List<NotaInvoice> build() => MockLedgerData.initialNotas;

  void markAsPaid(String number) {
    state = [
      for (final nota in state)
        if (nota.number == number)
          nota.copyWith(
            status: NotaStatus.lunas,
            subtitle: '${nota.number} • Lunas (Kas)',
          )
        else
          nota,
    ];
  }

  void addNota(NotaInvoice nota) {
    state = [nota, ...state];
  }
}

final notaListProvider = NotifierProvider<NotaListNotifier, List<NotaInvoice>>(
  NotaListNotifier.new,
);

final txSearchQueryProvider = StateProvider<String>((ref) => '');
final txFilterCategoryProvider = StateProvider<String>((ref) => 'Semua');
final notaFilterStatusProvider = StateProvider<NotaStatus?>((ref) => null);
final selectedNotaNumberProvider = StateProvider<String?>((ref) => null);

final selectedNotaProvider = Provider<NotaInvoice>((ref) {
  final list = ref.watch(notaListProvider);
  final selectedNum = ref.watch(selectedNotaNumberProvider);
  if (selectedNum != null) {
    for (final nota in list) {
      if (nota.number == selectedNum) return nota;
    }
  }
  return list.first;
});

enum VoiceIntentType {
  bukuKas,
  kirimInvoice,
}

class VoiceRecordingSession {
  static const String sampleKasSpeech =
      'Ada uang masuk dari Pak Husni benerin motor ganti oli ceban tiga sama busi 25 ribu tunai';

  static const String sampleInvoiceSpeech =
      'Coba buatin invoice untuk Pak Reza, pembelian kursi kerja 3 buah totalnya 300 ribu dan meja 3 buah totalnya 600 ribu jadi total semua 900 ribu buatin invoicenya jatuh tempo tgl 12 November';

  final int durationSeconds;
  final bool isPushToTalk;
  final String transcript;

  const VoiceRecordingSession({
    this.durationSeconds = 4,
    this.isPushToTalk = false,
    this.transcript = sampleKasSpeech,
  });
}

final lastVoiceSessionProvider = StateProvider<VoiceRecordingSession>(
  (ref) => const VoiceRecordingSession(),
);

