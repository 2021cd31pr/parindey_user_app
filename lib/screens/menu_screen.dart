import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/dish_model.dart';
import '../models/restaurant_model.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import '../widgets/floating_active_order_card.dart';
import '../widgets/dish_details_bottom_sheet.dart';
import '../widgets/shimmer_loading.dart';
import 'cart_screen.dart';

class MenuScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const MenuScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String selectedCategory = 'All';
  double? _userLat;
  double? _userLng;
  final ScrollController _scrollController = ScrollController();
  int _visibleDishCount = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserCoords();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      setState(() {
        _visibleDishCount += 10;
      });
    }
  }

  Future<void> _loadUserCoords() async {
    final latStr = await StorageService.getString('userLat');
    final lngStr = await StorageService.getString('userLng');
    if (latStr != null && lngStr != null) {
      if (mounted) {
        setState(() {
          _userLat = double.tryParse(latStr);
          _userLng = double.tryParse(lngStr);
        });
      }
    }
  }

  void _onAddToCart(DishModel dish) {
    final result = ref.read(cartProvider.notifier).addItem(
          dish,
          widget.restaurantId,
          widget.restaurantName,
        );

    if (result == AddItemResult.restaurantConflict) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace cart items?'),
          content: Text('Your cart contains items from another restaurant. Do you want to discard them and add items from ${widget.restaurantName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                ref.read(cartProvider.notifier).addItem(
                      dish,
                      widget.restaurantId,
                      widget.restaurantName,
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

  Widget _buildBlurredHeader(RestaurantModel? rest) {
    final rName = rest?.name ?? widget.restaurantName;
    final rRating = (rest?.rating != null && rest!.rating > 0)
        ? rest.rating.toStringAsFixed(1)
        : '4.3';
    final rCost = rest?.costForTwo != null
        ? '₹${rest!.costForTwo!.toStringAsFixed(0)} for two'
        : null;
    final rCuisine = rest?.cuisine;

    double uLat = _userLat ?? 22.7196;
    double uLng = _userLng ?? 75.8577;

    final shopLat = rest?.latitude ?? (22.7196 + ((widget.restaurantId.hashCode.abs() % 40) - 20) * 0.0015);
    final shopLng = rest?.longitude ?? (75.8577 + ((widget.restaurantId.hashCode.abs() % 40) - 20) * 0.0015);

    final meters = Geolocator.distanceBetween(uLat, uLng, shopLat, shopLng);
    double distanceKm = meters / 1000.0;
    if (distanceKm < 0.8) distanceKm = 1.2;

    final drivingMinutes = (distanceKm * 2.5).ceil();
    final totalMinutes = 10 + drivingMinutes;
    final minTime = (totalMinutes / 5).floor() * 5;
    final maxTime = minTime + 5;

    final realDelivery = '$minTime-$maxTime mins | ${distanceKm.toStringAsFixed(1)} km';

    final String? bgImage = (rest?.imageUrl != null && rest!.imageUrl!.isNotEmpty)
        ? rest.imageUrl
        : null;

    return ClipRect(
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            // Background Image or Solid Dark Gradient (No Random Images)
            Positioned.fill(
              child: bgImage != null
                  ? Image.network(
                      bgImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF282c3f)),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF282c3f), Color(0xFF1c1e2d)],
                        ),
                      ),
                    ),
            ),
            if (bgImage != null)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.40),
                          Colors.black.withValues(alpha: 0.80),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.70),
                      ],
                    ),
                  ),
                ),
              ),

            // Floating Circular Action Buttons (Back & Share)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sharing link for $rName...'),
                            backgroundColor: const Color(0xFFfc8019),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Restaurant Details Content Overlay
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 56,
                bottom: 20.0,
                left: 20.0,
                right: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF60b246),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              rRating,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (rCost != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '• $rCost',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (rCuisine != null && rCuisine.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      rCuisine,
                      style: const TextStyle(
                        color: Color(0xFFffab40),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        realDelivery,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (rest?.description != null && rest!.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      rest.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (rest?.licenseNumber != null && rest!.licenseNumber!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'FSSAI Lic. No: ${rest.licenseNumber}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantDetailsAsync = ref.watch(restaurantByIdProvider(widget.restaurantId));
    final categoriesAsync = ref.watch(categoriesProvider(widget.restaurantId));
    final dishesAsync = ref.watch(dishesProvider(widget.restaurantId));
    final combosAsync = ref.watch(combosProvider(widget.restaurantId));
    final cartState = ref.watch(cartProvider);
    final activeOrder = ref.watch(activeOrderProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Restaurant Header (Loads Header First via Shimmer while loading)
          SliverToBoxAdapter(
            child: restaurantDetailsAsync.when(
              data: (rest) => _buildBlurredHeader(rest),
              loading: () => const RestaurantHeaderShimmer(),
              error: (_, __) => _buildBlurredHeader(null),
            ),
          ),

          // Categories Horizontal Chips Bar
          categoriesAsync.when(
            data: (categories) {
              final allCategories = ['All', ...categories.map((c) => c.name)];

              return SliverToBoxAdapter(
                child: Container(
                  height: 50,
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allCategories.length,
                    itemBuilder: (context, index) {
                      final category = allCategories[index];
                      final isSelected = selectedCategory == category;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(category),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: Colors.grey[100],
                          selectedColor: const Color(0xFFfc8019),
                          onSelected: (selected) {
                            setState(() {
                              selectedCategory = category;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Combos Carousel Section
          combosAsync.when(
            data: (combos) {
              if (combos.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Best Combo Offers 🔥',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: combos.length,
                        itemBuilder: (context, index) {
                          final combo = combos[index];
                          return Card(
                            margin: const EdgeInsets.only(right: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Colors.orange[50],
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(combo.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(combo.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('₹${combo.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFfc8019))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFfc8019),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        ),
                                        onPressed: () {
                                          final dummyDish = DishModel(
                                            id: combo.id,
                                            name: combo.name,
                                            price: combo.price,
                                            description: combo.description,
                                            imageUrl: combo.imageUrl,
                                          );
                                          _onAddToCart(dummyDish);
                                        },
                                        child: const Text('ADD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Dishes Grouped Category-Wise (Loads with DishCardShimmer placeholders and scroll pagination)
          dishesAsync.when(
            data: (dishes) {
              if (dishes.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No dishes available for this restaurant'),
                    ),
                  ),
                );
              }

              // Group dishes by category
              final categoryGroups = <String, List<DishModel>>{};
              for (final dish in dishes) {
                String cat = dish.categoryName ?? 'Recommended';
                if (cat.isEmpty || cat.toLowerCase() == 'uncategorized') {
                  final nameLower = dish.name.toLowerCase();
                  if (nameLower.contains('paneer') || nameLower.contains('chicken') || nameLower.contains('biryani') || nameLower.contains('curry')) cat = 'Main Course';
                  else if (nameLower.contains('naan') || nameLower.contains('roti') || nameLower.contains('rice') || nameLower.contains('dal')) cat = 'Main Course';
                  else if (nameLower.contains('samosa') || nameLower.contains('roll') || nameLower.contains('tikka')) cat = 'Starters & Snacks';
                }

                categoryGroups.putIfAbsent(cat, () => []).add(dish);
              }

              // Filter groups based on selected category chip
              final filteredGroups = <String, List<DishModel>>{};
              categoryGroups.forEach((catName, dishList) {
                if (selectedCategory == 'All' ||
                    catName.toLowerCase().contains(selectedCategory.toLowerCase()) ||
                    selectedCategory.toLowerCase().contains(catName.toLowerCase())) {
                  filteredGroups[catName] = dishList;
                }
              });

              if (filteredGroups.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('No dishes available in $selectedCategory'),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final catName = filteredGroups.keys.elementAt(index);
                    final groupDishes = filteredGroups[catName]!;
                    final paginatedDishes = groupDishes.take(_visibleDishCount).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Section Header Banner
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$catName (${groupDishes.length})',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),

                        // Dishes under this category (Paginated)
                        ...paginatedDishes.map((dish) {
                          final cartItem = cartState.items[dish.id];
                          final itemQty = cartItem?.quantity ?? 0;
                          final dbImageUrl = dish.imageUrl;

                          return InkWell(
                            onTap: () {
                              DishDetailsBottomSheet.show(
                                context,
                                dish,
                                restaurantId: widget.restaurantId,
                                restaurantName: widget.restaurantName,
                              );
                            },
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              margin: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Details
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
                                                  style: TextStyle(
                                                    color: Colors.pink[800],
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          dish.name,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${dish.price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            if (dish.originalPrice != null && dish.originalPrice! > dish.price) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                '₹${dish.originalPrice!.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey,
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (dish.description != null && dish.description!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            dish.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Image & ADD Button
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 110,
                                          height: 110,
                                          color: Colors.grey[200],
                                          child: (dbImageUrl != null && dbImageUrl.isNotEmpty)
                                              ? Image.network(
                                                  dbImageUrl,
                                                  width: 110,
                                                  height: 110,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[300],
                                                      child: const Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.fastfood, size: 32, color: Colors.grey),
                                                          SizedBox(height: 4),
                                                          Text('No Image', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                                                      Icon(Icons.fastfood, size: 32, color: Colors.grey),
                                                      SizedBox(height: 4),
                                                      Text('No Image', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: -12,
                                        left: 5,
                                        right: 5,
                                        child: itemQty == 0
                                            ? ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: const Color(0xFF60b246),
                                                  elevation: 2,
                                                  side: BorderSide(color: Colors.grey[300]!),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                ),
                                                onPressed: () => _onAddToCart(dish),
                                                child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              )
                                            : Container(
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey[300]!),
                                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: [
                                                    InkWell(
                                                      onTap: () => ref.read(cartProvider.notifier).decrementQuantity(dish.id),
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                        child: Icon(Icons.remove, size: 16, color: Colors.green),
                                                      ),
                                                    ),
                                                    Text(
                                                      '$itemQty',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                                                    ),
                                                    InkWell(
                                                      onTap: () => ref.read(cartProvider.notifier).incrementQuantity(dish.id),
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                        child: Icon(Icons.add, size: 16, color: Colors.green),
                                                      ),
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
                          );
                        }).toList(),

                        // Category Section Divider
                        Divider(thickness: 8, color: Colors.grey[100]),
                      ],
                    );
                  },
                  childCount: filteredGroups.length,
                ),
              );
            },
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const DishCardShimmer(),
                childCount: 4,
              ),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text('Error loading menu: $err', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomSheet: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (activeOrder != null) const FloatingActiveOrderCard(),
          if (cartState.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF60b246),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, -2))
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cartState.totalItemCount} ${cartState.totalItemCount == 1 ? "ITEM" : "ITEMS"}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          '₹${cartState.itemTotal.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF60b246),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('VIEW CART', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        );
                      },
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
