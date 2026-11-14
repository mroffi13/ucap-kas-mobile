import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Light Mode Tokens (Nordic Ledger — Calibrated High-Craft Fintech)
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F3F6);
  static const Color heroDark = Color(0xFF0B1220);
  static const Color heroCardSecondary = Color(0xFF172235);
  static const Color textPrimary = Color(0xFF0B1220);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE5E9F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // Brand & Semantic Tokens (Single Accent Discipline — Deep Teal)
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryTealBright = Color(0xFF2DD4BF);
  static const Color primaryTealSoft = Color(0xFFF0FDFA);
  static const Color micRingCyan = Color(0xFF1E293B);
  static const Color sparkGold = Color(0xFFFBBF24);

  static const Color incomeEmerald = Color(0xFF059669);
  static const Color incomeEmeraldBright = Color(0xFF34D399);
  static const Color incomeSoft = Color(0xFFECFDF5);

  static const Color expenseRose = Color(0xFFE11D48);
  static const Color expenseRoseBright = Color(0xFFFB7185);
  static const Color expenseSoft = Color(0xFFFFF1F2);

  static const Color warningAmber = Color(0xFFB45309);
  static const Color warningAmberSoft = Color(0xFFFEF3C7);
  static const Color warningSoft = warningAmberSoft;

  // Dark Mode Tokens
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF172235);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF26334D);

  // Semantic Aliases for Task 5 & 6 Screens
  static const Color bgPage = background;
  static const Color bgCard = surface;
  static const Color bgInput = surfaceSubtle;
  static const Color heroPine = heroDark;
  static const Color borderSubtle = border;
  static const Color emeraldPrimary = primaryTeal;
  static const Color emeraldLight = Color(0xFF99F6E4);
  static const Color mintSuccess = incomeEmeraldBright;
  static const Color terracottaOut = expenseRose;
  static const Color amberWarm = warningAmber;
  static const Color amberLight = sparkGold;
  static const Color textOnDarkMuted = darkTextMuted;
  static const Color bgChipEmerald = primaryTealSoft;
  static const Color bgChipWarm = warningAmberSoft;
  static const Color bgChipDanger = expenseSoft;

  // Ambient Elevation Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x070B1220),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> heroShadow = [
    BoxShadow(
      color: Color(0x1F0B1220),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
