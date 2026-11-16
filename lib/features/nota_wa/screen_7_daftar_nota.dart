import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/ucapkas_bottom_nav.dart';
import '../../core/widgets/ucapkas_toast.dart';
import '../../data/models/nota_invoice.dart';
import '../../state/ledger_providers.dart';

class Screen7DaftarNota extends ConsumerWidget {
  const Screen7DaftarNota({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allNotas = ref.watch(notaListProvider);
    final selectedStatus = ref.watch(notaFilterStatusProvider);

    final filtered = selectedStatus == null
        ? allNotas
        : allNotas.where((n) => n.status == selectedStatus).toList();

    final unpaidNotas =
        allNotas.where((n) => n.status != NotaStatus.lunas).toList();
    final paidNotas =
        allNotas.where((n) => n.status == NotaStatus.lunas).toList();
    final overdueNotas =
        allNotas.where((n) => n.status == NotaStatus.jatuhTempo).toList();
    final waitingNotas =
        allNotas.where((n) => n.status == NotaStatus.menunggu).toList();

    final unpaidTotal = unpaidNotas.fold<int>(0, (sum, n) => sum + n.amount);
    final paidTotal = paidNotas.fold<int>(0, (sum, n) => sum + n.amount);

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(notaListProvider.notifier).refreshFromServer(),
          child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
          children: [
            // 1. Editorial Page Header + Primary Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tagihan & Nota WA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola piutang pelanggan dan bukti tagihan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => context.push('/buat-nota'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Buat Invoice',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Live Receivables Hero Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Piutang Belum Cair (${unpaidNotas.length} Tagihan)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkTextMuted,
                          ),
                        ),
                      ),
                      if (overdueNotas.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.expenseRose.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${overdueNotas.length} lewat tempo',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.expenseRoseBright,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    RupiahFormatter.format(unpaidTotal),
                    style: AppTheme.numStyle(
                      fontSize: 28,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.heroCardSecondary,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sudah Lunas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.darkTextMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                RupiahFormatter.format(paidTotal),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.numStyle(
                                  fontSize: 14,
                                  color: AppColors.incomeEmeraldBright,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          color: AppColors.darkBorder,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Dokumen',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.darkTextMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${allNotas.length} Invoice (${paidNotas.length} lunas)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Filter Chips with Live Counts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                    ref,
                    'Semua (${allNotas.length})',
                    null,
                    selectedStatus,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    ref,
                    'Menunggu (${waitingNotas.length})',
                    NotaStatus.menunggu,
                    selectedStatus,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    ref,
                    'Lewat Tempo (${overdueNotas.length})',
                    NotaStatus.jatuhTempo,
                    selectedStatus,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    ref,
                    'Lunas (${paidNotas.length})',
                    NotaStatus.lunas,
                    selectedStatus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Grouped Invoice Ledger Sheet (No disconnected card spam)
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Tidak ada invoice pada filter ini.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < filtered.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppColors.border,
                        ),
                      _buildInvoiceRow(context, ref, filtered[i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
        ),
      ),
      bottomNavigationBar:
          const UcapKasBottomNavBar(activeTab: UcapKasTab.notaWa),
    );
  }

  Widget _filterChip(
    WidgetRef ref,
    String label,
    NotaStatus? status,
    NotaStatus? current,
  ) {
    final isSelected = status == current;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(notaFilterStatusProvider.notifier).state = status;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.heroDark : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.heroDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(
    BuildContext context,
    WidgetRef ref,
    NotaInvoice nota,
  ) {
    final (Color badgeBg, Color badgeFg, String badgeText) =
        switch (nota.status) {
      NotaStatus.jatuhTempo => (
          AppColors.expenseSoft,
          AppColors.expenseRose,
          'Lewat Tempo',
        ),
      NotaStatus.menunggu => (
          AppColors.warningSoft,
          AppColors.warningAmber,
          'Menunggu Bayar',
        ),
      NotaStatus.lunas => (
          AppColors.incomeSoft,
          AppColors.incomeEmerald,
          'Lunas',
        ),
    };

    final isPaid = nota.status == NotaStatus.lunas;

    return InkWell(
      onTap: () {
        ref.read(selectedNotaNumberProvider.notifier).state = nota.number;
        context.push('/detail-nota');
      },
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tier 1: Nomor Invoice + Tanggal Terbit & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${nota.number} · ${nota.dateIssued}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.numStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Tier 2: Nama Pelanggan / Pesanan + Nominal Tagihan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    nota.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  RupiahFormatter.format(nota.amount),
                  style: AppTheme.numStyle(
                    fontSize: 15.5,
                    color: isPaid
                        ? AppColors.incomeEmerald
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tier 3: Info Jatuh Tempo & Tombol Aksi Cepat
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    nota.clientContact.trim().isEmpty
                        ? nota.dueDateLabel
                        : '${nota.dueDateLabel} · ${nota.clientContact}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: nota.status == NotaStatus.jatuhTempo
                          ? AppColors.expenseRose
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isPaid)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(notaListProvider.notifier)
                              .markAsPaid(
                                nota.id.isNotEmpty ? nota.id : nota.number,
                              );
                          UcapKasToast.showKasMasuk(
                            context,
                            title: 'Pelunasan ${nota.clientName}',
                            amount: nota.amount,
                            subtitle: '${nota.number} • Lunas & Dicatat ke Kas',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Tandai Lunas',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTealSoft,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tagih WA',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: AppColors.primaryTeal,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Bukti',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
