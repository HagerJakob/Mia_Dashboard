import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StudySvgAsset extends StatelessWidget {
  const StudySvgAsset({
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    super.key,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      placeholderBuilder: (_) => SizedBox(width: width, height: height),
    );
  }
}
