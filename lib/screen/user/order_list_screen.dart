import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OrderListScreen extends StatefulWidget {
  final String status;
  final List<dynamic>? orders;

  const OrderListScreen({super.key, required this.status, this.orders});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> with TickerProviderStateMixin {
  late AnimationController _waitAnimController;

  @override
  void initState() {
    super.initState();
    _waitAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waitAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Process and flatten orders to handle multiple items per order structure
    // coming from check_out.dart (where each order has an 'items' list)
    final List<Map<String, dynamic>> displayedItems = [];

    if (widget.orders != null) {
      for (var orderEntry in widget.orders!) {
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
                  itemMap['paymentMethod'] = orderMap['paymentMethod'] ?? itemMap['paymentMethod'];
                  itemMap['paymentProof'] = orderMap['paymentProof'] ?? itemMap['paymentProof'];
                  displayedItems.add(itemMap);
                }
              }
            } else {
              // Fallback for flat structure or already processed items
              displayedItems.add(orderMap);
            }
          }
        } catch (e) {
          // Error processing order entry
        }
      }
    }



    return Scaffold(
      appBar: AppBar(title: Text('${widget.status} Orders')),
      body: Column(
        children: [
          _buildTopNotice(displayedItems.isNotEmpty),
          Expanded(
            child: displayedItems.isEmpty
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
                        'No ${widget.status} orders found',
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
          ),
        ],
      ),
    );
  }

  Widget _buildTopNotice(bool hasItems) {
    if (!hasItems) return const SizedBox.shrink();

    if (widget.status == 'To Verify') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: _buildStatusNotice(
          'An admin will verify your order within 24 hours. Please wait until then.',
          '২৪ ঘণ্টার মধ্যে একজন অ্যাডমিন আপনার অর্ডার যাচাই করবেন, অনুগ্রহ করে ততক্ষণ অপেক্ষা করুন।',
        ),
      );
    } else if (widget.status == 'To Ship') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: _buildStatusNotice(
          'Your order has been accepted. Your product has been handed over to the Steadfast courier service and will take 3-4 days to arrive. Please wait until then.',
          'আপনার অর্ডারটি গ্রহণ করা হয়েছে। আপনার পণ্যটি স্টিডফাস্ট কুরিয়ার সার্ভিসে হস্তান্তর করা হয়েছে এবং পৌঁছাতে ৩-৪ দিন সময় লাগবে। অনুগ্রহ করে ততক্ষণ অপেক্ষা করুন।',
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatusNotice(String englishText, String banglaText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _waitAnimController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _waitAnimController.value * 2 * 3.14159,
                child: const Icon(
                  Icons.hourglass_empty,
                  color: AppColors.warning,
                  size: 28,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  englishText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  banglaText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEF6C00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    // Safely extract data with type checking
    final imageUrl = _safeGetString(order, 'imageUrl');
    final name = _safeGetString(order, 'name') ?? 'Unknown Product';
    final price = _safeGetNum(order, 'price') ?? 0;
    final quantity = _safeGetNum(order, 'quantity') ?? 0;
    final total = price * quantity;
    final paymentProof = _safeGetString(order, 'paymentProof');
    final paymentMethod = _safeGetString(order, 'paymentMethod');

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
            if ((paymentMethod != null && paymentMethod.isNotEmpty) ||
                (paymentProof != null && paymentProof.isNotEmpty)) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          paymentMethod?.toUpperCase() ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (paymentProof != null && paymentProof.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showPaymentProofDialog(context, paymentProof),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: const [
                              Text(
                                'Payment Proof',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tap to view',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Image.network(
                                paymentProof.startsWith('/')
                                    ? "${dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com')}$paymentProof"
                                    : paymentProof,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.broken_image, size: 20, color: AppColors.error);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPaymentProofDialog(BuildContext context, String imageUrl) {
    final fullUrl = imageUrl.startsWith('/')
        ? "${dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com')}$imageUrl"
        : imageUrl;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Proof Screenshot',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: InteractiveViewer(
                  child: Image.network(
                    fullUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            SizedBox(height: 8),
                            Text('Failed to load payment proof image'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
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
      return null;
    }
  }
}
