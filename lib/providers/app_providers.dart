import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/auth_model.dart';
import '../models/city_model.dart';
import '../models/restaurant_model.dart';
import '../models/category_model.dart';
import '../models/dish_model.dart';
import '../models/combo_model.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../services/user_api_service.dart';
import '../services/storage_service.dart';

final userApiServiceProvider = Provider<UserApiService>((ref) => UserApiService());

// ---------------------------------------------------------------------------
// AUTH STATE
// ---------------------------------------------------------------------------

class AuthState {
  final bool isLoggedIn;
  final String? phone;
  final String? name;
  final String? email;
  final String? address;
  final String? userId;
  final String? token;

  AuthState({
    this.isLoggedIn = false,
    this.phone,
    this.name,
    this.email,
    this.address,
    this.userId,
    this.token,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final token = await StorageService.getString('accessToken');
    final userId = await StorageService.getString('userId');
    final phone = await StorageService.getString('userPhone');
    final name = await StorageService.getString('userName');
    final email = await StorageService.getString('userEmail');
    final address = await StorageService.getString('userAddress');

    if (token != null && token.isNotEmpty) {
      state = AuthState(
        isLoggedIn: true,
        token: token,
        userId: userId,
        phone: phone,
        name: name,
        email: email,
        address: address,
      );
    }
  }

  void setLoggedIn(AuthResponse auth, {String? name, String? email, String? address}) async {
    if (auth.accessToken.isNotEmpty) await StorageService.setString('accessToken', auth.accessToken);
    if (auth.userId.isNotEmpty) await StorageService.setString('userId', auth.userId);
    if (auth.phone.isNotEmpty) await StorageService.setString('userPhone', auth.phone);
    if (name != null && name.isNotEmpty) await StorageService.setString('userName', name);
    if (email != null && email.isNotEmpty) await StorageService.setString('userEmail', email);
    if (address != null && address.isNotEmpty) await StorageService.setString('userAddress', address);

    state = AuthState(
      isLoggedIn: true,
      token: auth.accessToken,
      userId: auth.userId,
      phone: auth.phone.isNotEmpty ? auth.phone : (state.phone ?? ''),
      name: name ?? state.name,
      email: email ?? state.email,
      address: address ?? state.address,
    );
  }

  Future<void> logout() async {
    await StorageService.remove('accessToken');
    await StorageService.remove('refreshToken');
    await StorageService.remove('userId');
    await StorageService.remove('userPhone');
    await StorageService.remove('userName');
    await StorageService.remove('userEmail');
    await StorageService.remove('userAddress');
    state = AuthState(isLoggedIn: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

// ---------------------------------------------------------------------------
// CITY & LOCATION STATE
// ---------------------------------------------------------------------------

final citiesProvider = FutureProvider<List<CityModel>>((ref) async {
  final api = ref.watch(userApiServiceProvider);
  return api.getCities();
});

class SelectedCityNotifier extends StateNotifier<CityModel?> {
  SelectedCityNotifier() : super(null);

  void selectCity(CityModel city) {
    state = city;
  }
}

final selectedCityProvider = StateNotifierProvider<SelectedCityNotifier, CityModel?>((ref) => SelectedCityNotifier());

// GPS Nearby Provider
final nearbyRestaurantsProvider = FutureProvider.family<List<RestaurantModel>, Position>((ref, pos) async {
  final api = ref.watch(userApiServiceProvider);
  return api.getNearbyRestaurants(latitude: pos.latitude, longitude: pos.longitude);
});

final globalCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final api = ref.watch(userApiServiceProvider);
  return api.getAllCategories();
});

final dishesByCategoryProvider = FutureProvider.family<List<DishModel>, String>((ref, categoryId) async {
  final api = ref.watch(userApiServiceProvider);
  final selectedCity = ref.watch(selectedCityProvider);
  return api.getDishesByCategory(categoryId, cityId: selectedCity?.id);
});

// ---------------------------------------------------------------------------
// RESTAURANTS & SEARCH PROVIDERS
// ---------------------------------------------------------------------------

final restaurantsProvider = FutureProvider<List<RestaurantModel>>((ref) async {
  final api = ref.watch(userApiServiceProvider);
  final selectedCity = ref.watch(selectedCityProvider);
  return api.getRestaurants(cityId: selectedCity?.id);
});

final restaurantByIdProvider = FutureProvider.family<RestaurantModel?, String>((ref, restaurantId) async {
  final api = ref.watch(userApiServiceProvider);
  return api.getRestaurantById(restaurantId);
});

final searchDishesProvider = FutureProvider.family<List<DishModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final api = ref.watch(userApiServiceProvider);
  final selectedCity = ref.watch(selectedCityProvider);
  return api.searchDishes(query, cityId: selectedCity?.id);
});

// ---------------------------------------------------------------------------
// MENU PROVIDERS
// ---------------------------------------------------------------------------

final categoriesProvider = FutureProvider.family<List<CategoryModel>, String>((ref, restaurantId) async {
  final api = ref.watch(userApiServiceProvider);
  return api.getCategories(restaurantId);
});

final dishesProvider = FutureProvider.family<List<DishModel>, String>((ref, restaurantId) async {
  final api = ref.watch(userApiServiceProvider);
  return api.getDishes(restaurantId);
});

final combosProvider = FutureProvider.family<List<ComboModel>, String>((ref, restaurantId) async {
  final api = ref.watch(userApiServiceProvider);
  return api.getCombos(restaurantId);
});

// ---------------------------------------------------------------------------
// CART STATE MANAGEMENT
// ---------------------------------------------------------------------------

class CartState {
  final Map<String, CartItemModel> items; // dishId -> CartItemModel
  final String? restaurantId;
  final String? restaurantName;

  CartState({
    this.items = const {},
    this.restaurantId,
    this.restaurantName,
  });

  int get totalItemCount => items.values.fold(0, (sum, item) => sum + item.quantity);

  double get itemTotal => items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee => items.isEmpty ? 0.0 : 40.0;

  double get taxes => itemTotal * 0.05;

  double get totalAmount => itemTotal + deliveryFee + taxes;

  CartState copyWith({
    Map<String, CartItemModel>? items,
    String? restaurantId,
    String? restaurantName,
  }) {
    return CartState(
      items: items ?? this.items,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
    );
  }
}

enum AddItemResult {
  added,
  restaurantConflict,
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState()) {
    _loadCartFromStorage();
  }

  void _loadCartFromStorage() async {
    try {
      final cartStr = await StorageService.getString('local_cart_data');
      if (cartStr != null && cartStr.isNotEmpty) {
        final Map<String, dynamic> jsonMap = jsonDecode(cartStr);
        final rId = jsonMap['restaurantId']?.toString();
        final rName = jsonMap['restaurantName']?.toString();
        final Map<String, dynamic>? rawItems = jsonMap['items'] as Map<String, dynamic>?;

        if (rawItems != null && rawItems.isNotEmpty) {
          final Map<String, CartItemModel> items = {};
          rawItems.forEach((key, val) {
            items[key] = CartItemModel.fromJson(val as Map<String, dynamic>);
          });
          state = CartState(
            items: items,
            restaurantId: rId,
            restaurantName: rName,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Cart load error: $e');
    }
  }

  void _saveCartToStorage() async {
    try {
      if (state.items.isEmpty) {
        await StorageService.remove('local_cart_data');
      } else {
        final jsonMap = {
          'restaurantId': state.restaurantId,
          'restaurantName': state.restaurantName,
          'items': state.items.map((k, v) => MapEntry(k, v.toJson())),
        };
        await StorageService.setString('local_cart_data', jsonEncode(jsonMap));
      }
    } catch (e) {
      if (kDebugMode) print('Cart save error: $e');
    }
  }

  /// Returns AddItemResult.restaurantConflict if user tries to add item from another restaurant.
  AddItemResult addItem(DishModel dish, String restaurantId, String restaurantName, {bool forceClear = false}) {
    if (state.restaurantId != null &&
        state.restaurantId != restaurantId &&
        state.items.isNotEmpty &&
        !forceClear) {
      return AddItemResult.restaurantConflict;
    }

    final newItems = (state.restaurantId == restaurantId)
        ? Map<String, CartItemModel>.from(state.items)
        : <String, CartItemModel>{};

    if (newItems.containsKey(dish.id)) {
      final existing = newItems[dish.id]!;
      newItems[dish.id] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      newItems[dish.id] = CartItemModel(
        dishId: dish.id,
        dishName: dish.name,
        quantity: 1,
        unitPrice: dish.price,
        isVeg: dish.isVeg,
        imageUrl: dish.imageUrl,
        restaurantId: restaurantId,
      );
    }

    state = CartState(
      items: newItems,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
    _saveCartToStorage();

    return AddItemResult.added;
  }

  void incrementQuantity(String dishId) {
    if (!state.items.containsKey(dishId)) return;
    final newItems = Map<String, CartItemModel>.from(state.items);
    final existing = newItems[dishId]!;
    newItems[dishId] = existing.copyWith(quantity: existing.quantity + 1);
    state = state.copyWith(items: newItems);
    _saveCartToStorage();
  }

  void decrementQuantity(String dishId) {
    if (!state.items.containsKey(dishId)) return;
    final newItems = Map<String, CartItemModel>.from(state.items);
    final existing = newItems[dishId]!;
    if (existing.quantity > 1) {
      newItems[dishId] = existing.copyWith(quantity: existing.quantity - 1);
    } else {
      newItems.remove(dishId);
    }

    if (newItems.isEmpty) {
      state = CartState();
    } else {
      state = state.copyWith(items: newItems);
    }
    _saveCartToStorage();
  }

  void clearCart() {
    state = CartState();
    _saveCartToStorage();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

// ---------------------------------------------------------------------------
// ACTIVE ORDER PROVIDER
// ---------------------------------------------------------------------------

class ActiveOrderNotifier extends StateNotifier<OrderResponse?> {
  ActiveOrderNotifier() : super(null) {
    _loadActiveOrderFromStorage();
  }

  void _loadActiveOrderFromStorage() async {
    try {
      final jsonStr = await StorageService.getString('active_order_data');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        state = OrderResponse.fromJson(decoded as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  void setActiveOrder(OrderResponse order) async {
    state = order;
    try {
      final jsonMap = {
        'id': order.id,
        'restaurantId': order.restaurantId,
        'status': order.status,
        'totalAmount': order.totalAmount,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'deliveryAddress': order.deliveryAddress,
        'createdAt': order.createdAt,
      };
      await StorageService.setString('active_order_data', jsonEncode(jsonMap));
    } catch (_) {}
  }

  void clearActiveOrder() async {
    state = null;
    await StorageService.remove('active_order_data');
  }
}

final activeOrderProvider = StateNotifierProvider<ActiveOrderNotifier, OrderResponse?>((ref) => ActiveOrderNotifier());

final customerOrdersProvider = FutureProvider<List<OrderResponse>>((ref) async {
  final api = ref.watch(userApiServiceProvider);
  return api.getCustomerOrders();
});

