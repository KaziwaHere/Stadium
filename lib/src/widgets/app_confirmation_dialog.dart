import 'package:flutter/material.dart';
import 'package:stadium/src/theme/app_theme.dart';

Future<bool> showAppConfirmationDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Keep',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _AppConfirmationDialog(
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );

  return result ?? false;
}

class _AppConfirmationDialog extends StatelessWidget {
  const _AppConfirmationDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final confirmColor = isDestructive ? Colors.redAccent : colors.action;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.navFill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: confirmColor.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: confirmColor.withValues(alpha: .28),
                    ),
                  ),
                  child: Icon(icon, color: confirmColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .66),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: colors.glassBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
