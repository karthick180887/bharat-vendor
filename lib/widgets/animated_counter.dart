import 'package:flutter/material.dart';
import '../design_system.dart';

/// An animated counter that smoothly animates between number values
class AnimatedCounter extends StatelessWidget {
  final int value;
  final String? prefix;
  final String? suffix;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix,
    this.suffix,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '${prefix ?? ''}${animatedValue.toInt()}${suffix ?? ''}',
          style: style ?? AppTextStyles.h1,
        );
      },
    );
  }
}

/// A larger stat counter with label, icon, and animation
class StatCounter extends StatelessWidget {
  final String label;
  final int value;
  final String? prefix;
  final IconData icon;
  final Color iconColor;

  const StatCounter({
    super.key,
    required this.label,
    required this.value,
    this.prefix,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const Spacer(),
              // Trend indicator placeholder
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.trending_up, size: 14, color: AppColors.success),
                    SizedBox(width: 2),
                    Text(
                      '+12%',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedCounter(
            value: value,
            prefix: prefix,
            style: AppTextStyles.h1.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
