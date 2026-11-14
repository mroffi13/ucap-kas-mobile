import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/widgets/pro_badge.dart';
import '../../core/widgets/ucapkas_bottom_nav.dart';
import '../../state/ledger_providers.dart';

class _TeamMember {
  final String name;
  final String initials;
  final String phoneOrNote;
  final String role;
  final bool isOwner;
  final bool isOnline;

  const _TeamMember({
    required this.name,
    required this.initials,
    required this.phoneOrNote,
    required this.role,
    this.isOwner = false,
    this.isOnline = true,
  });
}

class Screen9AkunKas extends ConsumerStatefulWidget {
  const Screen9AkunKas({super.key});

  @override
  ConsumerState<Screen9AkunKas> createState() => _Screen9AkunKasState();
}

class _Screen9AkunKasState extends ConsumerState<Screen9AkunKas> {
  bool _autoCloudSync = true;
  bool _waAutoReminder = true;

  final List<_TeamMember> _members = [
    const _TeamMember(
      name: 'Pak Hendra Jaya (Anda)',
      initials: 'HJ',
      phoneOrNote: 'Pemilik Usaha · Akses Penuh Semua Kas',
      role: 'Pemilik',
      isOwner: true,
      isOnline: true,
    ),
    const _TeamMember(
      name: 'Rian Pratama',
      initials: 'RP',
      phoneOrNote: 'Kepala Mekanik · Catat Servis & Foto Struk',
      role: 'Kasir & Staf',
      isOwner: false,
      isOnline: true,
    ),
    const _TeamMember(
      name: 'Siti Aminah',
      initials: 'SA',
      phoneOrNote: 'Admin Pembukuan · Kelola Nota & Laporan',
      role: 'Admin',
      isOwner: false,
      isOnline: false,
    ),
  ];

  void _showInviteMemberSheet(BuildContext context, String workspaceName) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'Kasir & Staf';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Undang Anggota ke $workspaceName',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Anggota dapat mencatat kas lewat suara atau foto struk dari HP masing-masing.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Anggota / Karyawan',
                      hintText: 'Contoh: Mas Dimas',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp',
                      hintText: 'Contoh: 0812-3456-7890',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hak Akses',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final roleOption in ['Kasir & Staf', 'Admin']) ...[
                        if (roleOption != 'Kasir & Staf')
                          const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(
                              () => selectedRole = roleOption,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selectedRole == roleOption
                                    ? AppColors.primaryTealSoft
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedRole == roleOption
                                      ? AppColors.primaryTeal
                                      : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  roleOption,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: selectedRole == roleOption
                                        ? AppColors.primaryTeal
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final parts = name.split(' ');
                      final initials = parts.length >= 2
                          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                          : name.substring(0, 1).toUpperCase();
                      setState(() {
                        _members.add(
                          _TeamMember(
                            name: name,
                            initials: initials,
                            phoneOrNote: selectedRole == 'Admin'
                                ? 'Admin Pembukuan · Kelola Nota & Laporan'
                                : 'Staf Lapangan · Catat Kas & Foto Struk',
                            role: selectedRole,
                            isOnline: true,
                          ),
                        );
                      });
                      Navigator.of(sheetCtx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Undangan WhatsApp dikirim ke $name ($selectedRole)',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Kirim Undangan via WhatsApp'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspaces = ref.watch(workspacesProvider);
    final activeIdx = ref.watch(activeWorkspaceIndexProvider);
    final activeWs = workspaces[activeIdx];
    final txs = ref.watch(transactionsProvider);

    // Compute live net delta from recorded transactions for the first workspace
    int txDelta = 0;
    for (final tx in txs) {
      txDelta += tx.amount;
    }
    const seededDelta = 450000 - 180000 - 45000 + 95000 + 1250000 - 320000;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // 1. Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Akun & Kas Bersama',
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
                        'Kelola profil usaha, buku kas, dan akses tim',
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
                const ProBadge(label: 'Paket Usaha Aktif'),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Owner Profile & Active Plan Card (Dark Slate Executive Card)
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
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'HJ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Hendra Jaya',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 15,
                                  color: AppColors.incomeEmeraldBright,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '0812-3344-5566 · Terhubung ke WhatsApp & Google',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.darkTextMuted,
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
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.heroCardSecondary,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.22,
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 17,
                              color: AppColors.incomeEmeraldBright,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Paket Usaha Tahunan · Aktif s/d Nov 2027',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Suara tanpa batas, OCR struk & 5 anggota tim',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.darkTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kelola',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.incomeEmeraldBright,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.incomeEmeraldBright,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Multi-Workspace Switcher ("Pilih Buku Kas Aktif")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Pilih Buku Kas Aktif',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${workspaces.length} Buku Kas',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < workspaces.length; i++) ...[
              Builder(
                builder: (context) {
                  final ws = workspaces[i];
                  final isSelected = i == activeIdx;
                  final displayBalance = i == 0
                      ? ws.balance + (txDelta - seededDelta)
                      : ws.balance;
                  final isBusiness = ws.id == 'ws-bengkel';

                  return GestureDetector(
                    key: ValueKey('workspace_card_${ws.id}'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(activeWorkspaceIndexProvider.notifier).state = i;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Buku kas beralih ke ${ws.name}'),
                          duration: const Duration(milliseconds: 1400),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryTeal
                              : AppColors.border,
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryTealSoft
                                  : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isBusiness
                                  ? Icons.storefront_rounded
                                  : Icons.home_work_outlined,
                              size: 20,
                              color: isSelected
                                  ? AppColors.primaryTeal
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        ws.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Saldo Kas: ${RupiahFormatter.format(displayBalance)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.numStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primaryTeal
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryTeal
                                  : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  isSelected ? 'Aktif' : 'Pilih',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],

            // 4. Team Members Section ("Anggota Kas Bersama")
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Anggota ${activeWs.shortName} (${_members.length}/5)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showInviteMemberSheet(context, activeWs.shortName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTealSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ Undang via WA',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _members.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 20, color: AppColors.border),
                    _buildMemberRow(_members[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 5. Preferences & Cloud Backup Section
            Text(
              'Pengaturan Pembukuan & Suara',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  _buildSwitchSettingRow(
                    icon: Icons.cloud_done_outlined,
                    title: 'Cadangan Otomatis (Cloud)',
                    subtitle: 'Tersinkron real-time ke akun Google Anda',
                    value: _autoCloudSync,
                    onChanged: (v) => setState(() => _autoCloudSync = v),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _buildSwitchSettingRow(
                    icon: Icons.mark_chat_unread_outlined,
                    title: 'Pengingat Tagihan WA Otomatis',
                    subtitle: 'Ingatkan pelanggan H-1 sebelum jatuh tempo',
                    value: _waAutoReminder,
                    onChanged: (v) => setState(() => _waAutoReminder = v),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _buildActionSettingRow(
                    icon: Icons.record_voice_over_outlined,
                    title: 'Kamus Suara Bahasa Pasar',
                    trailingLabel: 'Aktif (ID)',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Kamus otomatis mengenali: ceban, gocap, seket, juta, ribu',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 6. Sign Out / Switch Account Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.expenseRose,
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(
                  color: AppColors.expenseRose.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.go('/onboarding'),
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: Text(
                'Keluar / Ganti Akun Usaha',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          const UcapKasBottomNavBar(activeTab: UcapKasTab.akun),
    );
  }

  Widget _buildMemberRow(_TeamMember member) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: member.isOwner
                    ? AppColors.primaryTealSoft
                    : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                member.initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: member.isOwner
                      ? AppColors.primaryTeal
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (member.isOnline)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.incomeEmerald,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                member.phoneOrNote,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: member.isOwner
                ? AppColors.primaryTealSoft
                : AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            member.role,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: member.isOwner
                  ? AppColors.primaryTeal
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  subtitle,
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
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primaryTeal,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSettingRow({
    required IconData icon,
    required String title,
    required String trailingLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailingLabel,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
