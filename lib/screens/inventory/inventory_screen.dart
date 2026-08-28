import 'package:flutter/material.dart';
import '../../widgets/api_list_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiListScreen(
      title: 'Inventory',
      endpoint: '/inventory/items',
      icon: Icons.inventory_2_outlined,
      preferredFields: ['name', 'item_name', 'sku'],
    );
  }
}
