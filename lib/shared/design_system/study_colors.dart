import 'package:flutter/material.dart';

class StudyColors {
  const StudyColors._();

  static const background = Color(0xFFFAF7F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7F2EE);
  static const ink = Color(0xFF2D2930);
  static const mutedInk = Color(0xFF766D7D);
  static const subtleInk = Color(0xFF9A919F);
  static const border = Color(0xFFEDE4DD);
  static const strongBorder = Color(0xFFE2D6CE);

  static const mauve = Color(0xFFA85F82);
  static const mauveDark = Color(0xFF7B405F);
  static const dustyPink = Color(0xFFE7B0C0);
  static const blush = Color(0xFFF9E7ED);
  static const lavender = Color(0xFFA8A0D8);
  static const lilac = Color(0xFFEAE7F7);
  static const sage = Color(0xFF83B99A);
  static const mint = Color(0xFFE4F3EA);
  static const cream = Color(0xFFFFF3D8);
  static const warning = Color(0xFFD18D73);

  static Color tint(Color color, [double alpha = .12]) =>
      color.withValues(alpha: alpha);
}
