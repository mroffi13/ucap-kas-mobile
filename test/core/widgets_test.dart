import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucapkas_app/core/widgets/ucapkas_bottom_nav.dart';
import 'package:ucapkas_app/core/widgets/ucapkas_logo.dart';
import 'package:ucapkas_app/core/widgets/ucapkas_toast.dart';
import 'package:ucapkas_app/features/manual_entry/screen_3_catat_manual.dart';
import 'package:ucapkas_app/features/voice_entry/screen_2_voice_sheet.dart';

void main() {
  testWidgets('UcapKasLogo renders wordmark when enabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UcapKasLogo(size: 32, showWordmark: true),
        ),
      ),
    );
    expect(find.text('Ucap'), findsOneWidget);
    expect(find.text('Kas'), findsOneWidget);
  });

  testWidgets(
      'UcapKasBottomNavBar renders 5 items and clicking Bicara starts hands-free recording',
      (tester) async {
    int? tappedTab;
    bool bicaraCompleted = false;
    bool recordCancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: UcapKasBottomNavBar(
            currentIndex: 0,
            onTabSelected: (index) => tappedTab = index,
            onBicaraPressed: () => bicaraCompleted = true,
            onRecordCancelled: () => recordCancelled = true,
          ),
        ),
      ),
    );

    expect(find.text('Kas'), findsOneWidget);
    expect(find.text('Nota'), findsOneWidget);
    expect(find.text('Bicara'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Akun'), findsOneWidget);

    await tester.tap(find.text('Nota'));
    expect(tappedTab, 1);

    // 1. Clicking Bicara once starts inline voice recording (does not navigate immediately)
    await tester.tap(find.byKey(const Key('btn_bicara_mic')));
    await tester.pump();
    expect(find.byKey(const Key('voice_recording_hud')), findsOneWidget);
    expect(find.text('Mode Klik'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(bicaraCompleted, isFalse);

    // 2. Clicking Batal cancels recording
    await tester.tap(find.byKey(const Key('btn_voice_cancel')));
    await tester.pump();
    expect(recordCancelled, isTrue);
    expect(find.byKey(const Key('voice_cancelled_banner')), findsOneWidget);
    expect(find.text('Rekaman suara dibatalkan'), findsOneWidget);

    // Wait for cancelled banner timer to clear
    await tester.pump(const Duration(seconds: 3));

    // 3. Clicking Bicara again and then Selesai completes recording
    await tester.tap(find.byKey(const Key('btn_bicara_mic')));
    await tester.pump();
    expect(find.byKey(const Key('voice_recording_hud')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn_voice_done')));
    await tester.pump();
    expect(bicaraCompleted, isTrue);
  });

  testWidgets(
      'UcapKasBottomNavBar supports Hold Push-to-Talk (release to finish, drag away to cancel)',
      (tester) async {
    bool bicaraCompleted = false;
    bool recordCancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: UcapKasBottomNavBar(
            currentIndex: 0,
            onBicaraPressed: () => bicaraCompleted = true,
            onRecordCancelled: () => recordCancelled = true,
          ),
        ),
      ),
    );

    final micFinder = find.byKey(const Key('btn_bicara_mic'));
    final micCenter = tester.getCenter(micFinder);

    // Scenario A: Hold for Push-to-Talk and release normally -> completes recording
    final holdGesture = await tester.startGesture(micCenter);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('voice_recording_hud')), findsOneWidget);
    expect(find.text('Mode Tahan (WA)'), findsOneWidget);
    expect(find.text('« Geser untuk batal'), findsOneWidget);

    await holdGesture.up();
    await tester.pump();
    expect(bicaraCompleted, isTrue);
    expect(recordCancelled, isFalse);

    // Reset flags
    bicaraCompleted = false;
    recordCancelled = false;

    // Scenario B: Hold for Push-to-Talk and drag away -> cancels recording on release
    final cancelGesture = await tester.startGesture(micCenter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mode Tahan (WA)'), findsOneWidget);

    // Drag left 90px into cancel zone
    await cancelGesture.moveBy(const Offset(-90, 0));
    await tester.pump();

    expect(find.text('LEPAS UNTUK BATAL'), findsOneWidget);
    expect(find.text('Lepas untuk Batal!'), findsOneWidget);

    await cancelGesture.up();
    await tester.pump();

    expect(recordCancelled, isTrue);
    expect(bicaraCompleted, isFalse);
    expect(find.text('Rekaman suara dibatalkan'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'Screen3CatatManual supports smooth Kas Masuk/Keluar toggle and editable nominal field',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Screen3CatatManual(),
        ),
      ),
    );

    expect(find.text('Jumlah Uang Masuk'), findsOneWidget);
    expect(find.text('Simpan Kas Masuk'), findsOneWidget);

    // Toggle to Kas Keluar and settle smooth animation
    await tester.tap(find.text('Kas Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Jumlah Uang Keluar'), findsOneWidget);
    expect(find.text('Simpan Kas Keluar'), findsOneWidget);

    // Edit nominal directly via TextField -> auto-formats with thousand dots
    final nominalField = find.byKey(const Key('input_nominal_kas'));
    await tester.enterText(nominalField, '125000');
    await tester.pump();

    final textFieldWidget = tester.widget<TextField>(nominalField);
    expect(textFieldWidget.controller?.text, '125.000');

    // Tap quick increment +50 rb -> updates editable field to 175.000
    await tester.tap(find.text('+50 rb'));
    await tester.pump();
    expect(textFieldWidget.controller?.text, '175.000');
  });

  testWidgets(
      'Screen2VoiceSheet supports editable Kategori, Qty, and Harga Satuan with real-time total calculation',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Screen2VoiceSheet(),
        ),
      ),
    );

    // Initial total: (3 x 10.000) + (1 x 25.000) = +Rp 55.000
    expect(find.text('+Rp 55.000'), findsOneWidget);

    // Edit Qty of Item 0 from 3 to 5 -> (5 x 10.000) + 25.000 = +Rp 75.000
    final qtyField0 = find.byKey(const Key('input_voice_item_qty_0'));
    await tester.enterText(qtyField0, '5');
    await tester.pump();
    expect(find.text('+Rp 75.000'), findsOneWidget);

    // Edit Harga Satuan of Item 0 from 10.000 to 20000 -> (5 x 20.000) + 25.000 = +Rp 125.000
    final priceField0 = find.byKey(const Key('input_voice_item_price_0'));
    await tester.enterText(priceField0, '20000');
    await tester.pump();
    final priceWidget = tester.widget<TextField>(priceField0);
    expect(priceWidget.controller?.text, '20.000');
    expect(find.text('+Rp 125.000'), findsOneWidget);

    // Edit Kategori via TextField directly
    final catField = find.byKey(const Key('input_voice_category'));
    await tester.enterText(catField, 'Jasa Turun Mesin');
    await tester.pump();
    final catWidget = tester.widget<TextField>(catField);
    expect(catWidget.controller?.text, 'Jasa Turun Mesin');

    // Switch to Invoice Speech ("Buat Invoice (Pak Reza · Rp 900 rb)") -> renders Kirim Invoice view
    final invoicePill = find.text('Buat Invoice (Pak Reza · Rp 900 rb)');
    await tester.ensureVisible(invoicePill);
    await tester.tap(invoicePill);
    await tester.pumpAndSettle();

    expect(find.text('Total Tagihan Invoice'), findsOneWidget);
    expect(find.text('Rp 900.000'), findsOneWidget);
    expect(find.text('Rincian Item Invoice'), findsOneWidget);
    expect(find.text('Buat & Kirim Invoice'), findsOneWidget);

    final customerWidget = tester.widget<TextField>(
      find.byKey(const Key('input_invoice_customer')),
    );
    expect(customerWidget.controller?.text, 'Pak Reza');
  });

  testWidgets('UcapKasToast displays reusable toast card for Kas Masuk',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                UcapKasToast.showKasMasuk(
                  context,
                  title: 'Servis AC Mobil Avanza',
                  amount: 450000,
                  subtitle: 'Servis • Tunai',
                );
              },
              child: const Text('Trigger Toast'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger Toast'));
    await tester.pump();

    expect(find.byKey(const Key('ucapkas_toast_card')), findsOneWidget);
    expect(find.text('Kas Masuk Tersimpan'), findsOneWidget);
    expect(find.text('Servis AC Mobil Avanza'), findsOneWidget);
    expect(find.text('+Rp 450.000'), findsOneWidget);
  });
}
