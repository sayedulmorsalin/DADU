import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';

class OrderListScreen extends StatelessWidget {
  final String status;
  final List<dynamic>? orders;

  const OrderListScreen({super.key, required this.status, this.orders});

  @override
  Widget build(BuildContext context) {
    // Process and flatten orders to handle multiple items per order structure
    // coming from check_out.dart (where each order has an 'items' list)
    final List<Map<String, dynamic>> displayedItems = [];

    if (orders != null) {
      for (var orderEntry in orders!) {
        try {
          if (orderEntry is Map) {
            final orderMap = Map<String, dynamic>.from(orderEntry);

            // If this is an order container with an 'items' list
            if (orderMap.containsKey('items') && orderMap['items'] is List) {
              final items = orderMap['items'] as List;
              for (var itemEntry in items) {
                if (itemEntry is Map) {
                  final itemMap = Map<String, dynamic>.from(itemEntry);
                  // Enrich item with order-level metadata
                  itemMap['_order_id'] = orderMap['order_id'];
                  itemMap['_order_date'] = orderMap['order_date'];
                  displayedItems.add(itemMap);
                }
              }
            } else {
              // Fallback for flat structure or already processed items
              displayedItems.add(orderMap);
            }
          }
        } catch (e) {
          debugPrint('Error processing order entry: $e');
        }
      }
    }

    // Debug logging
    debugPrint('\n===== ORDER LIST SCREEN RECEIVED DATA =====');
    debugPrint('Status: $status');
    debugPrint('Original Orders Count: ${orders?.length ?? 0}');
    debugPrint('Flattened Items Count: ${displayedItems.length}');
    debugPrint('===========================================\n');

    return Scaffold(
      appBar: AppBar(title: Text('$status Orders')),
      body:
          displayedItems.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No $status orders found',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: displayedItems.length,
                itemBuilder: (context, index) {
                  final item = displayedItems[index];
                  return _buildOrderCard(item, index);
                },
              ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    // Debug individual order
    print('Order $index: $order');
    print('Order $index type: ${order.runtimeType}');
    print('Order $index keys: ${order.keys.toList()}');

    // Safely extract data with type checking
    final imageUrl = _safeGetString(order, 'imageUrl');
    final name = _safeGetString(order, 'name') ?? 'Unknown Product';
    final price = _safeGetNum(order, 'price') ?? 0;
    final quantity = _safeGetNum(order, 'quantity') ?? 0;
    final total = price * quantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.surfaceGrey,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image_not_supported);
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.surfaceGrey,
                    ),
                    child: const Icon(Icons.shopping_bag),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.containsKey('_order_id')
                            ? 'Order ${order['_order_id']}'
                            : 'Order #${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '৳${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      quantity.toStringAsFixed(0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '৳${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Coins',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      ((_safeGetNum(order, 'freeCoin') ?? 0) * quantity).toStringAsFixed(0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for safe data extraction
  String? _safeGetString(Map<String, dynamic> map, String key) {
    try {
      final value = map[key];
      if (value == null) return null;
      return value.toString();
    } catch (e) {
      print('Error getting string $key: $e');
      return null;
    }
  }

  num? _safeGetNum(Map<String, dynamic> map, String key) {
    try {
      final value = map[key];
      if (value == null) return null;
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
      return null;
    } catch (e) {
      print('Error getting number $key: $e');
      return null;
    }
  }
}
