import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/auth_provider.dart';
import '../../state/ledger_providers.dart';
import '../theme/app_colors.dart';

class ProBadge extends ConsumerWidget {
  final VoidCallback? onTap;
  final String? label;

  const ProBadge({
    super.key,
    this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final activeWs = ref.watch(activeWorkspaceProvider);
    final authUser = authState.user;

    final isPro = label != null
        ? true
        : (authUser != null ? (authUser.isPro || activeWs.isPro) : activeWs.isPro);

    final resolvedLabel = label ??
        (authUser != null
            ? authUser.shortPlanBadge
            : (activeWs.isPro ? 'Paket Usaha Pro' : 'Paket Starter'));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isPro ? AppColors.primaryTealSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPro
                ? AppColors.primaryTeal.withValues(alpha: 0.22)
                : AppColors.borderStrong,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isPro ? AppColors.primaryTeal : AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              resolvedLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: isPro ? AppColors.primaryTeal : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
