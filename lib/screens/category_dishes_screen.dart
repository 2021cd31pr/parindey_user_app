import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dish_model.dart';
import '../providers/app_providers.dart';
import '../widgets/floating_active_order_card.dart';
import '../widgets/dish_details_bottom_sheet.dart';
import 'cart_screen.dart';

class CategoryDishesScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryDishesScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<CategoryDishesScreen> createState() => _CategoryDishesScreenState();
}

class _CategoryDishesScreenState extends ConsumerState<CategoryDishesScreen> {
  final List<String> itemImages = [
    'https://images.unsplash.com/photo-1589302168068-964664d93cb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1513104890138-7c749659a591?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
  ];

  void _onAddToCart(DishModel dish) {
    final rId = dish.restaurantId ?? 'd4afb18f-307c-4af2-9aa3-6085bfd8e7ea';
    final rName = dish.restaurantName ?? 'Restaurant';

    final result = ref.read(cartProvider.notifier).addItem(
          dish,
          rId,
          rName,
        );

    if (result == AddItemResult.restaurantConflict) {
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
                      dish,
                      rId,
                      rName,
                      forceClear: true,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${dish.name} added to cart')),
                );
              },
              child: const Text('REPLACE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${dish.name} added to cart'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final dishesAsync = ref.watch(dishesByCategoryProvider(widget.categoryId));
    final cartState = ref.watch(cartProvider);
    final activeOrder = ref.watch(activeOrderProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.categoryName,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text(
              'Dishes available near you',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: dishesAsync.when(
        data: (dishes) {
          if (dishes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No dishes available for "${widget.categoryName}" in your area',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: dishes.length,
            itemBuilder: (context, index) {
              final dish = dishes[index];
              final fallbackImage = itemImages[index % itemImages.length];
              final displayImage = (dish.imageUrl != null && dish.imageUrl!.isNotEmpty)
                  ? dish.imageUrl!
                  : fallbackImage;

              final cartItem = cartState.items[dish.id];
              final itemQty = cartItem?.quantity ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    DishDetailsBottomSheet.show(context, dish);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Details Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildVegIndicator(dish.isVeg),
                                const SizedBox(width: 8),
                                if (dish.discountBadge != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.pink[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      dish.discountBadge!,
                                      style: const TextStyle(color: Colors.pink, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dish.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '₹${dish.price.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                if (dish.originalPrice != null && dish.originalPrice! > dish.price) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${dish.originalPrice!.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (dish.description != null && dish.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                dish.description!,
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (dish.restaurantName != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.storefront, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    dish.restaurantName!,
                                    style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Image & Add Button
                      Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 110,
                              height: 110,
                              color: Colors.grey[200],
                              child: Image.network(
                                displayImage,
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.network(
                                    fallbackImage,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -15,
                            child: itemQty == 0
                                ? InkWell(
                                    onTap: () => _onAddToCart(dish),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withValues(alpha: 0.3),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: const Text(
                                        'ADD',
                                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  )
                                : Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(alpha: 0.3),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          icon: const Icon(Icons.remove, size: 18, color: Colors.green),
                                          onPressed: () => ref.read(cartProvider.notifier).decrementQuantity(dish.id),
                                        ),
                                        Text(
                                          '$itemQty',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          icon: const Icon(Icons.add, size: 18, color: Colors.green),
                                          onPressed: () => ref.read(cartProvider.notifier).incrementQuantity(dish.id),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFfc8019)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error loading dishes: $err', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
      bottomNavigationBar: (activeOrder != null || cartState.totalItemCount > 0)
          ? SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (activeOrder != null) const FloatingActiveOrderCard(),
                  if (cartState.totalItemCount > 0)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF60b246),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${cartState.totalItemCount} ITEM${cartState.totalItemCount > 1 ? 'S' : ''}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    Text(
                                      '${cartState.restaurantName ?? "Cart"} • ₹${cartState.totalAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Row(
                                  children: [
                                    Text('VIEW CART', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Icon(Icons.shopping_bag_outlined, color: Colors.white),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : null,
    );
  }
}
