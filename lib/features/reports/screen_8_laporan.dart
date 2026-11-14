import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/ucapkas_bottom_nav.dart';
import '../../core/widgets/workspace_pill.dart';
import '../../data/repositories/mock_ledger_data.dart';
import '../../state/ledger_providers.dart';

class _MonthReportData {
  final String shortLabel;
  final String fullLabel;
  final int inflow;
  final int outflow;

  const _MonthReportData({
    required this.shortLabel,
    required this.fullLabel,
    required this.inflow,
    required this.outflow,
  });

  int get netProfit => inflow - outflow;

  String get compactProfitLabel {
    final juta = netProfit / 1000000.0;
    return '${juta.toStringAsFixed(1).replaceAll('.', ',')} jt';
  }
}

class _CategoryBreakdownItem {
  final String category;
  final int amount;
  final int txCount;
  final double ratio;

  const _CategoryBreakdownItem({
    required this.category,
    required this.amount,
    required this.txCount,
    required this.ratio,
  });
}

class Screen8Laporan extends ConsumerStatefulWidget {
  const Screen8Laporan({super.key});

  @override
  ConsumerState<Screen8Laporan> createState() => _Screen8LaporanState();
}

class _Screen8LaporanState extends ConsumerState<Screen8Laporan> {
  int _selectedMonthIndex = 5; // Default: Nov 2026 (current live month)
  bool _showExpenseBreakdown = true;

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(activeWorkspaceProvider);
    final allTxs = ref.watch(transactionsProvider);

    // Calculate live delta from newly added transactions beyond initial seed
    final initialNetInflow = MockLedgerData.initialTransactions
        .where((t) => t.isInflow)
        .fold<int>(0, (s, t) => s + t.amount);
    final initialNetOutflow = MockLedgerData.initialTransactions
        .where((t) => !t.isInflow)
        .fold<int>(0, (s, t) => s + t.amount.abs());

    final currentTxInflow = allTxs
        .where((t) => t.isInflow)
        .fold<int>(0, (s, t) => s + t.amount);
    final currentTxOutflow = allTxs
        .where((t) => !t.isInflow)
        .fold<int>(0, (s, t) => s + t.amount.abs());

    final addedInflow =
        (currentTxInflow - initialNetInflow).clamp(0, 999999999);
    final addedOutflow =
        (currentTxOutflow - initialNetOutflow).clamp(0, 999999999);

    final novInflow = ws.monthlyInflow + addedInflow;
    final novOutflow = ws.monthlyOutflow + addedOutflow;

    final months = <_MonthReportData>[
      const _MonthReportData(
        shortLabel: 'Jun',
        fullLabel: 'Juni 2026',
        inflow: 5900000,
        outflow: 2800000,
      ),
      const _MonthReportData(
        shortLabel: 'Jul',
        fullLabel: 'Juli 2026',
        inflow: 6450000,
        outflow: 2850000,
      ),
      const _MonthReportData(
        shortLabel: 'Agu',
        fullLabel: 'Agustus 2026',
        inflow: 6200000,
        outflow: 3000000,
      ),
      const _MonthReportData(
        shortLabel: 'Sep',
        fullLabel: 'September 2026',
        inflow: 7350000,
        outflow: 3250000,
      ),
      const _MonthReportData(
        shortLabel: 'Okt',
        fullLabel: 'Oktober 2026',
        inflow: 7800000,
        outflow: 3400000,
      ),
      _MonthReportData(
        shortLabel: 'Nov',
        fullLabel: 'November 2026',
        inflow: novInflow,
        outflow: novOutflow,
      ),
    ];

    final activeMonth = months[_selectedMonthIndex];
    final netProfit = activeMonth.netProfit;
    final marginPercent = activeMonth.inflow > 0
        ? ((netProfit / activeMonth.inflow) * 100).round().clamp(0, 100)
        : 0;
    final totalCashflow = activeMonth.inflow + activeMonth.outflow;
    final inflowShare = totalCashflow > 0
        ? (activeMonth.inflow / totalCashflow).clamp(0.15, 0.85)
        : 0.5;

    final maxProfit = months
        .map((m) => m.netProfit)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 999999999);

    final breakdownItems = _buildCategoryBreakdown(
      allTxs: allTxs,
      isExpense: _showExpenseBreakdown,
      monthTotal:
          _showExpenseBreakdown ? activeMonth.outflow : activeMonth.inflow,
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
          children: [
            // 1. Editorial Header + Workspace Switcher Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laporan Untung Rugi',
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
                        'Ringkasan arus kas & margin usaha',
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
                const SizedBox(width: 8),
                WorkspacePill(
                  label: ws.shortName,
                  onTap: () => context.go('/akun'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Net Profit Hero Card (Live-Calculated + Cashflow Ratio Bar)
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
                          'Laba Bersih · ${activeMonth.fullLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkTextMuted,
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
                          color: AppColors.heroCardSecondary,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: Text(
                          'Margin $marginPercent%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.incomeEmeraldBright,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    RupiahFormatter.format(netProfit, showSign: true),
                    style: AppTheme.numStyle(
                      fontSize: 28,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Proportional Cashflow Split Bar (Inflow vs Outflow)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (inflowShare * 100).round(),
                            child: Container(
                              color: AppColors.incomeEmeraldBright,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            flex: ((1.0 - inflowShare) * 100).round(),
                            child: Container(
                              color: AppColors.expenseRoseBright,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Inflow vs Outflow Summary Box
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
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.incomeEmeraldBright,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Kas Masuk',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.darkTextMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '+${RupiahFormatter.format(activeMonth.inflow)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.numStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: AppColors.darkBorder,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.expenseRoseBright,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Kas Keluar',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.darkTextMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '-${RupiahFormatter.format(activeMonth.outflow)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.numStyle(
                                  fontSize: 14,
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

            // 3. Interactive 6-Month Profit Trend Chart (With Direct Value Labels)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tren Laba Bersih 6 Bulan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ketuk bulan untuk melihat perbandingan kas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTealSoft,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          activeMonth.shortLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 132,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < months.length; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedMonthIndex = i);
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    months[i].compactProfitLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.numStyle(
                                      fontSize: 10,
                                      fontWeight: i == _selectedMonthIndex
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: i == _selectedMonthIndex
                                          ? AppColors.primaryTeal
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    width: 28,
                                    height: ((months[i].netProfit / maxProfit) *
                                            78.0)
                                        .clamp(18.0, 78.0),
                                    decoration: BoxDecoration(
                                      color: i == _selectedMonthIndex
                                          ? AppColors.primaryTeal
                                          : AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: i == _selectedMonthIndex
                                            ? AppColors.primaryTeal
                                            : AppColors.border,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    months[i].shortLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: i == _selectedMonthIndex
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: i == _selectedMonthIndex
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Category Breakdown Card (Switchable: Pengeluaran vs Pemasukan)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Rincian per Kategori',
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
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTypeTab(
                              label: 'Pengeluaran',
                              selected: _showExpenseBreakdown,
                              onTap: () => setState(
                                () => _showExpenseBreakdown = true,
                              ),
                            ),
                            _buildTypeTab(
                              label: 'Pemasukan',
                              selected: !_showExpenseBreakdown,
                              onTap: () => setState(
                                () => _showExpenseBreakdown = false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (int i = 0; i < breakdownItems.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _buildCategoryBarRow(
                      item: breakdownItems[i],
                      isExpense: _showExpenseBreakdown,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Export Actions (PDF & Excel)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      backgroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'File Excel (${ws.shortName} · ${activeMonth.fullLabel}) berhasil diekspor',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.table_chart_outlined,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    label: Text(
                      'Ekspor Excel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Laporan PDF (${ws.shortName} · ${activeMonth.fullLabel}) berhasil diunduh',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: Text(
                      'Unduh PDF',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          const UcapKasBottomNavBar(activeTab: UcapKasTab.laporan),
    );
  }

  List<_CategoryBreakdownItem> _buildCategoryBreakdown({
    required List allTxs,
    required bool isExpense,
    required int monthTotal,
  }) {
    if (isExpense) {
      final bahanBaku = (monthTotal * 0.56).round();
      final operasional = (monthTotal * 0.28).round();
      final lainnya = (monthTotal - bahanBaku - operasional).clamp(0, monthTotal);
      return [
        _CategoryBreakdownItem(
          category: 'Bahan Baku & Suku Cadang',
          amount: bahanBaku,
          txCount: 9,
          ratio: 0.56,
        ),
        _CategoryBreakdownItem(
          category: 'Operasional & Listrik Bengkel',
          amount: operasional,
          txCount: 5,
          ratio: 0.28,
        ),
        _CategoryBreakdownItem(
          category: 'Konsumsi & Kebutuhan Harian',
          amount: lainnya,
          txCount: 4,
          ratio: 0.16,
        ),
      ];
    } else {
      final servis = (monthTotal * 0.64).round();
      final part = (monthTotal * 0.24).round();
      final pelunasan = (monthTotal - servis - part).clamp(0, monthTotal);
      return [
        _CategoryBreakdownItem(
          category: 'Jasa Servis & Perbaikan',
          amount: servis,
          txCount: 16,
          ratio: 0.64,
        ),
        _CategoryBreakdownItem(
          category: 'Penjualan Oli & Suku Cadang',
          amount: part,
          txCount: 7,
          ratio: 0.24,
        ),
        _CategoryBreakdownItem(
          category: 'Pelunasan Invoice Pelanggan',
          amount: pelunasan,
          txCount: 3,
          ratio: 0.12,
        ),
      ];
    }
  }

  Widget _buildTypeTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x120B1220),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBarRow({
    required _CategoryBreakdownItem item,
    required bool isExpense,
  }) {
    final barColor =
        isExpense ? AppColors.expenseRose : AppColors.incomeEmerald;
    final pct = (item.ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              RupiahFormatter.format(item.amount),
              style: AppTheme.numStyle(
                fontSize: 13.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${item.txCount} catatan transaksi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct% dari total',
              style: AppTheme.numStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            width: double.infinity,
            color: AppColors.background,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: item.ratio.clamp(0.05, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
