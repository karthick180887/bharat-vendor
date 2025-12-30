import 'package:flutter/material.dart';
import '../design_system.dart';

enum StatusType { success, warning, error, info, pending }

/// A semantic status badge with icon and color coding
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final bool showIcon;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.showIcon = true,
    this.fontSize = 12,
  });

  Color get _backgroundColor {
    switch (type) {
      case StatusType.success:
        return AppColors.successLight;
      case StatusType.warning:
        return AppColors.warningLight;
      case StatusType.error:
        return AppColors.errorLight;
      case StatusType.info:
        return AppColors.infoLight;
      case StatusType.pending:
        return AppColors.primaryLight;
    }
  }

  Color get _foregroundColor {
    switch (type) {
      case StatusType.success:
        return AppColors.success;
      case StatusType.warning:
        return AppColors.warning;
      case StatusType.error:
        return AppColors.error;
      case StatusType.info:
        return AppColors.info;
      case StatusType.pending:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (type) {
      case StatusType.success:
        return Icons.check_circle_rounded;
      case StatusType.warning:
        return Icons.schedule_rounded;
      case StatusType.error:
        return Icons.cancel_rounded;
      case StatusType.info:
        return Icons.info_rounded;
      case StatusType.pending:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showIcon ? 10 : 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(_icon, size: fontSize + 2, color: _foregroundColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: _foregroundColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
