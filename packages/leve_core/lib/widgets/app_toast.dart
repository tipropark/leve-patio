import 'package:flutter/material.dart';

/// Toasts padronizados — cores derivadas do tema do app consumidor.
class AppToast {
  AppToast._();

  static void success(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    _show(context, message, colors.primary, Icons.check_circle_outline);
  }

  static void error(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    _show(context, message, colors.error, Icons.error_outline);
  }

  static void info(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    _show(context, message, colors.secondary, Icons.info_outline);
  }

  static void _show(
    BuildContext context,
    String message,
    Color iconColor,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final colors = Theme.of(context).colorScheme;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: colors.surfaceContainerHighest,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
