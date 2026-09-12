import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/branding_service.dart';

/// Shared between DashboardScreen's 5-item quick glance and
/// RecentActivityScreen's full "View All" list, so both render each
/// item identically rather than duplicating this logic in two places.
class RecentActivityTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const RecentActivityTile({super.key, required this.item});

  String _money(num amount) {
    return (BrandingService.cached ?? BrandingInfo(siteName: ''))
        .formatMoney(amount);
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (item['icon']) {
      'income' => Icons.trending_up,
      'reminder' => Icons.notifications_outlined,
      'business_card' => Icons.badge_outlined,
      _ => Icons.receipt_long,
    };
    final color = switch (item['icon']) {
      'income' => const Color(0xFF059669),
      'reminder' => const Color(0xFFD97706),
      'business_card' => const Color(0xFF00897B),
      _ => const Color(0xFFE11D48),
    };
    final time = DateTime.tryParse(item['time'] ?? '')?.toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(item['text'] ?? '', style: const TextStyle(fontSize: 13)),
        trailing: item['amount'] != null
            ? Text(_money(item['amount']),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color))
            : (time != null
                ? Text(DateFormat('MMM d').format(time),
                    style: const TextStyle(fontSize: 11, color: Colors.grey))
                : null),
      ),
    );
  }
}
