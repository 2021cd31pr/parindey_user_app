import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/city_model.dart';
import '../models/restaurant_model.dart';
import '../models/dish_model.dart';
import '../providers/app_providers.dart';
import 'menu_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'category_dishes_screen.dart';
import '../widgets/floating_active_order_card.dart';
import '../widgets/dish_details_bottom_sheet.dart';
import '../services/location_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String searchQuery = '';
  List<RestaurantModel>? gpsNearbyRestaurants;
  bool isGpsLoading = false;

  final List<String> bannerImages = [
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1493770348161-369560ae357d?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
  ];

  Position? _userGpsPos;

  Map<String, String> _calculateRealDistanceAndDeliveryTime(RestaurantModel restaurant) {
    double userLat = 22.7196; // default Indore center lat
    double userLng = 75.8577; // default Indore center lng

    if (_userGpsPos != null) {
      userLat = _userGpsPos!.latitude;
      userLng = _userGpsPos!.longitude;
    }

    final double shopLat = restaurant.latitude ?? (22.7196 + ((restaurant.id.hashCode.abs() % 40) - 20) * 0.0015);
    final double shopLng = restaurant.longitude ?? (75.8577 + ((restaurant.id.hashCode.abs() % 40) - 20) * 0.0015);

    final meters = Geolocator.distanceBetween(userLat, userLng, shopLat, shopLng);
    double distanceKm = meters / 1000.0;
    if (distanceKm < 0.8) distanceKm = 1.2;

    // Driving time @ ~24 km/h (2.5 mins per km) + 10 mins kitchen food preparation
    final int drivingMinutes = (distanceKm * 2.5).ceil();
    final int totalMinutes = 10 + drivingMinutes;
    final int minTime = (totalMinutes / 5).floor() * 5;
    final int maxTime = minTime + 5;

    return {
      'distance': '${distanceKm.toStringAsFixed(1)} km',
      'time': '$minTime-$maxTime mins',
    };
  }

  Future<void> _detectLocationAndFetchNearby() async {
    setState(() => isGpsLoading = true);
    final position = await LocationService.getCurrentLocation(
      onError: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
    );

    if (position == null) {
      setState(() => isGpsLoading = false);
      return;
    }

    try {
      final api = ref.read(userApiServiceProvider);
      final nearby = await api.getNearbyRestaurants(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusInKm: 15.0,
      );

      setState(() {
        _userGpsPos = position;
        gpsNearbyRestaurants = nearby;
        isGpsLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${nearby.length} nearby restaurants via GPS'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => isGpsLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    }
  }

  void _showCitySelectionDialog(List<CityModel> cities, CityModel? selectedCity) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Your City', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.my_location, color: Color(0xFFfc8019)),
                title: const Text('Auto-Detect by GPS (Nearby)', style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold)),
                subtitle: const Text('Fetch restaurants within 15 km radius'),
                onTap: () {
                  Navigator.pop(context);
                  _detectLocationAndFetchNearby();
                },
              ),
              const Divider(),
              const Text('ACTIVE CITIES', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cities.length,
                  itemBuilder: (context, index) {
                    final city = cities[index];
                    final isSelected = selectedCity?.id == city.id;
                    return ListTile(
                      title: Text(city.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(city.state),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFfc8019)) : null,
                      onTap: () {
                        ref.read(selectedCityProvider.notifier).selectCity(city);
                        setState(() {
                          gpsNearbyRestaurants = null;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onAddToCart(DishModel dish, String restaurantId, String restaurantName) {
    final result = ref.read(cartProvider.notifier).addItem(dish, restaurantId, restaurantName);
    if (result == AddItemResult.restaurantConflict) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace cart items?'),
          content: Text('Your cart contains items from another restaurant. Do you want to discard them and add items from $restaurantName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                ref.read(cartProvider.notifier).addItem(dish, restaurantId, restaurantName, forceClear: true);
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
        SnackBar(content: Text('${dish.name} added to cart'), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesProvider);
    final selectedCity = ref.watch(selectedCityProvider);
    final restaurantsAsync = ref.watch(restaurantsProvider);
    final globalCategoriesAsync = ref.watch(globalCategoriesProvider);
    final cartState = ref.watch(cartProvider);
    final activeOrder = ref.watch(activeOrderProvider);
    final searchDishesAsync = searchQuery.isNotEmpty ? ref.watch(searchDishesProvider(searchQuery)) : null;

    // Auto-select initial city if none selected
    citiesAsync.whenData((cities) {
      if (selectedCity == null && cities.isNotEmpty) {
        Future.microtask(() {
          ref.read(selectedCityProvider.notifier).selectCity(cities.first);
        });
      }
    });

    final currentCityName = selectedCity?.name ?? 'Indore';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar / Location Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        citiesAsync.whenData((cities) {
                          _showCitySelectionDialog(cities, selectedCity);
                        });
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFfc8019)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    currentCityName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                                ],
                              ),
                              Text(
                                gpsNearbyRestaurants != null
                                    ? 'Using GPS (Nearby)'
                                    : '${selectedCity?.state ?? "Madhya Pradesh"} • Tap to change',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.deepOrange,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.trim();
                      });
                    },
                    decoration: InputDecoration(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Search for dishes, Paneer, Biryani or restaurants',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
                      border: InputBorder.none,
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () => setState(() => searchQuery = ''),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),

            // Banner Section
            if (searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bannerImages.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: NetworkImage(bannerImages[index]),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                          ),
                        ),
                        child: Stack(
                          children: const [
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('50% OFF', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text('UPTO ₹100 ON FIRST ORDER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

            // What's on your mind? (Global Categories Carousel)
            if (searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "What's on your mind?",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 16),
                      globalCategoriesAsync.when(
                        data: (categories) {
                          final List<String> defaultImages = [
                            'https://images.unsplash.com/photo-1589302168068-964664d93cb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80',
                            'https://images.unsplash.com/photo-1513104890138-7c749659a591?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80',
                            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80',
                            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80',
                          ];

                          if (categories.isEmpty) return const SizedBox.shrink();

                          return SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final fallbackImg = defaultImages[index % defaultImages.length];
                                final catImg = (cat.imageUrl != null && cat.imageUrl!.isNotEmpty)
                                    ? cat.imageUrl!
                                    : fallbackImg;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CategoryDishesScreen(
                                            categoryId: cat.id,
                                            categoryName: cat.name,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(36),
                                          child: SizedBox(
                                            width: 72,
                                            height: 72,
                                            child: Image.network(
                                              catImg,
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Image.network(
                                                  fallbackImg,
                                                  width: 72,
                                                  height: 72,
                                                  fit: BoxFit.cover,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          cat.name,
                                          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        loading: () => const SizedBox(
                          height: 110,
                          child: Center(child: CircularProgressIndicator(color: Color(0xFFfc8019))),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),

            // Divider
            if (searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Divider(thickness: 8, color: Colors.grey[100]),
              ),

            // Global Search Results View for Dishes
            if (searchQuery.isNotEmpty && searchDishesAsync != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Dishes matching "$searchQuery"',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              searchDishesAsync.when(
                data: (dishes) {
                  if (dishes.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('No dishes found matching your query')),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final dish = dishes[index];
                        final rId = dish.restaurantId ?? 'd4afb18f-307c-4af2-9aa3-6085bfd8e7ea';
                        final rName = dish.restaurantName ?? 'Restaurant';
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 1,
                          child: ListTile(
                            leading: Icon(
                              Icons.circle,
                              color: dish.isVeg ? Colors.green : Colors.red,
                              size: 16,
                            ),
                            title: Text(dish.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('₹${dish.price.toStringAsFixed(0)} • $rName'),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF60b246),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              onPressed: () => _onAddToCart(dish, rId, rName),
                              child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            onTap: () {
                              DishDetailsBottomSheet.show(
                                context,
                                dish,
                                restaurantId: rId,
                                restaurantName: rName,
                              );
                            },
                          ),
                        );
                      },
                      childCount: dishes.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                ),
                error: (err, stack) => SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.all(16), child: Text('Search error: $err')),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Matching Restaurants for "$searchQuery"',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            // Restaurants Section Header
            if (searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        gpsNearbyRestaurants != null
                            ? 'Nearby Restaurants (GPS)'
                            : 'Restaurants in $currentCityName',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      if (gpsNearbyRestaurants != null)
                        TextButton(
                          onPressed: () => setState(() => gpsNearbyRestaurants = null),
                          child: const Text('Show All', style: TextStyle(color: Color(0xFFfc8019))),
                        ),
                    ],
                  ),
                ),
              ),

            // Restaurant List Rendering
            if (gpsNearbyRestaurants != null)
              _buildRestaurantSliverList(gpsNearbyRestaurants!)
            else
              restaurantsAsync.when(
                data: (restaurants) {
                  final filtered = restaurants.where((r) {
                    if (searchQuery.isEmpty) return true;
                    return r.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                           r.address.toLowerCase().contains(searchQuery.toLowerCase());
                  }).toList();

                  if (filtered.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No restaurants found in $currentCityName', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return _buildRestaurantSliverList(filtered);
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: Color(0xFFfc8019)),
                  )),
                ),
                error: (e, st) => SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Error loading restaurants: $e', style: const TextStyle(color: Colors.red)),
                  )),
                ),
              ),

            // Bottom Spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
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

  Widget _buildRestaurantSliverList(List<RestaurantModel> restaurants) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final restaurant = restaurants[index];
          final dbImageUrl = restaurant.imageUrl;

          return InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MenuScreen(restaurantId: restaurant.id, restaurantName: restaurant.name),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Image from DB ONLY
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: (dbImageUrl != null && dbImageUrl.isNotEmpty)
                              ? Image.network(
                                  dbImageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.restaurant, size: 48, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text(restaurant.name, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.restaurant, size: 48, color: Colors.grey),
                                      const SizedBox(height: 8),
                                      Text(restaurant.name, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 12,
                        left: 16,
                        child: Text(
                          'FLAT 20% OFF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.green, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            restaurant.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final realStats = _calculateRealDistanceAndDeliveryTime(restaurant);
                      return Row(
                        children: [
                          const Icon(Icons.access_time_filled, size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            realStats['time']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                          Text(
                            realStats['distance']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      );
                    },
                  ),
                  if (restaurant.cuisine != null && restaurant.cuisine!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisine!,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    restaurant.address,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (restaurant.description != null && restaurant.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant.description!,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
        childCount: restaurants.length,
      ),
    );
  }
}
