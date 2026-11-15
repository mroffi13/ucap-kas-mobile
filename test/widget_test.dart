import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucapkas_app/app.dart';
import 'package:ucapkas_app/core/widgets/ucapkas_logo.dart';
import 'package:ucapkas_app/data/models/auth_user.dart';
import 'package:ucapkas_app/data/models/cash_transaction.dart';
import 'package:ucapkas_app/data/models/workspace.dart';
import 'package:ucapkas_app/data/repositories/auth_repository.dart';
import 'package:ucapkas_app/data/repositories/ledger_repository.dart';
import 'package:ucapkas_app/data/repositories/mock_ledger_data.dart';
import 'package:ucapkas_app/state/auth_provider.dart';
import 'package:ucapkas_app/state/ledger_providers.dart';

class _WidgetTestLedgerRepository implements LedgerRepository {
  @override
  Future<List<Workspace>> listWorkspaces() async => MockLedgerData.workspaces;

  @override
  Future<WorkspaceMutationResult> createWorkspace({
    required String name,
    required String shortName,
    required String focusType,
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountHolder = '',
  }) async {
    return const WorkspaceMutationResult(
      workspace: null,
      workspaces: MockLedgerData.workspaces,
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
    return const WorkspaceMutationResult(
      workspace: null,
      workspaces: MockLedgerData.workspaces,
    );
  }

  @override
  Future<LedgerTransactionsResult> listTransactions(String workspaceId) async {
    return const LedgerTransactionsResult(
      transactions: MockLedgerData.initialTransactions,
      workspaces: MockLedgerData.workspaces,
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
    return CreateTransactionResult(
      transaction: CashTransaction(
        id: 'server-tx-1',
        title: title,
        category: category,
        paymentMethod: paymentMethod,
        timeLabel: 'Baru saja',
        dateGroup: 'Hari Ini',
        amount: isInflow ? amount : -amount,
        items: items,
      ),
      workspaces: MockLedgerData.workspaces,
    );
  }

  @override
  Future<List<Workspace>> deleteTransaction({
    required String workspaceId,
    required String transactionId,
  }) async {
    return MockLedgerData.workspaces;
  }
}

class _WidgetTestAuthRepository implements AuthRepository {
  @override
  Future<AuthSessionBundle?> tryRestoreSession() async => null;

  @override
  Future<AuthSessionBundle> signInWithGoogle({
    required String selectedFocus,
  }) async {
    return const AuthSessionBundle(
      accessToken: 'test_access_token',
      refreshToken: 'test_refresh_token',
      expiresIn: 900,
      user: AuthUser(
        id: '01932c00-0000-7000-8000-000000000010',
        email: 'hendra.jaya@gmail.com',
        fullName: 'Hendra Jaya',
        planTier: 'umkm_pro',
      ),
      workspaces: MockLedgerData.workspaces,
    );
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('UcapKasApp boots into Splash -> Login -> Dashboard and navigates tabs', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_WidgetTestAuthRepository()),
          ledgerRepositoryProvider.overrideWithValue(_WidgetTestLedgerRepository()),
        ],
        child: const UcapKasApp(),
      ),
    );
    await tester.pump();

    // 1. Verify clean Splash Screen renders first
    expect(find.text('Tinggal ngomong, kas rapi.'), findsOneWidget);
    expect(find.text('Buku Kas Usaha & Harian'), findsOneWidget);
    expect(find.byType(UcapKasLogo), findsOneWidget);

    // 2. Advance past the 6.0s Splash timer into Login (Screen 0)
    await tester.pump(const Duration(milliseconds: 6100));
    await tester.pumpAndSettle();

    expect(find.text('Masuk Lewat Google'), findsOneWidget);
    expect(find.text('Servis AC Mobil Avanza'), findsOneWidget);
    expect(find.text('+Rp 450.000'), findsOneWidget);

    // 2b. Test interactive Persona Switcher on Onboarding screen
    await tester.tap(find.text('Rumah Tangga'));
    await tester.pumpAndSettle();
    expect(find.text('Beras 5kg & Telur Ayam 1kg'), findsOneWidget);
    expect(find.text('-Rp 103.000'), findsOneWidget);

    await tester.tap(find.text('UMKM / Jasa'));
    await tester.pumpAndSettle();
    expect(find.text('Servis AC Mobil Avanza'), findsOneWidget);

    // 3. Tap 'Masuk Lewat Google' to enter Dashboard (Screen 1)
    await tester.tap(find.text('Masuk Lewat Google'));
    await tester.pumpAndSettle();

    expect(find.byType(UcapKasLogo), findsOneWidget);
    expect(find.text('Rp 14.850.000'), findsOneWidget);
    expect(find.text('Bicara'), findsOneWidget);

    // 3b. Test eye icon balance visibility toggle on Dashboard Hero Card
    await tester.tap(find.byKey(const Key('btn_toggle_balance_visibility')));
    await tester.pumpAndSettle();
    expect(find.text('Rp ••••••••'), findsOneWidget);
    expect(find.text('+Rp •••••••'), findsOneWidget);
    expect(find.text('-Rp •••••••'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn_toggle_balance_visibility')));
    await tester.pumpAndSettle();
    expect(find.text('Rp 14.850.000'), findsOneWidget);

    // 4. Navigate to Nota WA tab
    await tester.tap(find.text('Nota'));
    await tester.pumpAndSettle();
    expect(find.text('Tagihan & Nota WA'), findsOneWidget);

    // 5. Navigate to Laporan tab
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan Untung Rugi'), findsOneWidget);

    // 6. Navigate to Akun tab
    await tester.tap(find.text('Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Akun & Kas Bersama'), findsOneWidget);

    // 7. Return to Dashboard (Kas) and test inline Voice Recording & Push-to-Talk
    await tester.tap(find.text('Kas'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 14.850.000'), findsOneWidget);

    final micFinder = find.byKey(const Key('btn_bicara_mic'));

    // 7a. Click Bicara -> starts inline recording on Dashboard (Mode Klik)
    await tester.tap(micFinder);
    await tester.pump();
    expect(find.byKey(const Key('voice_recording_hud')), findsOneWidget);
    expect(find.text('Mode Klik'), findsOneWidget);

    // Click Batal -> cancels inline recording and stays on Dashboard
    await tester.tap(find.byKey(const Key('btn_voice_cancel')));
    await tester.pump();
    expect(find.text('Rekaman suara dibatalkan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // 7b. Hold Bicara (Push-to-Talk) + drag left -> cancels recording on release
    final micCenter = tester.getCenter(micFinder);
    final pttCancelGesture = await tester.startGesture(micCenter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mode Tahan (WA)'), findsOneWidget);

    await pttCancelGesture.moveBy(const Offset(-85, 0));
    await tester.pump();
    expect(find.text('LEPAS UNTUK BATAL'), findsOneWidget);

    await pttCancelGesture.up();
    await tester.pump();
    expect(find.text('Rekaman suara dibatalkan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // 7c. Hold Bicara (Push-to-Talk) + release normally -> navigates to Confirmation Sheet
    final pttSendGesture = await tester.startGesture(micCenter);
    await tester.pump(const Duration(milliseconds: 300));
    await pttSendGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Rincian Catatan Suara'), findsOneWidget);
    expect(find.text('Push-to-Talk'), findsOneWidget);
  });

  test('CashTransaction.fromJson parses manual (0 items) and itemized (1..N items) payloads', () {
    final manualTx = CashTransaction.fromJson({
      'id': '01932c11-0000-7000-8000-000000000001',
      'title': 'Servis Ganti Oli',
      'type': 'inflow',
      'amount': 125000,
      'category': 'Servis',
      'payment_method': 'QRIS',
      'time_label': '14:30',
      'date_group': 'Hari Ini',
      'source': 'manual',
      'items': [],
    });
    expect(manualTx.isInflow, isTrue);
    expect(manualTx.amount, 125000);
    expect(manualTx.items, isEmpty);

    final itemizedTx = CashTransaction.fromJson({
      'id': '01932c11-0000-7000-8000-000000000002',
      'title': 'Belanja Onderdil',
      'type': 'outflow',
      'amount': 85000,
      'category': 'Bahan Baku',
      'payment_method': 'Tunai',
      'time_label': '15:10',
      'date_group': 'Hari Ini',
      'source': 'receipt_ai',
      'has_receipt_photo': true,
      'items': [
        {'name': 'Kampas Rem', 'quantity': 2, 'unit_price': 25000},
        {'name': 'Busi Iridium', 'quantity': 1, 'unit_price': 35000},
      ],
    });
    expect(itemizedTx.isInflow, isFalse);
    expect(itemizedTx.amount, -85000);
    expect(itemizedTx.items.length, 2);
    expect(itemizedTx.items.first.subtotal, 50000);
  });
}
