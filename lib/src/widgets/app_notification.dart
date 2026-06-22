import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:stadium/src/theme/app_theme.dart';

enum AppNotificationType { success, info, warning, error }

OverlayEntry? _activeNotification;

void showAppNotification(
  BuildContext context, {
  required String title,
  required String message,
  AppNotificationType type = AppNotificationType.info,
}) {
  final colors = context.appColors;
  final accent = _accentFor(type, colors);
  final icon = _iconFor(type);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);

  if (overlay == null) return;

  _activeNotification?.remove();
  _activeNotification = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AnimatedAppNotification(
      accent: accent,
      icon: icon,
      title: title,
      message: message,
      colors: colors,
      onDismissed: () {
        if (_activeNotification == entry) {
          _activeNotification = null;
        }
        entry.remove();
      },
    ),
  );

  _activeNotification = entry;
  overlay.insert(entry);
}

class _AnimatedAppNotification extends StatefulWidget {
  const _AnimatedAppNotification({
    required this.accent,
    required this.icon,
    required this.title,
    required this.message,
    required this.colors,
    required this.onDismissed,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String message;
  final AppColors colors;
  final VoidCallback onDismissed;

  @override
  State<_AnimatedAppNotification> createState() =>
      _AnimatedAppNotificationState();
}

class _AnimatedAppNotificationState extends State<_AnimatedAppNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .78, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    _scale = Tween<double>(
      begin: .94,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _slide = Tween<Offset>(
      begin: const Offset(0, .32),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 36 + MediaQuery.paddingOf(context).bottom,
      child: SafeArea(
        top: false,
        child: IgnorePointer(
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: _AppNotificationCard(
                  accent: widget.accent,
                  icon: widget.icon,
                  title: widget.title,
                  message: widget.message,
                  colors: widget.colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppNotificationCard extends StatelessWidget {
  const _AppNotificationCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.message,
    required this.colors,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String message;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.navFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .26),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: accent.withValues(alpha: .32)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .68),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.25,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _accentFor(AppNotificationType type, AppColors colors) {
  return switch (type) {
    AppNotificationType.success => colors.selection,
    AppNotificationType.info => colors.star,
    AppNotificationType.warning => const Color(0xFFFFB86B),
    AppNotificationType.error => const Color(0xFFFF6B7A),
  };
}

IconData _iconFor(AppNotificationType type) {
  return switch (type) {
    AppNotificationType.success => Icons.check_circle_rounded,
    AppNotificationType.info => Icons.info_rounded,
    AppNotificationType.warning => Icons.access_time_filled_rounded,
    AppNotificationType.error => Icons.error_rounded,
  };
}
