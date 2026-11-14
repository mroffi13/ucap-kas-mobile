import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/ledger_providers.dart';

class Screen10PaketUsaha extends ConsumerStatefulWidget {
  const Screen10PaketUsaha({super.key});

  @override
  ConsumerState<Screen10PaketUsaha> createState() => _Screen10PaketUsahaState();
}

class _Screen10PaketUsahaState extends ConsumerState<Screen10PaketUsaha> {
  bool _isAnnualPlan = true;

  @override
  Widget build(BuildContext context) {
    final activeWs = ref.watch(activeWorkspaceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text(
          'Paket Usaha UcapKas',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // 1. Dark Executive Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.heroDark,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.heroShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.heroCardSecondary,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Text(
                      'AKTIF UNTUK ${activeWs.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.incomeEmeraldBright,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Buka Semua Fitur Suara, Foto Struk & Kas Bersama',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pembukuan usaha rapi otomatis tanpa ketik manual satu per satu.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Features Checklist Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fitur Paket Usaha UMKM',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    'Catat Kas via Suara Bahasa Pasar tanpa batas harian',
                  ),
                  const SizedBox(height: 9),
                  _buildFeatureRow(
                    'Foto Struk Belanja otomatis terbaca per baris barang',
                  ),
                  const SizedBox(height: 9),
                  _buildFeatureRow(
                    'Buat & kirim Nota Tagihan PDF langsung ke WhatsApp',
                  ),
                  const SizedBox(height: 9),
                  _buildFeatureRow(
                    'Kas Bersama hingga 5 HP (Pemilik, Admin & Staf)',
                  ),
                  const SizedBox(height: 9),
                  _buildFeatureRow(
                    'Ekspor Laporan Untung Rugi PDF & Excel kapan saja',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Selectable Annual Plan
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isAnnualPlan = true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isAnnualPlan
                      ? AppColors.primaryTealSoft
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAnnualPlan
                        ? AppColors.primaryTeal
                        : AppColors.border,
                    width: _isAnnualPlan ? 1.8 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Paket Tahunan (12 Bulan)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'HEMAT 32%',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rp 299.000 / tahun',
                      style: AppTheme.numStyle(
                        fontSize: 19,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Setara Rp 24.900/bulan · Gratis 2 bulan dibanding bulanan',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 4. Selectable Monthly Plan
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isAnnualPlan = false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: !_isAnnualPlan
                      ? AppColors.primaryTealSoft
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: !_isAnnualPlan
                        ? AppColors.primaryTeal
                        : AppColors.border,
                    width: !_isAnnualPlan ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paket Bulanan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fleksibel, bisa berhenti kapan saja',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rp 29.000 / bln',
                      style: AppTheme.numStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 5. Primary Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.push('/bayar-qris'),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: Text(
                  _isAnnualPlan
                      ? 'Perpanjang Tahunan via QRIS (Rp 299.000)'
                      : 'Perpanjang Bulanan via QRIS (Rp 29.000)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1.5),
          child: Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
