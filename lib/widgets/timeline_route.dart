import 'package:flutter/material.dart';
import '../design_system.dart';

/// A timeline-style route visualization (pickup → stops → drop)
class TimelineRoute extends StatelessWidget {
  final String pickup;
  final String drop;
  final List<String>? stops;
  final bool compact;

  const TimelineRoute({
    super.key,
    required this.pickup,
    required this.drop,
    this.stops,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final allPoints = [pickup, ...?stops, drop];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(allPoints.length, (index) {
        final isFirst = index == 0;
        final isLast = index == allPoints.length - 1;
        final isStop = !isFirst && !isLast;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  // Dot
                  Container(
                    width: isStop ? 10 : 14,
                    height: isStop ? 10 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFirst
                          ? AppColors.success
                          : isLast
                              ? AppColors.error
                              : AppColors.primary,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isFirst
                                  ? AppColors.success
                                  : isLast
                                      ? AppColors.error
                                      : AppColors.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  // Connector line
                  if (!isLast)
                    Container(
                      width: 2,
                      height: compact ? 20 : 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            isFirst ? AppColors.success : AppColors.primary,
                            isStop
                                ? AppColors.primary
                                : isLast
                                    ? AppColors.error
                                    : AppColors.primary,
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Location text
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : (compact ? 8 : 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFirst
                          ? 'Pickup'
                          : isLast
                              ? 'Drop'
                              : 'Stop $index',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      allPoints[index],
                      style: compact
                          ? AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMain,
                            )
                          : AppTextStyles.bodyMedium,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
