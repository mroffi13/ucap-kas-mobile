import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/rupiah_formatter.dart';

enum UcapKasToastType {
  kasMasuk,
  kasKeluar,
  info,
}

/// Reusable toast notification helper and card widget for UcapKas.
class UcapKasToast {
  const UcapKasToast._();

  static void showKasMasuk(
    BuildContext context, {
    required String title,
    required int amount,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    show(
      context,
      type: UcapKasToastType.kasMasuk,
      headerLabel: 'Kas Masuk Tersimpan',
      title: title,
      subtitle: subtitle,
      amountText: RupiahFormatter.format(amount.abs(), showSign: true),
      duration: duration,
    );
  }

  static void showKasKeluar(
    BuildContext context, {
    required String title,
    required int amount,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    show(
      context,
      type: UcapKasToastType.kasKeluar,
      headerLabel: 'Kas Keluar Tersimpan',
      title: title,
      subtitle: subtitle,
      amountText: RupiahFormatter.format(-amount.abs(), showSign: true),
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String title,
    String headerLabel = 'Berhasil Disimpan',
    String? subtitle,
    String? badgeText,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    show(
      context,
      type: UcapKasToastType.info,
      headerLabel: headerLabel,
      title: title,
      subtitle: subtitle,
      amountText: badgeText,
      duration: duration,
    );
  }

  static void show(
    BuildContext context, {
    required String title,
    String? headerLabel,
    String? subtitle,
    String? amountText,
    UcapKasToastType type = UcapKasToastType.kasMasuk,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: EdgeInsets.zero,
        duration: duration,
        content: UcapKasToastCard(
          type: type,
          headerLabel: headerLabel,
          title: title,
          subtitle: subtitle,
          amountText: amountText,
        ),
      ),
    );
  }
}

class UcapKasToastCard extends StatelessWidget {
  final UcapKasToastType type;
  final String? headerLabel;
  final String title;
  final String? subtitle;
  final String? amountText;

  const UcapKasToastCard({
    super.key,
    required this.type,
    required this.title,
    this.headerLabel,
    this.subtitle,
    this.amountText,
  });

  @override
  Widget build(BuildContext context) {
    final (
      Color accentColor,
      Color iconBgColor,
      IconData iconData,
      String defaultHeader,
    ) = switch (type) {
      UcapKasToastType.kasMasuk => (
          AppColors.incomeEmeraldBright,
          const Color(0xFF0D332B),
          Icons.check_rounded,
          'Kas Masuk Tersimpan',
        ),
      UcapKasToastType.kasKeluar => (
          AppColors.expenseRoseBright,
          const Color(0xFF381524),
          Icons.check_rounded,
          'Kas Keluar Tersimpan',
        ),
      UcapKasToastType.info => (
          AppColors.primaryTealBright,
          const Color(0xFF12323A),
          Icons.check_circle_outline_rounded,
          'Berhasil Disimpan',
        ),
    };

    final resolvedHeader = headerLabel ?? defaultHeader;

    return Container(
      key: const Key('ucapkas_toast_card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.heroDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.darkBorder,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260B1220),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              iconData,
              size: 18,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolvedHeader,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (amountText != null && amountText!.trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                amountText!,
                style: AppTheme.numStyle(
                  fontSize: 13,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
