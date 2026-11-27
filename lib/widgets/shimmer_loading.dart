import 'package:flutter/material.dart';

class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerWidget.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.shapeBorder = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  });

  const ShimmerWidget.circular({
    super.key,
    required this.width,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shapeBorder,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RestaurantCardShimmer extends StatelessWidget {
  const RestaurantCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerWidget.rectangular(height: 160),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerWidget.rectangular(width: 180, height: 18),
              ShimmerWidget.rectangular(width: 40, height: 18),
            ],
          ),
          const SizedBox(height: 8),
          const ShimmerWidget.rectangular(width: 120, height: 14),
          const SizedBox(height: 8),
          const ShimmerWidget.rectangular(width: 220, height: 14),
        ],
      ),
    );
  }
}

class RestaurantHeaderShimmer extends StatelessWidget {
  const RestaurantHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 56,
        bottom: 20.0,
        left: 20.0,
        right: 20.0,
      ),
      color: const Color(0xFF282c3f),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerWidget.rectangular(width: 200, height: 26),
          SizedBox(height: 12),
          Row(
            children: [
              ShimmerWidget.rectangular(width: 50, height: 22),
              SizedBox(width: 10),
              ShimmerWidget.rectangular(width: 140, height: 18),
            ],
          ),
          SizedBox(height: 12),
          ShimmerWidget.rectangular(width: 120, height: 16),
          SizedBox(height: 12),
          ShimmerWidget.rectangular(width: 160, height: 16),
          SizedBox(height: 12),
          ShimmerWidget.rectangular(width: 240, height: 14),
        ],
      ),
    );
  }
}

class DishCardShimmer extends StatelessWidget {
  const DishCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerWidget.rectangular(width: 16, height: 16),
                SizedBox(height: 8),
                ShimmerWidget.rectangular(width: 150, height: 18),
                SizedBox(height: 6),
                ShimmerWidget.rectangular(width: 60, height: 16),
                SizedBox(height: 8),
                ShimmerWidget.rectangular(width: 200, height: 12),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: const [
              ShimmerWidget.rectangular(width: 110, height: 110),
              Positioned(
                bottom: -12,
                child: ShimmerWidget.rectangular(
                  width: 80,
                  height: 34,
                  shapeBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryCarouselShimmer extends StatelessWidget {
  const CategoryCarouselShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              children: const [
                ShimmerWidget.circular(width: 72, height: 72),
                SizedBox(height: 8),
                ShimmerWidget.rectangular(width: 50, height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CategoryChipShimmer extends StatelessWidget {
  const CategoryChipShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ShimmerWidget.rectangular(
              width: 80,
              height: 36,
              shapeBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
          );
        },
      ),
    );
  }
}
