import 'dart:ui';
import 'package:flutter/material.dart';
import '../design_system.dart';

/// A premium glass-morphism card with blur effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final bool showBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.backgroundColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.glassWhite,
            borderRadius: BorderRadius.circular(borderRadius),
            border: showBorder
                ? Border.all(color: AppColors.glassBorder, width: 1.5)
                : null,
            boxShadow: AppColors.cardShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
