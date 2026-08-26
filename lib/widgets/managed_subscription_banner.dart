import 'package:flutter/material.dart';

import '../services/organization_access_service.dart';

class ManagedSubscriptionBanner extends StatelessWidget {
  final OrganizationAccessContext contextData;

  const ManagedSubscriptionBanner({
    required this.contextData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!contextData.managedByOwner) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFF99F6E4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              color: Color(0xFF0F766E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription managed by owner',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (contextData.organizationName.isNotEmpty)
                    Text(
                      contextData.organizationName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (contextData.ownerName.isNotEmpty)
                    Text(
                      'Owner: ${contextData.ownerName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'You are included in the workspace plan and do not need a separate subscription.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
