import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dish_model.dart';
import '../models/restaurant_model.dart';
import '../providers/app_providers.dart';

class DishDetailsBottomSheet extends ConsumerStatefulWidget {
  final DishModel dish;
  final String? restaurantId;
  final String? restaurantName;

  const DishDetailsBottomSheet({
    super.key,
    required this.dish,
    this.restaurantId,
    this.restaurantName,
  });

  static void show(
    BuildContext context,
    DishModel dish, {
    String? restaurantId,
    String? restaurantName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DishDetailsBottomSheet(
        dish: dish,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      ),
    );
  }

  @override
  ConsumerState<DishDetailsBottomSheet> createState() => _DishDetailsBottomSheetState();
}

class _DishDetailsBottomSheetState extends ConsumerState<DishDetailsBottomSheet> {
  int _quantity = 1;
  final TextEditingController _instructionController = TextEditingController();

  Widget _buildVegIndicator(bool isVeg) {
    return Container(
      width: 16,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
          color: isVeg ? Colors.green[700]! : Colors.red[700]!,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isVeg ? Colors.green[700] : Colors.red[700],
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  String _resolveRestaurantName(WidgetRef ref) {
    if (widget.restaurantName != null && widget.restaurantName!.isNotEmpty) {
      return widget.restaurantName!;
    }
    if (widget.dish.restaurantName != null && widget.dish.restaurantName!.isNotEmpty) {
      return widget.dish.restaurantName!;
    }
    final rId = widget.restaurantId ?? widget.dish.restaurantId;
    if (rId != null) {
      final restaurantsAsync = ref.watch(restaurantsProvider);
      final restaurants = restaurantsAsync.value ?? [];
      final match = restaurants.firstWhere(
        (r) => r.id == rId,
        orElse: () => RestaurantModel(id: rId, name: 'pranjal', address: ''),
      );
      return match.name;
    }
    return 'pranjal';
  }

  void _onAddToCart(String rId, String rName) {
    for (int i = 0; i < _quantity; i++) {
      final result = ref.read(cartProvider.notifier).addItem(
            widget.dish,
            rId,
            rName,
          );

      if (result == AddItemResult.restaurantConflict && i == 0) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Replace cart items?'),
            content: Text('Your cart contains items from another restaurant. Do you want to discard them and add items from $rName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).addItem(
                        widget.dish,
                        rId,
                        rName,
                        forceClear: true,
                      );
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.dish.name} added to cart')),
                  );
                },
                child: const Text('REPLACE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.dish.name} (x$_quantity) added to cart!'),
        backgroundColor: const Color(0xFF60b246),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dish = widget.dish;
    final rId = widget.restaurantId ?? dish.restaurantId ?? 'd4afb18f-307c-4af2-9aa3-6085bfd8e7ea';
    final rName = _resolveRestaurantName(ref);
    final dbImageUrl = dish.imageUrl;
    final totalPrice = dish.price * _quantity;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Modal Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Banner with Close Button
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: (dbImageUrl != null && dbImageUrl.isNotEmpty)
                              ? Image.network(
                                  dbImageUrl,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.fastfood, size: 56, color: Colors.grey),
                                          SizedBox(height: 8),
                                          Text('No Image Available', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.fastfood, size: 56, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('No Image Available', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          radius: 18,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      if (dish.discountBadge != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.pink,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dish.discountBadge!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Veg/Non-Veg & Restaurant Name Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildVegIndicator(dish.isVeg),
                          const SizedBox(width: 8),
                          Text(
                            dish.isVeg ? 'PURE VEG' : 'NON-VEG',
                            style: TextStyle(
                              color: dish.isVeg ? Colors.green[800] : Colors.red[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront, size: 14, color: Color(0xFFfc8019)),
                            const SizedBox(width: 4),
                            Text(
                              'By $rName',
                              style: const TextStyle(
                                color: Color(0xFFe65100),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Text(
                    dish.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),

                  const SizedBox(height: 8),

                  // Price Section
                  Row(
                    children: [
                      Text(
                        '₹${dish.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      if (dish.originalPrice != null && dish.originalPrice! > dish.price) ...[
                        const SizedBox(width: 10),
                        Text(
                          '₹${dish.originalPrice!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Description
                  if (dish.description != null && dish.description!.isNotEmpty) ...[
                    const Text('About this dish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      dish.description!,
                      style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Special Cooking Instructions Input
                  TextField(
                    controller: _instructionController,
                    decoration: InputDecoration(
                      hintText: 'Add cooking instructions (e.g. less spicy, extra dip)',
                      prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Sticky Bottom Zomato-Style Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Quantity Counter (- QTY +)
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.green),
                          onPressed: () {
                            if (_quantity > 1) {
                              setState(() => _quantity--);
                            }
                          },
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () {
                            setState(() => _quantity++);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // ADD ITEM Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF60b246), // Swiggy/Zomato green
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: () => _onAddToCart(rId, rName),
                        child: Text(
                          'ADD ITEM • ₹${totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
