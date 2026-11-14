import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class UcapKasLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool darkHeader;

  const UcapKasLogo({
    super.key,
    this.size = 32,
    this.showWordmark = false,
    this.darkHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final rLarge = size * 0.29;
    final rSharp = size * 0.085;
    final barW = size * 0.125;

    final iconMark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryTeal,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(rLarge),
          topRight: Radius.circular(rLarge),
          bottomRight: Radius.circular(rLarge),
          bottomLeft: Radius.circular(rSharp),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: size * 0.22,
            top: size * 0.19,
            child: Container(
              width: barW,
              height: barW,
              decoration: const BoxDecoration(
                color: AppColors.sparkGold,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: size * 0.22,
            top: size * 0.44,
            child: Container(
              width: barW,
              height: size * 0.31,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(barW / 2),
              ),
            ),
          ),
          Positioned(
            left: size * 0.44,
            top: size * 0.31,
            child: Container(
              width: barW,
              height: size * 0.44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(barW / 2),
              ),
            ),
          ),
          Positioned(
            left: size * 0.66,
            top: size * 0.17,
            child: Container(
              width: barW,
              height: size * 0.58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(barW / 2),
              ),
            ),
          ),
          Positioned(
            left: size * 0.22,
            top: size * 0.63,
            child: Container(
              width: size * 0.565,
              height: barW,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(barW / 2),
              ),
            ),
          ),
        ],
      ),
    );

    if (!showWordmark) return iconMark;

    final fontSize = size * 0.56;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconMark,
        SizedBox(width: size * 0.3),
        Text(
          'Ucap',
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: darkHeader ? Colors.white : AppColors.textPrimary,
          ),
        ),
        Text(
          'Kas',
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: darkHeader ? AppColors.primaryTealBright : AppColors.primaryTeal,
          ),
        ),
      ],
    );
  }
}
