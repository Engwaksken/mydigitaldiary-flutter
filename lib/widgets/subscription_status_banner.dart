import 'package:flutter/material.dart';

class SubscriptionStatusBanner extends StatelessWidget {
  const SubscriptionStatusBanner({
    super.key,
    required this.subscriptionStatus,
    required this.isSuspended,
    required this.isAdmin,
    required this.onTrial,
    required this.trialDaysLeft,
    required this.subscriptionExpiry,
    this.onOpenSubscription,
  });

  final String? subscriptionStatus;
  final bool isSuspended;
  final bool isAdmin;
  final bool onTrial;
  final int trialDaysLeft;
  final DateTime? subscriptionExpiry;
  final VoidCallback? onOpenSubscription;

  bool get _isActive =>
      (subscriptionStatus ?? '').trim().toLowerCase() == 'active';

  int? get _daysUntilExpiry {
    final expiry = subscriptionExpiry;
    if (expiry == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(expiry.year, expiry.month, expiry.day);

    return end.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (isSuspended) {
      return _Banner(
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFF991B1B),
        icon: Icons.block_rounded,
        message: 'Your account has been suspended.',
        actionLabel: 'View details',
        onAction: onOpenSubscription,
      );
    }

    // ACTIVE SUBSCRIPTION ALWAYS TAKES PRIORITY OVER TRIAL.
    if (_isActive) {
      final daysLeft = _daysUntilExpiry;

      // Active and more than 14 days remaining = no dashboard banner.
      if (daysLeft == null || daysLeft > 14) {
        return const SizedBox.shrink();
      }

      // If the active expiry is already in the past, treat it as expired.
      if (daysLeft < 0) {
        return _Banner(
          background: const Color(0xFFFEE2E2),
          foreground: const Color(0xFF991B1B),
          icon: Icons.warning_amber_rounded,
          message: 'Your subscription has expired.',
          actionLabel: 'Renew subscription',
          onAction: onOpenSubscription,
        );
      }

      final message = switch (daysLeft) {
        0 => 'Your subscription expires today.',
        1 => 'Your subscription expires tomorrow.',
        _ => 'Your subscription expires in $daysLeft days.',
      };

      return _Banner(
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFF92400E),
        icon: Icons.schedule_rounded,
        message: message,
        actionLabel: 'Renew now',
        onAction: onOpenSubscription,
      );
    }

    // Trial is only visible when subscription_status is NOT active.
    if (onTrial) {
      return _Banner(
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFF92400E),
        icon: Icons.schedule_rounded,
        message: '$trialDaysLeft day(s) left in your free trial.',
        actionLabel: 'Subscribe',
        onAction: onOpenSubscription,
      );
    }

    if (!isAdmin) {
      return _Banner(
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFF991B1B),
        icon: Icons.warning_amber_rounded,
        message: 'Your subscription has expired or is inactive.',
        actionLabel: 'Renew subscription',
        onAction: onOpenSubscription,
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: foreground,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

DateTime? parseSubscriptionExpiry(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) {
    return value.toLocal();
  }

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  try {
    return DateTime.parse(text).toLocal();
  } catch (_) {
    return null;
  }
}

DateTime? resolveSubscriptionExpiry(Map<String, dynamic> user) {
  return parseSubscriptionExpiry(
    user['subscription_expires_at'] ??
        user['subscription_ends_at'] ??
        user['subscription_end_date'] ??
        user['subscription_expiry_date'],
  );
}
