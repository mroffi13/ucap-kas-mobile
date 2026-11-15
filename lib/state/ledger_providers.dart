import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cash_transaction.dart';
import '../data/models/nota_invoice.dart';
import '../data/models/workspace.dart';
import '../data/repositories/ai_repository.dart';
import '../data/repositories/ledger_repository.dart';
import '../data/repositories/mock_ledger_data.dart';
import 'auth_provider.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return RemoteLedgerRepository(
    apiClient: ref.watch(apiClientProvider),
  );
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return RemoteAiRepository(
    apiClient: ref.watch(apiClientProvider),
  );
});

final aiQuotaProvider = StateProvider<AiQuotaStatus>(
  (ref) => const AiQuotaStatus(),
);

final parsedReceiptDraftProvider = StateProvider<ReceiptAiResult>(
  (ref) => const ReceiptAiResult(
    storeName: 'Toko Onderdil Motor & Mobil Jaya',
    category: 'Suku Cadang',
    paymentMethod: 'Tunai',
    totalAmount: 180000,
    items: [
      TransactionLineItem(
        name: 'Kampas Rem Depan Honda Beat (2 Set)',
        quantity: 2,
        unitPrice: 45000,
      ),
      TransactionLineItem(
        name: 'Oli Mesin Shell Advance AX7 1L',
        quantity: 1,
        unitPrice: 65000,
      ),
      TransactionLineItem(
        name: 'Cairan Pembersih Karburator & Baut',
        quantity: 1,
        unitPrice: 25000,
      ),
    ],
  ),
);

final workspacesProvider = Provider<List<Workspace>>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.isAuthenticated && authState.workspaces.isNotEmpty) {
    return authState.workspaces;
  }
  return MockLedgerData.workspaces;
});

final activeWorkspaceIndexProvider = StateProvider<int>((ref) => 0);

final activeWorkspaceProvider = Provider<Workspace>((ref) {
  final list = ref.watch(workspacesProvider);
  final idx = ref.watch(activeWorkspaceIndexProvider);
  final safeIdx = idx.clamp(0, list.length - 1);
  return list[safeIdx];
});

class TransactionsNotifier extends Notifier<List<CashTransaction>> {
  @override
  List<CashTransaction> build() {
    final isAuthenticated = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );
    final activeWorkspaceId = ref.watch(
      activeWorkspaceProvider.select((w) => w.id),
    );

    if (!isAuthenticated) {
      return MockLedgerData.initialTransactions;
    }

    Future.microtask(() => refreshFromServer(activeWorkspaceId));
    return const [];
  }

  Future<void> refreshFromServer([String? workspaceId]) async {
    final isAuth = ref.read(authProvider).isAuthenticated;
    if (!isAuth) return;
    final targetWsId = workspaceId ?? ref.read(activeWorkspaceProvider).id;
    if (targetWsId.isEmpty) return;

    try {
      final repo = ref.read(ledgerRepositoryProvider);
      final res = await repo.listTransactions(targetWsId);
      if (ref.read(activeWorkspaceProvider).id == targetWsId) {
        state = res.transactions;
      }
      if (res.workspaces.isNotEmpty) {
        ref.read(authProvider.notifier).updateWorkspaces(res.workspaces);
      }
    } catch (e) {
      debugPrint('[UcapKas Ledger] Failed to load transactions: $e');
    }
  }

  Future<bool> addTransaction(
    CashTransaction tx, {
    String source = 'manual',
  }) async {
    // Optimistic insert so UI & synchronous widget tests update immediately
    state = [tx, ...state];

    final isAuth = ref.read(authProvider).isAuthenticated;
    if (!isAuth) return true;

    final wsId = ref.read(activeWorkspaceProvider).id;
    try {
      final repo = ref.read(ledgerRepositoryProvider);
      final res = await repo.createTransaction(
        workspaceId: wsId,
        title: tx.title,
        isInflow: tx.isInflow,
        amount: tx.amount.abs(),
        category: tx.category,
        paymentMethod: tx.paymentMethod,
        customerName: tx.customerName ?? '',
        notaRef: tx.notaRef ?? '',
        hasReceiptPhoto: tx.hasReceiptPhoto,
        source: source,
        items: tx.items,
      );

      state = [
        for (final item in state)
          if (item.id == tx.id) res.transaction else item,
      ];
      if (res.workspaces.isNotEmpty) {
        ref.read(authProvider.notifier).updateWorkspaces(res.workspaces);
      }
      return true;
    } catch (e) {
      debugPrint('[UcapKas Ledger] Failed to save transaction to server: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    final prev = state;
    state = [
      for (final item in state)
        if (item.id != transactionId) item,
    ];

    final isAuth = ref.read(authProvider).isAuthenticated;
    if (!isAuth) return true;

    final wsId = ref.read(activeWorkspaceProvider).id;
    try {
      final repo = ref.read(ledgerRepositoryProvider);
      final workspaces = await repo.deleteTransaction(
        workspaceId: wsId,
        transactionId: transactionId,
      );
      if (workspaces.isNotEmpty) {
        ref.read(authProvider.notifier).updateWorkspaces(workspaces);
      }
      return true;
    } catch (e) {
      debugPrint('[UcapKas Ledger] Failed to delete transaction: $e');
      state = prev;
      return false;
    }
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
final balanceVisibleProvider = StateProvider<bool>((ref) => true);

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
  final String audioBase64;
  final String mimeType;

  const VoiceRecordingSession({
    this.durationSeconds = 4,
    this.isPushToTalk = false,
    this.transcript = sampleKasSpeech,
    this.audioBase64 = '',
    this.mimeType = 'audio/mp4',
  });
}

final lastVoiceSessionProvider = StateProvider<VoiceRecordingSession>(
  (ref) => const VoiceRecordingSession(),
);
