import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucapkas_app/app.dart';
import 'package:ucapkas_app/core/widgets/ucapkas_logo.dart';
import 'package:ucapkas_app/router/app_router.dart';
import 'package:ucapkas_app/data/models/auth_user.dart';
import 'package:ucapkas_app/data/models/cash_transaction.dart';
import 'package:ucapkas_app/data/models/workspace.dart';
import 'package:ucapkas_app/data/repositories/auth_repository.dart';
import 'package:ucapkas_app/data/repositories/ledger_repository.dart';
import 'package:ucapkas_app/data/repositories/mock_ledger_data.dart';
import 'package:ucapkas_app/state/auth_provider.dart';
import 'package:ucapkas_app/state/ledger_providers.dart';

class _WidgetTestLedgerRepository implements LedgerRepository {
  List<Workspace> _workspaces = List<Workspace>.from(MockLedgerData.workspaces);

  @override
  Future<List<Workspace>> listWorkspaces() async => _workspaces;

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
    final created = Workspace(
      id: 'ws-${_workspaces.length + 1}',
      name: name,
      shortName: shortName,
      balance: 0,
      monthlyInflow: 0,
      monthlyOutflow: 0,
      focusType: focusType,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountHolder: bankAccountHolder,
      logoUrl: logoUrl,
      quickCategories: Workspace.normalizeQuickCategories(
        quickCategories,
        focusType: focusType,
      ),
    );
    _workspaces = [..._workspaces, created];
    return WorkspaceMutationResult(
      workspace: created,
      workspaces: _workspaces,
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
    Workspace? updated;
    _workspaces = [
      for (final ws in _workspaces)
        if (ws.id == workspaceId)
          updated = ws.copyWith(
            name: name,
            shortName: shortName,
            focusType: focusType,
            bankName: bankName,
            bankAccountNumber: bankAccountNumber,
            bankAccountHolder: bankAccountHolder,
            logoUrl: logoUrl,
            quickCategories: quickCategories,
          )
        else
          ws,
    ];
    return WorkspaceMutationResult(
      workspace: updated,
      workspaces: _workspaces,
    );
  }

  @override
  Future<LedgerTransactionsResult> listTransactions(String workspaceId) async {
    return LedgerTransactionsResult(
      transactions: MockLedgerData.initialTransactions,
      workspaces: _workspaces,
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

  @override
  Future<WorkspaceMembersBundle> listMembers(String workspaceId) async {
    return const WorkspaceMembersBundle(
      members: [
        WorkspaceMemberModel(
          userId: '01932c00-0000-7000-8000-000000000010',
          email: 'hendra.jaya@gmail.com',
          fullName: 'Hendra Jaya',
          role: 'owner',
          roleLabel: 'Pemilik',
          isOwner: true,
        ),
      ],
      maxMembers: 5,
      viewerRole: 'owner',
    );
  }

  @override
  Future<WorkspaceInviteModel> createInvite(String workspaceId) async {
    return const WorkspaceInviteModel(
      token: 'uk-inv-test12345',
      inviteUrl: 'https://ucapkas.id/join/uk-inv-test12345',
      deepLink: 'ucapkas://join/uk-inv-test12345',
      expiresAt: '2026-11-17T20:00:00Z',
      waShareText: 'Undangan Admin UcapKas: https://ucapkas.id/join/uk-inv-test12345',
    );
  }

  @override
  Future<WorkspaceMutationResult> joinWorkspace(String tokenOrUrl) async {
    return const WorkspaceMutationResult(
      workspace: null,
      workspaces: MockLedgerData.workspaces,
    );
  }

  @override
  Future<WorkspaceMembersBundle> removeMember({
    required String workspaceId,
    required String memberUserId,
  }) async {
    return listMembers(workspaceId);
  }

  @override
  Future<WorkspaceActivityLogsPage> listActivityLogs(
    String workspaceId, {
    int limit = 5,
    int offset = 0,
  }) async {
    return const WorkspaceActivityLogsPage();
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
    expect(find.text('Naik 12,5% dibanding bulan lalu'), findsOneWidget);
    expect(find.text('Catat Kas'), findsOneWidget);
    expect(find.text('Buat Nota'), findsOneWidget);
    expect(find.text('Foto Struk'), findsNothing);

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

    // 7a. Click Bicara -> starts inline recording on Dashboard
    await tester.tap(micFinder);
    await tester.pump();
    expect(find.byKey(const Key('voice_recording_hud')), findsOneWidget);
    expect(find.text('Mode Klik'), findsNothing);

    // Click Batal -> cancels inline recording and stays on Dashboard
    await tester.tap(find.byKey(const Key('btn_voice_cancel')));
    await tester.pump();
    expect(find.text('Rekaman suara dibatalkan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // 7b. Hold Bicara (Push-to-Talk) + drag left -> cancels recording on release
    final micCenter = tester.getCenter(micFinder);
    final pttCancelGesture = await tester.startGesture(micCenter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mode Tahan (WA)'), findsNothing);

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
    expect(find.text('Rekaman Suara'), findsOneWidget);
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

  test('Workspace.compareMonthlyNet computes dynamic upward, downward, flat, and noPrevData trends', () {
    const wsUp = Workspace(
      id: 'ws-1',
      name: 'Kas 1',
      shortName: 'Kas 1',
      balance: 1000000,
      monthlyInflow: 1500000,
      monthlyOutflow: 500000, // net 1.000.000
      prevMonthlyInflow: 1200000,
      prevMonthlyOutflow: 400000, // prev net 800.000 -> +25%
    );
    final upRes = wsUp.compareMonthlyNet(
      currentInflow: wsUp.monthlyInflow,
      currentOutflow: wsUp.monthlyOutflow,
    );
    expect(upRes.trend, MonthlyTrendType.up);
    expect(upRes.label, 'Naik 25% dibanding bulan lalu');

    final downRes = wsUp.compareMonthlyNet(
      currentInflow: 900000,
      currentOutflow: 500000, // net 400.000 vs 800.000 -> -50%
    );
    expect(downRes.trend, MonthlyTrendType.down);
    expect(downRes.label, 'Turun 50% dibanding bulan lalu');

    const wsNew = Workspace(
      id: 'ws-new',
      name: 'Kas Baru',
      shortName: 'Kas Baru',
      balance: 0,
      monthlyInflow: 200000,
      monthlyOutflow: 0,
      prevMonthlyInflow: 0,
      prevMonthlyOutflow: 0,
    );
    final newRes = wsNew.compareMonthlyNet(
      currentInflow: 200000,
      currentOutflow: 0,
    );
    expect(newRes.trend, MonthlyTrendType.noPrevData);
    expect(newRes.label, 'Bulan pertama pembukuan aktif');
  });

  testWidgets('Catat Kas removes Biasa dicatat & Lampirkan Foto Struk, and Akun customizes 3 quick categories', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appRouter.go('/onboarding');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_WidgetTestAuthRepository()),
          ledgerRepositoryProvider.overrideWithValue(_WidgetTestLedgerRepository()),
        ],
        child: const UcapKasApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk Lewat Google'));
    await tester.pumpAndSettle();

    // Open Catat Kas from Dashboard
    await tester.tap(find.text('Catat Kas'));
    await tester.pumpAndSettle();

    expect(find.text('Biasa dicatat:'), findsNothing);
    expect(find.text('Lampirkan Foto Struk'), findsNothing);
    expect(find.byKey(const Key('quick_category_chip_0')), findsOneWidget);
    expect(find.byKey(const Key('quick_category_chip_1')), findsOneWidget);
    expect(find.byKey(const Key('quick_category_chip_2')), findsOneWidget);
    expect(find.byKey(const Key('quick_category_chip_3')), findsNothing);

    // Go to Akun and edit the 3 quick categories
    await tester.tap(find.text('Pilih cepat (3) · Atur di Akun'));
    await tester.pumpAndSettle();

    expect(find.text('Akun & Kas Bersama'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_edit_workspace_ws-bengkel')));
    await tester.pumpAndSettle();

    expect(find.text('Kategori Pilih Cepat (Maks. 3)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('input_quick_cat_0')), 'Ganti Oli');
    await tester.enterText(find.byKey(const Key('input_quick_cat_1')), 'Tune Up');
    await tester.enterText(find.byKey(const Key('input_quick_cat_2')), 'Onderdil');
    await tester.pump();

    await tester.tap(find.text('Simpan Pengaturan Kas'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Kategori Cepat: Ganti Oli · Tune Up · Onderdil'), findsOneWidget);

    // Return to Dashboard -> Catat Kas and verify the 3 new quick categories appear
    await tester.tap(find.text('Kas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catat Kas'));
    await tester.pumpAndSettle();

    expect(find.text('Ganti Oli'), findsWidgets);
    expect(find.text('Tune Up'), findsOneWidget);
    expect(find.text('Onderdil'), findsOneWidget);
  });
}
