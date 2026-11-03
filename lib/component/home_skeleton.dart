import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Base shimmer wrapper for building skeleton placeholders
class ShimmerWidget extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerWidget({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey.shade300,
      highlightColor: highlightColor ?? Colors.grey.shade100,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Generic skeleton container (box / circle / pill)
class SkeletonContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? margin;

  const SkeletonContainer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape,
    this.margin,
  });

  const SkeletonContainer.circular({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = const CircleBorder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: shape != null
          ? ShapeDecoration(color: Colors.white, shape: shape!)
          : BoxDecoration(
              color: Colors.white,
              borderRadius: borderRadius ?? BorderRadius.circular(8),
            ),
    );
  }
}

/// Product card skeleton matching ProductItem layout
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Card(
        color: AppColors.cardBackground,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: SizedBox(
          height: 255,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              const SkeletonContainer(
                height: 135,
                width: double.infinity,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title placeholder
                    const SkeletonContainer(
                      height: 16,
                      width: double.infinity,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 2),
                    // Price and cash back row placeholder
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SkeletonContainer(
                          height: 15,
                          width: 55,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        SkeletonContainer(
                          height: 16,
                          width: 65,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // View Product button placeholder
                    SkeletonContainer(
                      height: 34,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(12),
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

/// Banner section skeleton
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bannerHeight = MediaQuery.of(context).size.width / 2.16;
    return ShimmerWidget(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SkeletonContainer(
          width: double.infinity,
          height: bannerHeight,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Quick action buttons skeleton ("Buy Old Boot" / "Sell Old Boot")
class ActionButtonsSkeleton extends StatelessWidget {
  const ActionButtonsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: SkeletonContainer(
                height: 68,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SkeletonContainer(
                height: 68,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brands horizontal row skeleton
class BrandsSkeleton extends StatelessWidget {
  const BrandsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: List.generate(
            6,
            (index) => Container(
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                children: const [
                  SkeletonContainer.circular(size: 60),
                  SizedBox(height: 6),
                  SkeletonContainer(
                    width: 44,
                    height: 11,
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Categories 2-column grid skeleton
class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: List.generate(
            6,
            (index) => SkeletonContainer(
              height: 48,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flash sale section skeleton
class FlashSaleSkeleton extends StatelessWidget {
  const FlashSaleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SkeletonContainer(
          width: double.infinity,
          height: 240,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Product grid skeleton (used when products are loading or for sliver feed)
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const ProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 255,
      ),
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}

/// Sliver version of product grid skeleton
class SliverProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const SliverProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 255,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ProductCardSkeleton(),
          childCount: itemCount,
        ),
      ),
    );
  }
}

/// Bottom skeleton shown when loading more products via infinite scroll
class ProductLoadMoreSkeleton extends StatelessWidget {
  const ProductLoadMoreSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: const [
          Expanded(child: ProductCardSkeleton()),
          SizedBox(width: 10),
          Expanded(child: ProductCardSkeleton()),
        ],
      ),
    );
  }
}

/// Full screen Home skeleton displayed while initial data is being fetched
class HomeFullSkeleton extends StatelessWidget {
  const HomeFullSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner skeleton
          const BannerSkeleton(),
          // Action buttons skeleton
          const ActionButtonsSkeleton(),
          // Section: Brand
          _buildSkeletonTitle('Brand'),
          const BrandsSkeleton(),
          // Section: Category
          _buildSkeletonTitle('Catagory'),
          const CategorySkeleton(),
          const SizedBox(height: 12),
          // Section: Flash Sale skeleton
          const FlashSaleSkeleton(),
          const SizedBox(height: 12),
          // Section: Recommended For You
          _buildSkeletonTitle('Recommended For You'),
          const ProductGridSkeleton(itemCount: 4),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSkeletonTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

