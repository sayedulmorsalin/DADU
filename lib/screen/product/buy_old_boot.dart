import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/d1.dart';
import 'sell_old_product.dart';

class BuyOldBootScreen extends StatefulWidget {
  const BuyOldBootScreen({super.key});

  @override
  State<BuyOldBootScreen> createState() => _BuyOldBootScreenState();
}

class _BuyOldBootScreenState extends State<BuyOldBootScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _hasMore = false;
  int _currentPage = 1;
  final int _pageSize = 20;

  String? _selectedCategory;
  String? _selectedBrand;
  String? _selectedCondition;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Boots',
    'Jerseys',
    'Gloves',
    'Accessories',
    'Other',
  ];

  final List<String> _brands = [
    'All',
    'Nike',
    'Adidas',
    'Puma',
    'Mizuno',
    'Under Armour',
  ];

  final List<String> _conditions = [
    'All Conditions',
    'Like New',
    'Very Good',
    'Good',
    'Fair',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
      });
    }

    try {
      final res = await _apiService.fetchUsedProducts(
        page: _currentPage,
        limit: _pageSize,
        category: (_selectedCategory == null || _selectedCategory == 'All')
            ? null
            : _selectedCategory,
        brand: (_selectedBrand == null || _selectedBrand == 'All') ? null : _selectedBrand,
        condition: (_selectedCondition == null || _selectedCondition == 'All Conditions')
            ? null
            : _selectedCondition,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        final List<Map<String, dynamic>> newItems =
            List<Map<String, dynamic>>.from(res['data'] ?? []);
        final pagination = res['pagination'] ?? {};
        final int pages = pagination['pages'] ?? 1;

        setState(() {
          if (reset) {
            _products = newItems;
          } else {
            _products.addAll(newItems);
          }
          _hasMore = _currentPage < pages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadProducts(reset: true);
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
    _loadProducts(reset: true);
  }

  void _callSeller(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _whatsappSeller(String phone) async {
    if (phone.isEmpty) return;
    // Format to international phone if standard BD number
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('01')) {
      clean = '88$clean';
    }
    final uri = Uri.parse('https://wa.me/$clean');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  void _showProductDetailsModal(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildProductDetailsBottomSheet(product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Buy Old Boot',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellOldProductScreen()),
              ).then((_) => _onRefresh());
            },
            icon: const Icon(Icons.sell_outlined, size: 18, color: Colors.deepOrange),
            label: const Text(
              'Sell Boot',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _isLoading && _products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: _products.isEmpty
                        ? _buildEmptyState()
                        : _buildProductsGrid(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SellOldProductScreen()),
          ).then((_) => _onRefresh());
        },
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Sell Your Boot', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: [
          // Search input
          TextField(
            controller: _searchController,
            onSubmitted: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search pre-owned boots (Nike, Predator, size 42)...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Filter Horizontal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = (_selectedCategory == null && cat == 'All') ||
                    _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1565C0),
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat == 'All' ? null : cat;
                      });
                      _loadProducts(reset: true);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Brand Filter Horizontal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _brands.map((brand) {
                final isSelected = (_selectedBrand == null && brand == 'All') ||
                    _selectedBrand == brand;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(brand),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D47A1),
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (selected) {
                      setState(() {
                        _selectedBrand = brand == 'All' ? null : brand;
                      });
                      _loadProducts(reset: true);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Condition Filter Horizontal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _conditions.map((condition) {
                final isSelected = (_selectedCondition == null && condition == 'All Conditions') ||
                    _selectedCondition == condition;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(condition),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    selected: isSelected,
                    selectedColor: Colors.deepOrange,
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCondition =
                            condition == 'All Conditions' ? null : condition;
                      });
                      _loadProducts(reset: true);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.64,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _products.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, index) {
        if (index == _products.length) {
          // Load more button / spinner
          return Center(
            child: TextButton(
              onPressed: () {
                _currentPage++;
                _loadProducts(reset: false);
              },
              child: const Text('Load More'),
            ),
          );
        }

        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'Pre-owned Boot';
    final double price = (product['price'] is num) ? (product['price'] as num).toDouble() : 0.0;
    final double? originalPrice = (product['originalPrice'] is num)
        ? (product['originalPrice'] as num).toDouble()
        : null;
    final String condition = product['condition'] ?? 'Good';
    final String size = product['size'] ?? '';
    final String brand = product['brand'] ?? '';
    final String imageUrl = ApiService.resolveUrl(product['imagePrimary']?.toString() ?? '');

    return GestureDetector(
      onTap: () => _showProductDetailsModal(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with condition badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.grey, size: 28),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
                // Pre-owned / condition badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      condition,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (size.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        size,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Product Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (brand.isNotEmpty)
                    Text(
                      brand.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '৳${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      if (originalPrice != null && originalPrice > price) ...[
                        const SizedBox(width: 6),
                        Text(
                          '৳${originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shopping_bag_outlined, size: 54, color: Color(0xFF0D47A1)),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'No Used Boots Available Right Now',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Be the first to list your old boots for other players to buy!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellOldProductScreen()),
              ).then((_) => _onRefresh());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.sell_outlined),
            label: const Text('Sell Your Boot Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildProductDetailsBottomSheet(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'Pre-owned Boot';
    final double price = (product['price'] is num) ? (product['price'] as num).toDouble() : 0.0;
    final double? originalPrice = (product['originalPrice'] is num)
        ? (product['originalPrice'] as num).toDouble()
        : null;
    final String details = product['details'] ?? 'No additional details provided.';
    final String condition = product['condition'] ?? 'Good';
    final String size = product['size'] ?? 'N/A';
    final String brand = product['brand'] ?? '';
    final String imageUrl = ApiService.resolveUrl(product['imagePrimary']?.toString() ?? '');
    final String phone = product['userPhone'] ?? '';
    final String sellerName = product['userName'] ?? 'Seller';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1.25,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name & Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (brand.isNotEmpty)
                          Text(
                            brand.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '৳${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      if (originalPrice != null && originalPrice > price)
                        Text(
                          '৳${originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Chips for Condition, Size, Status
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTagChip('Condition: $condition', Colors.deepOrange),
                  if (size.isNotEmpty && size != 'N/A')
                    _buildTagChip('Size: $size', Colors.blue.shade700),
                  _buildTagChip('Admin Approved ✓', Colors.green.shade700),
                ],
              ),
              const SizedBox(height: 18),

              // Description
              const Text(
                'Product Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                details,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Seller info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sellerName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            phone.isNotEmpty ? phone : 'Verified Member',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Contact Buttons
              if (phone.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _callSeller(phone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.phone),
                        label: const Text('Call Seller', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _whatsappSeller(phone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
