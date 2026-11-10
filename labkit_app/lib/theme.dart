import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All colors used in the app (style A, "Clean Maroon").
class AppColors {
  static const maroon = Color(0xFF500000);
  static const maroonTint = Color(0xFFF3E8E8);
  static const bg = Color(0xFFF6F6F7);
  static const stage = Color(0xFFDCDCE1);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E4E8);
  static const divider = Color(0xFFEDEDF0);
  static const chip = Color(0xFFE9E9ED);
  static const buttonBorder = Color(0xFFD4D4DA);
  static const switchOff = Color(0xFFC9C9D1);
  static const segmentOff = Color(0xFFDCDCE1);

  static const text = Color(0xFF1A1A1F);
  static const text2 = Color(0xFF3A3A44);
  static const body = Color(0xFF2A2A33);
  static const muted = Color(0xFF55555F);
  static const faint = Color(0xFF8A8A93);

  static const green = Color(0xFF1F6F43);
  static const greenTint = Color(0xFFE5F3EA);
  static const greenText = Color(0xFF1A4D31);

  static const warnBg = Color(0xFFFDF1E7);
  static const warnBorder = Color(0xFFF2C9A4);
  static const warnIcon = Color(0xFF9A4A0B);
  static const warnText = Color(0xFF6B3307);

  static const infoBg = Color(0xFFEEF2F8);
  static const infoBorder = Color(0xFFCCD6E6);
  static const infoIcon = Color(0xFF2F4F7F);
  static const infoText = Color(0xFF22385C);
}

class AppFonts {
  static String? get sans => GoogleFonts.inter().fontFamily;

  static TextStyle mono({double size = 14, FontWeight weight = FontWeight.w600, Color color = AppColors.text}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.maroon, primary: AppColors.maroon),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
  );
}

/// Short-hand text style.
TextStyle ts(double size, {FontWeight weight = FontWeight.w400, Color color = AppColors.text, double? height}) =>
    TextStyle(fontFamily: AppFonts.sans, fontSize: size, fontWeight: weight, color: color, height: height);
