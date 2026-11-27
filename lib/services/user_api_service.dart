import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_model.dart';
import '../models/city_model.dart';
import '../models/restaurant_model.dart';
import '../models/category_model.dart';
import '../models/dish_model.dart';
import '../models/combo_model.dart';
import '../models/order_model.dart';
import '../models/saved_address_model.dart';

import 'storage_service.dart';

class UserApiException implements Exception {
  final String message;
  final int? statusCode;

  UserApiException(this.message, {this.statusCode});

  @override
  String toString() => 'UserApiException: $message (Status: $statusCode)';
}

class UserApiService {
  static const String baseUrl = 'https://parindey-production.up.railway.app';
  static const Duration timeoutDuration = Duration(seconds: 45);

  static final Map<String, List<CategoryModel>> _restaurantCategoriesCache = {};
  static final Map<String, Map<String, dynamic>> _restaurantDishesCache = {};

  Future<Map<String, String>> _getHeaders({bool requireAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await StorageService.getString('accessToken');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Helper method for standard http error handling
  dynamic _handleResponse(http.Response response) {
    if (kDebugMode) {
      print('API Response [${response.statusCode}]: ${response.body}');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Server error (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson.containsKey('message')) {
          errorMessage = errJson['message'];
        } else if (errJson is Map && errJson.containsKey('error')) {
          errorMessage = errJson['error'];
        }
      } catch (_) {}
      throw UserApiException(errorMessage, statusCode: response.statusCode);
    }
  }

  // 1. Customer OTP Authentication

  /// Send OTP to Mobile
  /// POST /api/v1/auth/send-otp
  Future<bool> sendOtp(String phone) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/send-otp');
      final headers = await _getHeaders();
      final body = jsonEncode({'phone': phone});

      final response = await http.post(url, headers: headers, body: body).timeout(timeoutDuration);
      _handleResponse(response);
      return true;
    } on TimeoutException {
      throw UserApiException('Request timed out. Please check your internet connection.');
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to send OTP: $e');
    }
  }

  /// Check if user exists by phone
  /// GET /api/v1/auth/check-user?phone={phone}
  Future<bool> checkUserExists(String phone) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/check-user?phone=$phone');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data['exists'] == true || data['registered'] == true;
        } else if (data is bool) {
          return data;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Verify OTP & Receive JWT
  /// POST /api/v1/auth/verify-otp
  Future<AuthResponse> verifyOtp(String phone, String otp, {String requestedRole = 'ROLE_CUSTOMER'}) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/verify-otp');
      final headers = await _getHeaders();
      final body = jsonEncode({
        'phone': phone,
        'otp': otp,
        'requestedRole': requestedRole,
      });

      final response = await http.post(url, headers: headers, body: body).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      final authResponse = AuthResponse.fromJson(responseData as Map<String, dynamic>, fallbackPhone: phone);

      // Save token & userId to StorageService (with memory fallback)
      await StorageService.setString('accessToken', authResponse.accessToken);
      await StorageService.setString('refreshToken', authResponse.refreshToken);
      await StorageService.setString('userPhone', authResponse.phone.isNotEmpty ? authResponse.phone : phone);
      if (authResponse.userId.isNotEmpty) {
        await StorageService.setString('userId', authResponse.userId);
      }

      return authResponse;
    } on TimeoutException {
      throw UserApiException('Verification timed out. Please try again.');
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to verify OTP: $e');
    }
  }

  /// Complete/Update Profile: PATCH /api/v1/auth/profile
  Future<Map<String, dynamic>> updateProfile(String fullName) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/profile');
      final headers = await _getHeaders(requireAuth: true);
      final body = jsonEncode({'fullName': fullName.trim()});

      final response = await http.patch(url, headers: headers, body: body).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      await StorageService.setString('userName', fullName.trim());

      if (responseData is Map<String, dynamic>) {
        return responseData;
      }
      return {'fullName': fullName.trim()};
    } on TimeoutException {
      throw UserApiException('Profile update timed out. Please try again.');
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to update profile: $e');
    }
  }

  /// Get Current User Profile: GET /api/v1/auth/profile
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/profile');
      final headers = await _getHeaders(requireAuth: true);

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is Map<String, dynamic>) {
        final name = responseData['fullName']?.toString() ?? responseData['name']?.toString();
        if (name != null && name.trim().isNotEmpty) {
          await StorageService.setString('userName', name.trim());
        }
        return responseData;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getProfile error: $e');
      return null;
    }
  }

  // 2. Auto-fetch Cities & Location Selection

  /// Fetch All Active Cities
  /// GET /api/cities
  Future<List<CityModel>> getCities() async {
    try {
      final url = Uri.parse('$baseUrl/api/cities');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List) {
        return responseData.map((e) => CityModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on TimeoutException {
      return [
        CityModel(id: 'aec9b667-4f70-4e11-8551-231d6e1879d8', name: 'Indore', state: 'Madhya Pradesh', active: true),
        CityModel(id: 'c15e311d-4ef4-4622-bd41-e826a61a5e6d', name: 'Udaipur', state: 'Rajasthan', active: true),
      ];
    } catch (e) {
      if (kDebugMode) print('getCities error: $e');
      // Fallback fallback defaults so UI doesn't break
      return [
        CityModel(id: 'aec9b667-4f70-4e11-8551-231d6e1879d8', name: 'Indore', state: 'Madhya Pradesh', active: true),
        CityModel(id: 'c15e311d-4ef4-4622-bd41-e826a61a5e6d', name: 'Udaipur', state: 'Rajasthan', active: true),
      ];
    }
  }

  /// Auto-Detect by GPS (Nearby Restaurants)
  /// GET /api/v1/customer/restaurants/nearby?latitude={lat}&longitude={lng}&radiusInKm={radius}
  Future<List<RestaurantModel>> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    double radiusInKm = 15.0,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/customer/restaurants/nearby?latitude=$latitude&longitude=$longitude&radiusInKm=$radiusInKm');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List) {
        return responseData.map((e) => RestaurantModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getNearbyRestaurants error: $e');
      return [];
    }
  }

  // 3. Browse Restaurants & Global Food Search

  /// Get Available Restaurants in Selected City
  /// GET /api/restaurants?cityId={cityId}
  Future<List<RestaurantModel>> getRestaurants({String? cityId}) async {
    try {
      String path = '$baseUrl/api/restaurants';
      if (cityId != null && cityId.isNotEmpty) {
        path += '?cityId=$cityId';
      }
      final url = Uri.parse(path);
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List) {
        return responseData.map((e) => RestaurantModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getRestaurants error: $e');
      // Try fallback endpoint /api/restaurants/city/{cityId}
      if (cityId != null && cityId.isNotEmpty) {
        try {
          final url = Uri.parse('$baseUrl/api/restaurants/city/$cityId');
          final response = await http.get(url, headers: await _getHeaders()).timeout(timeoutDuration);
          final responseData = _handleResponse(response);
          if (responseData is List) {
            return responseData.map((e) => RestaurantModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
      }
      // Demo fallback if backend is warming up
      return [
        RestaurantModel(id: 'd4afb18f-307c-4af2-9aa3-6085bfd8e7ea', name: 'Empire Restaurant', address: 'Vijay Nagar, Indore', rating: 4.5),
        RestaurantModel(id: 'c25e311d-4ef4-4622-bd41-e826a61a5e6f', name: 'Royal Food Court', address: 'Palasia, Indore', rating: 4.2),
      ];
    }
  }

  /// Search Dishes Across City
  /// GET /api/v1/customer/dishes/search?query={query}&cityId={cityId}
  Future<List<DishModel>> searchDishes(String query, {String? cityId}) async {
    try {
      String queryParams = 'query=${Uri.encodeComponent(query)}';
      if (cityId != null && cityId.isNotEmpty) {
        queryParams += '&cityId=$cityId';
      }
      final url = Uri.parse('$baseUrl/api/v1/customer/dishes/search?$queryParams');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List) {
        return responseData.map((e) => DishModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('searchDishes error: $e');
      return [];
    }
  }

  /// Get Single Restaurant Details from DB
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    final List<String> endpoints = [
      '$baseUrl/api/restaurants/$restaurantId',
      '$baseUrl/api/v1/partner/restaurants/$restaurantId',
      '$baseUrl/api/v1/customer/restaurants/$restaurantId',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(endpoint);
        final response = await http.get(url, headers: await _getHeaders()).timeout(timeoutDuration);
        final responseData = _handleResponse(response);
        if (responseData is Map<String, dynamic>) {
          return RestaurantModel.fromJson(responseData);
        }
      } catch (e) {
        if (kDebugMode) print('getRestaurantById error for $endpoint: $e');
      }
    }
    return null;
  }

  /// GET /api/v1/categories (Fetch All Public Categories for Home Carousel)
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/categories');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List && responseData.isNotEmpty) {
        return responseData.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('getAllCategories error: $e');
    }

    // Default Fallback Categories for Home Screen Carousel
    return [
      CategoryModel(id: 'cat-biryani', name: 'Biryani', imageUrl: 'https://images.unsplash.com/photo-1589302168068-964664d93cb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80'),
      CategoryModel(id: 'cat-pizza', name: 'Pizzas', imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80'),
      CategoryModel(id: 'cat-burger', name: 'Burgers', imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80'),
      CategoryModel(id: 'cat-chinese', name: 'Chinese', imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80'),
      CategoryModel(id: 'cat-thali', name: 'North Indian', imageUrl: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80'),
      CategoryModel(id: 'cat-dessert', name: 'Desserts', imageUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?ixlib=rb-4.0.3&auto=format&fit=crop&w=200&q=80'),
    ];
  }

  /// GET /api/v1/customer/dishes/by-category/{categoryId}?cityId={selectedCityId}
  Future<List<DishModel>> getDishesByCategory(String categoryId, {String? cityId}) async {
    try {
      String path = '$baseUrl/api/v1/customer/dishes/by-category/$categoryId';
      if (cityId != null && cityId.isNotEmpty) {
        path += '?cityId=$cityId';
      }
      final url = Uri.parse(path);
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List) {
        return responseData.map((e) => DishModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getDishesByCategory error: $e');
      return [];
    }
  }

  /// Customer Available Categories: GET /api/v1/customer/restaurants/{restaurantId}/categories
  Future<List<CategoryModel>> getCustomerRestaurantCategories(String restaurantId) async {
    if (_restaurantCategoriesCache.containsKey(restaurantId) && _restaurantCategoriesCache[restaurantId]!.isNotEmpty) {
      return _restaurantCategoriesCache[restaurantId]!;
    }

    final List<String> endpoints = [
      '$baseUrl/api/v1/customer/restaurants/$restaurantId/categories',
      '$baseUrl/api/v1/partner/restaurants/$restaurantId/categories',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(endpoint);
        final headers = await _getHeaders();
        final response = await http.get(url, headers: headers).timeout(timeoutDuration);
        final responseData = _handleResponse(response);

        if (responseData is List && responseData.isNotEmpty) {
          final list = responseData.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
          _restaurantCategoriesCache[restaurantId] = list;
          return list;
        }
      } catch (e) {
        if (kDebugMode) print('getCustomerRestaurantCategories error: $e');
      }
    }
    return _restaurantCategoriesCache[restaurantId] ?? [];
  }

  /// Customer Paginated Dishes: GET /api/v1/customer/restaurants/{restaurantId}/dishes
  Future<Map<String, dynamic>> getCustomerRestaurantDishesPaginated(
    String restaurantId, {
    int page = 0,
    int size = 15,
    String? categoryId,
  }) async {
    final cacheKey = '$restaurantId-${categoryId ?? "ALL"}-$page-$size';
    if (_restaurantDishesCache.containsKey(cacheKey)) {
      return _restaurantDishesCache[cacheKey]!;
    }

    try {
      String query = 'page=$page&size=$size';
      if (categoryId != null && categoryId.isNotEmpty && categoryId.toLowerCase() != 'all') {
        query += '&categoryId=$categoryId';
      }

      final List<String> endpoints = [
        '$baseUrl/api/v1/customer/restaurants/$restaurantId/dishes?$query',
        '$baseUrl/api/v1/partner/restaurants/$restaurantId/dishes',
      ];

      for (final endpoint in endpoints) {
        try {
          final url = Uri.parse(endpoint);
          final headers = await _getHeaders();
          final response = await http.get(url, headers: headers).timeout(timeoutDuration);
          final responseData = _handleResponse(response);

          int totalPages = 1;
          if (response.headers['x-total-pages'] != null) {
            totalPages = int.tryParse(response.headers['x-total-pages']!) ?? 1;
          }

          if (responseData is List) {
            final dishes = responseData.map((e) => DishModel.fromJson(e as Map<String, dynamic>)).toList();
            final res = {
              'dishes': dishes,
              'totalPages': totalPages,
              'currentPage': page,
            };
            if (dishes.isNotEmpty) {
              _restaurantDishesCache[cacheKey] = res;
            }
            return res;
          } else if (responseData is Map<String, dynamic> && responseData['content'] is List) {
            final content = responseData['content'] as List;
            final dishes = content.map((e) => DishModel.fromJson(e as Map<String, dynamic>)).toList();
            final totalP = (responseData['totalPages'] as num?)?.toInt() ?? 1;
            final res = {
              'dishes': dishes,
              'totalPages': totalP,
              'currentPage': page,
            };
            if (dishes.isNotEmpty) {
              _restaurantDishesCache[cacheKey] = res;
            }
            return res;
          }
        } catch (e) {
          if (kDebugMode) print('getCustomerRestaurantDishesPaginated error for $endpoint: $e');
        }
      }

      return {
        'dishes': <DishModel>[],
        'totalPages': 1,
        'currentPage': page,
      };
    } catch (e) {
      if (kDebugMode) print('getCustomerRestaurantDishesPaginated error: $e');
      return {
        'dishes': <DishModel>[],
        'totalPages': 1,
        'currentPage': page,
      };
    }
  }

  // 4. View Restaurant Menu (Categories, Dishes, Combos)

  /// Categories: GET /api/v1/partner/restaurants/{restaurantId}/categories
  Future<List<CategoryModel>> getCategories(String restaurantId) async {
    final List<String> endpoints = [
      '$baseUrl/api/v1/partner/restaurants/$restaurantId/categories',
      '$baseUrl/api/v1/customer/restaurants/$restaurantId/categories',
      '$baseUrl/api/restaurants/$restaurantId/categories',
      '$baseUrl/api/v1/categories?restaurantId=$restaurantId',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(endpoint);
        final headers = await _getHeaders();
        final response = await http.get(url, headers: headers).timeout(timeoutDuration);
        final responseData = _handleResponse(response);

        if (responseData is List && responseData.isNotEmpty) {
          final list = responseData.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
          return list;
        }
      } catch (e) {
        if (kDebugMode) print('getCategories error for $endpoint: $e');
      }
    }

    // Default categories fallback if database has no registered categories yet
    return [
      CategoryModel(id: 'cat-main', name: 'Main Course'),
      CategoryModel(id: 'cat-breads', name: 'Breads & Rice'),
      CategoryModel(id: 'cat-starters', name: 'Starters & Snacks'),
      CategoryModel(id: 'cat-desserts', name: 'Desserts & Drinks'),
    ];
  }

  /// Dishes: GET /api/v1/partner/restaurants/{restaurantId}/dishes
  Future<List<DishModel>> getDishes(String restaurantId) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/partner/restaurants/$restaurantId/dishes');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List) {
        return responseData.map((e) => DishModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getDishes error: $e');
      // Return demo dishes fallback if server unavailable
      return [
        DishModel(id: 'dish-1', name: 'Paneer Butter Masala', price: 240.0, isVeg: true, description: 'Rich creamy gravy with cottage cheese cubes', restaurantId: restaurantId, discountBadge: '20% OFF'),
        DishModel(id: 'dish-2', name: 'Butter Garlic Naan', price: 55.0, isVeg: true, description: 'Freshly baked tandoori naan brushed with garlic butter', restaurantId: restaurantId),
        DishModel(id: 'dish-3', name: 'Chicken Dum Biryani', price: 320.0, isVeg: false, description: 'Aromatic basmati rice cooked with tender chicken pieces', restaurantId: restaurantId, discountBadge: '15% OFF'),
        DishModel(id: 'dish-4', name: 'Dal Makhani', price: 190.0, isVeg: true, description: 'Slow cooked black lentils with cream and butter', restaurantId: restaurantId),
      ];
    }
  }

  /// Combos: GET /api/v1/partner/restaurants/{restaurantId}/combos
  Future<List<ComboModel>> getCombos(String restaurantId) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/partner/restaurants/$restaurantId/combos');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List) {
        return responseData.map((e) => ComboModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getCombos error: $e');
      return [];
    }
  }

  // 5. Cart & Order Placement

  static final List<OrderResponse> _localOrdersList = [];

  void _persistOrderLocally(OrderResponse order) async {
    if (!_localOrdersList.any((o) => o.id == order.id)) {
      _localOrdersList.insert(0, order);
    }
    try {
      final jsonList = _localOrdersList.map((o) => {
        'id': o.id,
        'restaurantId': o.restaurantId,
        'status': o.status,
        'totalAmount': o.totalAmount,
        'customerName': o.customerName,
        'customerPhone': o.customerPhone,
        'deliveryAddress': o.deliveryAddress,
        'createdAt': o.createdAt,
      }).toList();
      await StorageService.setString('cached_placed_orders', jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Place Order
  /// POST /api/v1/customer/orders
  Future<OrderResponse> placeOrder(OrderRequest request) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/customer/orders');
      final headers = await _getHeaders(requireAuth: true);
      final body = jsonEncode(request.toJson());

      if (kDebugMode) {
        print('Posting Order: $body');
      }

      final response = await http.post(url, headers: headers, body: body).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      final createdOrder = OrderResponse.fromJson(responseData as Map<String, dynamic>);
      _persistOrderLocally(createdOrder);
      return createdOrder;
    } on TimeoutException {
      throw UserApiException('Order placement timed out. Please check your connection.');
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to place order: $e');
    }
  }

  /// Get Customer Order History
  /// GET /api/v1/customer/orders
  Future<List<OrderResponse>> getCustomerOrders() async {
    final List<OrderResponse> resultList = [];

    // 1. Read locally cached placed orders
    try {
      final cachedJson = await StorageService.getString('cached_placed_orders');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List decoded = jsonDecode(cachedJson);
        for (final item in decoded) {
          final o = OrderResponse.fromJson(item as Map<String, dynamic>);
          if (o.id.isNotEmpty && !resultList.any((existing) => existing.id == o.id)) {
            resultList.add(o);
          }
        }
      }
    } catch (_) {}

    for (final o in _localOrdersList) {
      if (o.id.isNotEmpty && !resultList.any((existing) => existing.id == o.id)) {
        resultList.add(o);
      }
    }

    // 2. Fetch from backend candidate endpoints
    final phone = await StorageService.getString('userPhone') ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    final List<String> endpoints = [
      '$baseUrl/api/v1/customer/orders',
      if (cleanPhone.isNotEmpty) '$baseUrl/api/v1/customer/orders/phone/$cleanPhone',
      if (cleanPhone.isNotEmpty) '$baseUrl/api/v1/customer/orders?phone=$cleanPhone',
      '$baseUrl/api/v1/customer/orders/my-orders',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(endpoint);
        final headers = await _getHeaders(requireAuth: true);
        final response = await http.get(url, headers: headers).timeout(timeoutDuration);
        final responseData = _handleResponse(response);

        if (responseData is List) {
          for (final item in responseData) {
            final o = OrderResponse.fromJson(item as Map<String, dynamic>);
            if (o.id.isNotEmpty && !resultList.any((existing) => existing.id == o.id)) {
              resultList.add(o);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('getCustomerOrders error for $endpoint: $e');
      }
    }

    return resultList;
  }

  /// GET /api/v1/customer/orders/{orderId}
  Future<OrderResponse> getOrderById(String orderId) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/customer/orders/$orderId');
      final headers = await _getHeaders(requireAuth: true);

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      return OrderResponse.fromJson(responseData as Map<String, dynamic>);
    } on TimeoutException {
      throw UserApiException('Request timed out while fetching order details.');
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to fetch order: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 6. SAVED ADDRESSES MANAGEMENT
  // ---------------------------------------------------------------------------

  /// GET /api/v1/auth/addresses
  Future<List<SavedAddressModel>> getSavedAddresses() async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/addresses');
      final headers = await _getHeaders(requireAuth: true);

      final response = await http.get(url, headers: headers).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is List) {
        return responseData.map((e) => SavedAddressModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getSavedAddresses error: $e');
      return [];
    }
  }

  /// POST /api/v1/auth/addresses
  Future<SavedAddressModel> addSavedAddress(SavedAddressModel address) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/addresses');
      final headers = await _getHeaders(requireAuth: true);
      final body = jsonEncode(address.toJson());

      final response = await http.post(url, headers: headers, body: body).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is Map<String, dynamic>) {
         return SavedAddressModel.fromJson(responseData);
      }
      return address;
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to add address: $e');
    }
  }

  /// PUT /api/v1/auth/addresses/{addressId}
  Future<SavedAddressModel> updateSavedAddress(String addressId, SavedAddressModel address) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/addresses/$addressId');
      final headers = await _getHeaders(requireAuth: true);
      final body = jsonEncode(address.toJson());

      final response = await http.put(url, headers: headers, body: body).timeout(timeoutDuration);
      final responseData = _handleResponse(response);

      if (responseData is Map<String, dynamic>) {
         return SavedAddressModel.fromJson(responseData);
      }
      return address;
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to update address: $e');
    }
  }

  /// DELETE /api/v1/auth/addresses/{addressId}
  Future<void> deleteSavedAddress(String addressId) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/addresses/$addressId');
      final headers = await _getHeaders(requireAuth: true);

      final response = await http.delete(url, headers: headers).timeout(timeoutDuration);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      _handleResponse(response);
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to delete address: $e');
    }
  }

  /// PATCH /api/v1/auth/addresses/{addressId}/default
  Future<void> setDefaultAddress(String addressId) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/auth/addresses/$addressId/default');
      final headers = await _getHeaders(requireAuth: true);

      final response = await http.patch(url, headers: headers).timeout(timeoutDuration);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      _handleResponse(response);
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Failed to set default address: $e');
    }
  }
}
