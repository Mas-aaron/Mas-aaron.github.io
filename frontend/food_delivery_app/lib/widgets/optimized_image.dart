import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final Color? shimmerBaseColor;
  final Color? shimmerHighlightColor;

  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildShimmerPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
        memCacheWidth: width != null ? (width! * 2).toInt() : null,
        memCacheHeight: height != null ? (height! * 2).toInt() : null,
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: shimmerBaseColor ?? Colors.grey.shade300,
      highlightColor: shimmerHighlightColor ?? Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (errorWidget != null) {
      return errorWidget!;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade300,
            Colors.orange.shade600,
          ],
        ),
        borderRadius: borderRadius,
      ),
      child: const Icon(
        Icons.restaurant,
        size: 50,
        color: Colors.white,
      ),
    );
  }
}

class RestaurantCardImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final BorderRadius borderRadius;

  const RestaurantCardImage({
    Key? key,
    required this.imageUrl,
    this.height = 140,
    required this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OptimizedImage(
      imageUrl: imageUrl,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      shimmerBaseColor: Colors.orange.shade100,
      shimmerHighlightColor: Colors.orange.shade50,
    );
  }
}

class MenuItemImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BorderRadius borderRadius;

  const MenuItemImage({
    Key? key,
    required this.imageUrl,
    this.size = 120,
    BorderRadius? borderRadius,
  })  : borderRadius = borderRadius ?? const BorderRadius.all(Radius.circular(16)),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return OptimizedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      shimmerBaseColor: Colors.grey.shade200,
      shimmerHighlightColor: Colors.grey.shade50,
    );
  }
}

class RestaurantLogoImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const RestaurantLogoImage({
    Key? key,
    required this.imageUrl,
    this.size = 60,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: OptimizedImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: const Icon(Icons.restaurant, size: 30),
        ),
      ),
    );
  }
}
