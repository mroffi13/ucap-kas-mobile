import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucapkas_app/app.dart';
import 'package:ucapkas_app/core/widgets/ucapkas_logo.dart';

void main() {
  testWidgets('UcapKasApp boots into Splash -> Login -> Dashboard and navigates tabs', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: UcapKasApp(),
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
    expect(find.text('Masuk Lewat WhatsApp'), findsOneWidget);

    // 3. Tap 'Masuk Lewat Google' to enter Dashboard (Screen 1)
    await tester.tap(find.text('Masuk Lewat Google'));
    await tester.pumpAndSettle();

    expect(find.byType(UcapKasLogo), findsOneWidget);
    expect(find.text('Rp 14.850.000'), findsOneWidget);
    expect(find.text('Bicara'), findsOneWidget);

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
}
