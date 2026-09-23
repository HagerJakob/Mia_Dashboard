import 'package:flutter/widgets.dart';

class StudyRadius {
  const StudyRadius._();

  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
  static const pill = 999.0;

  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get full => BorderRadius.circular(pill);
}
