import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/theme/app_theme.dart';

/// Emotional milestones — the small, professional "you did it" moments that
/// build attachment (first post, first message, first connection…). Each fires
/// AT MOST ONCE per company, tracked in localStorage keyed by uid (cosmetic, so
/// per-device is fine; avoids Firestore writes + rules). Style is deliberately
/// restrained: a clean accent-circle card that scales in and auto-dismisses —
/// celebratory, never childish.
class Milestone {
  static bool _seen(String uid, String key) {
    try {
      return web.window.localStorage.getItem('ms_${uid}_$key') == '1';
    } catch (_) {
      return true; // storage blocked → don't nag
    }
  }

  static void _mark(String uid, String key) {
    try {
      web.window.localStorage.setItem('ms_${uid}_$key', '1');
    } catch (_) {}
  }

  /// If [key] hasn't fired for [uid] yet, mark it and show the celebration.
  static void celebrateOnce(
    BuildContext context, {
    required String uid,
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    if (uid.isEmpty || _seen(uid, key)) return;
    _mark(uid, key);
    _show(context, icon: icon, title: title, subtitle: subtitle);
  }

  static void _show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ok',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) {
        // Auto-dismiss after a beat so it never blocks the flow.
        Future.delayed(const Duration(milliseconds: 3200), () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        final c = AppColors.of(ctx);
        return Align(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 18),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: c.textPrimary,
                              height: 1.2)),
                      const SizedBox(height: 8),
                      Text(subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13.5, color: c.textSecondary, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
