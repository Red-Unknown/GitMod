import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0B1019);
  static const surface = Color(0xFF121B29);
  static const surfaceRaised = Color(0xFF182334);
  static const surfaceMuted = Color(0xFF202D40);
  static const border = Color(0xFF2A3A50);
  static const textPrimary = Color(0xFFF3F6FC);
  static const textSecondary = Color(0xFF9CABBF);
  static const primary = Color(0xFF744BFF);
  static const primaryHover = Color(0xFF8968FF);
  static const success = Color(0xFF45C879);
  static const warning = Color(0xFFF0B653);
  static const danger = Color(0xFFEB6464);
}

abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadii {
  static const small = BorderRadius.all(Radius.circular(4));
  static const medium = BorderRadius.all(Radius.circular(6));
  static const large = BorderRadius.all(Radius.circular(8));
}

abstract final class AppShadows {
  static const panel = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}
