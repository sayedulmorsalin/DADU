import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/screen/product/product_item.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../services/firebase.dart';
import '../../services/d1.dart';

class Catagory extends StatefulWidget {
  final String catagoryName;
  final String catagoryLogo;

  const Catagory({super.key, required this.catagoryName, required this.catagoryLogo});

  @override
  State<Catagory> createState() => _CatagoryState();
}

class _CatagoryState extends State<Catagory> {
  final dataBase db = dataBase();
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> catagoryProducts = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 1;
  String? selectedBrand;
  String? selectedSubCatagory;
  ScrollController scrollController = ScrollController();

  final List<String> bootSubCatagories = [
    'Boots Master Grade',
    'Boots Master Grade Copy',
    'Boots Copy 4 Grade',
    'Boots China Copy',
  ];

  @override
  void initState() {
    super.initState();
    fetchInitialProducts();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          !isLoading) {
        fetchMoreProducts();
      }
    });
  }

  Future<void> fetchInitialProducts() async {
    setState(() {
      isLoading = true;
      currentPage = 1;
    });

    String? categoryFilter;
    String? searchFilter;

    if (widget.catagoryName.toLowerCase() == 'boots' && selectedSubCatagory == null) {
      searchFilter = 'Boots';
    } else {
      categoryFilter = selectedSubCatagory ?? widget.catagoryName;
    }

    final products = await apiService.fetchProducts(
      category: categoryFilter,
      brand: selectedBrand,
      search: searchFilter,
      limit: 20,
      page: currentPage,
    );
    catagoryProducts = products;
    if (products.isNotEmpty) currentPage++;

    setState(() => isLoading = false);
  }

  Future<void> fetchMoreProducts() async {
    setState(() => isLoadingMore = true);

    String? categoryFilter;
    String? searchFilter;

    if (widget.catagoryName.toLowerCase() == 'boots' && selectedSubCatagory == null) {
      searchFilter = 'Boots';
    } else {
      categoryFilter = selectedSubCatagory ?? widget.catagoryName;
    }

    final moreProducts = await apiService.fetchProducts(
      category: categoryFilter,
      brand: selectedBrand,
      search: searchFilter,
      limit: 20,
      page: currentPage,
    );

    if (moreProducts.isNotEmpty) {
      catagoryProducts.addAll(moreProducts);
      currentPage++;
    }

    setState(() => isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    bool isBoots = widget.catagoryName.toLowerCase() == 'boots';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          selectedSubCatagory ?? selectedBrand ?? widget.catagoryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        controller: scrollController,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.grey[200],
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    widget.catagoryLogo,
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.catagoryName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isBoots) ...[
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                "Select Grade",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            _buildSubCatagoryGrid(),
          ],

          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "Shop by Brand",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          _buildBrandGrid(),
          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ))
          else if (catagoryProducts.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No products found"),
            ))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: catagoryProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.70,
              ),
              itemBuilder: (context, index) {
                final product = catagoryProducts[index];
                return ProductItem(
                  productId: product['id'] ?? '',
                  title: product['name'] ?? 'No Title',
                  price: '৳${product['price']?.toString() ?? '0'}',
                  imagePath:
                      product['image5'] ?? 'assets/demo_item_image/d1.jpg',
                  image20:
                      product['image20'] ?? 'assets/demo_item_image/d1.jpg',
                  description: product['details'] ?? 'No details available',
                  videoLink: product['videoLink'] ?? 'No videoLink available',
                  catagory: product['catagory'] ?? 'Others',
                  image5: product['image5'] ?? 'assets/demo_item_image/d1.jpg',
                  goldCoin: (product['gold_coin'] as num?)?.toDouble() ?? 0.0,
                );
              },
            ),

          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSubCatagoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: bootSubCatagories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.2,
      ),
      itemBuilder: (context, index) {
        return _buildSubCatagoryItem(bootSubCatagories[index]);
      },
    );
  }

  Widget _buildSubCatagoryItem(String sub) {
    bool isSelected = selectedSubCatagory == sub;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selectedSubCatagory == sub) {
            selectedSubCatagory = null;
          } else {
            selectedSubCatagory = sub;
          }
        });
        fetchInitialProducts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceGrey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
        ),
        child: Center(
          child: Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3.2,
      children: [
        _buildBrandItem('Adidas', 'assets/icon/adidas.png'),
        _buildBrandItem('Nike', 'assets/icon/Nike.png'),
        _buildBrandItem('Puma', 'assets/icon/puma.png'),
        _buildBrandItem('Mizuno', 'assets/icon/mizuno.png'),
        _buildBrandItem('Dadu', 'assets/logo/black_logo.png'),
        _buildBrandItem('Others', 'assets/icon/other.png'),
      ],
    );
  }

  Widget _buildBrandItem(String brand, String imagePath) {
    bool isSelected = selectedBrand == brand;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selectedBrand == brand) {
            selectedBrand = null;
          } else {
            selectedBrand = brand;
          }
        });
        fetchInitialProducts();
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceGrey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              brand,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Image.asset(imagePath, width: 35, height: 35, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}
