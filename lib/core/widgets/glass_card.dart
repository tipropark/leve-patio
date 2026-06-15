import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_patio_colors.dart';

/// Card com efeito glassmorphism: fundo semitransparente + blur.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12.0,
    this.borderColor = AppPatioColors.glassBorder,
    this.fillColor = AppPatioColors.glassFill,
    this.blurSigma = 12.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color borderColor;
  final Color fillColor;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
