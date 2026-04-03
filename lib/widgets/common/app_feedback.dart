import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum AppFeedbackType { info, success, error }

void showAppSnackBar(
  BuildContext context,
  String message, {
  AppFeedbackType type = AppFeedbackType.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();

  final color = switch (type) {
    AppFeedbackType.info => AppTheme.primaryColor,
    AppFeedbackType.success => AppTheme.successColor,
    AppFeedbackType.error => AppTheme.errorColor,
  };

  final icon = switch (type) {
    AppFeedbackType.info => Icons.info_outline_rounded,
    AppFeedbackType.success => Icons.check_circle_outline_rounded,
    AppFeedbackType.error => Icons.error_outline_rounded,
  };

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.elevatedColor,
      content: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
