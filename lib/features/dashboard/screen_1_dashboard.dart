import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/pro_badge.dart';
import '../../core/widgets/ucapkas_bottom_nav.dart';
import '../../core/widgets/ucapkas_logo.dart';
import '../../core/widgets/workspace_pill.dart';
import '../../data/models/cash_transaction.dart';
import '../../state/ledger_providers.dart';

class Screen1Dashboard extends ConsumerWidget {
  const Screen1Dashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(activeWorkspaceProvider);
    final transactions = ref.watch(transactionsProvider).take(4).toList();

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/splash'),
                    child: const UcapKasLogo(
                      size: 30,
                      showWordmark: true,
                    ),
                  ),
                  ProBadge(onTap: () => context.push('/paket-usaha')),
                ],
              ),
              const SizedBox(height: 12),
              // Workspace & Period Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: WorkspacePill(
                      label: workspace.name,
                      onTap: () => context.go('/akun'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.go('/laporan'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Nov 2026',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Bento Saldo Card — High-Craft Fintech Ledger
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.heroDark,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppColors.heroShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Saldo Kas',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkTextMuted,
                          ),
                        ),
                        const Icon(
                          Icons.visibility_outlined,
                          size: 17,
                          color: AppColors.darkTextMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      RupiahFormatter.format(workspace.balance),
                      style: AppTheme.numStyle(
                        fontSize: 30,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 15,
                          color: AppColors.incomeEmeraldBright,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Naik 12,5% dibanding bulan lalu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.incomeEmeraldBright,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        color: AppColors.heroCardSecondary,
                        height: 1,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.south_west_rounded,
                                    size: 13,
                                    color: AppColors.incomeEmeraldBright,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Kas Masuk',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppColors.darkTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                RupiahFormatter.format(
                                  workspace.monthlyInflow,
                                  showSign: true,
                                ),
                                style: AppTheme.numStyle(
                                  fontSize: 14.5,
                                  color: AppColors.incomeEmeraldBright,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: AppColors.heroCardSecondary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.north_east_rounded,
                                    size: 13,
                                    color: AppColors.expenseRoseBright,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Kas Keluar',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppColors.darkTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                RupiahFormatter.format(
                                  -workspace.monthlyOutflow,
                                  showSign: true,
                                ),
                                style: AppTheme.numStyle(
                                  fontSize: 14.5,
                                  color: AppColors.expenseRoseBright,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => context.push('/paket-usaha'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.heroCardSecondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryTealBright,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Catat Suara & Foto Struk Aktif',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.darkTextPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tanpa Batas',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTealBright,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Quick Actions Row
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      label: 'Catat Kas',
                      isPrimary: true,
                      icon: Icons.add_rounded,
                      onTap: () => context.push('/catat-manual'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionButton(
                      label: 'Foto Struk',
                      icon: Icons.camera_alt_outlined,
                      onTap: () => context.push('/foto-struk'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionButton(
                      label: 'Buat Nota',
                      icon: Icons.receipt_long_outlined,
                      onTap: () => context.push('/buat-nota'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaksi Hari Ini',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Selisih hari ini: +Rp 320.000 (4 catatan)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.incomeEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/riwayat-kas'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Semua',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primaryTeal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Grouped Ledger Surface Card for Transactions
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < transactions.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 58,
                          endIndent: 14,
                          color: AppColors.border,
                        ),
                      _TransactionTile(
                        tx: transactions[i],
                        onTap: () => context.push('/ubah-rincian'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: UcapKasBottomNavBar(
        currentIndex: 0,
        onTabSelected: (index) {
          switch (index) {
            case 0:
              context.go('/kas');
            case 1:
              context.go('/nota');
            case 2:
              context.go('/laporan');
            case 3:
              context.go('/akun');
          }
        },
        onBicaraPressed: () => context.push('/bicara'),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primaryTeal : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: isPrimary ? null : Border.all(color: AppColors.border),
          boxShadow: isPrimary ? null : AppColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isPrimary ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: isPrimary ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final CashTransaction tx;
  final VoidCallback onTap;

  const _TransactionTile({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIn = tx.isInflow;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isIn ? AppColors.incomeSoft : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isIn ? Icons.build_outlined : Icons.shopping_bag_outlined,
                size: 17,
                color: isIn ? AppColors.incomeEmerald : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${tx.category}  ·  ${tx.timeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          tx.paymentMethod,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              RupiahFormatter.format(tx.amount, showSign: true),
              style: AppTheme.numStyle(
                fontSize: 13.5,
                color: isIn ? AppColors.incomeEmerald : AppColors.expenseRose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
