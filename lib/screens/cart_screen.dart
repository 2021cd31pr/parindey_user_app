import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/order_model.dart';
import '../models/restaurant_model.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/user_api_service.dart';
import 'home_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Aarav Sharma');
  final TextEditingController _phoneController = TextEditingController();

  // Granular Address Controllers
  final TextEditingController _houseNoController = TextEditingController(text: 'Flat No 789');
  final TextEditingController _streetAreaController = TextEditingController(text: 'LIG Square, Ambedkar Nagar');
  final TextEditingController _landmarkController = TextEditingController(text: 'Hanuman Mandir');
  final TextEditingController _cityStateController = TextEditingController(text: 'Indore, Madhya Pradesh');
  final TextEditingController _pincodeController = TextEditingController(text: '452010');

  bool _isPlacingOrder = false;
  bool _isDetectingLocation = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadSavedUserData();
  }

  Future<void> _loadSavedUserData() async {
    final authState = ref.read(authProvider);
    if (authState.name != null && authState.name!.isNotEmpty) {
      _nameController.text = authState.name!;
    }
    if (authState.phone != null && authState.phone!.isNotEmpty) {
      _phoneController.text = authState.phone!;
    } else {
      _phoneController.text = '9876543210';
    }

    final hNo = await StorageService.getString('userHouseNo');
    final stArea = await StorageService.getString('userStreetArea');
    final lm = await StorageService.getString('userLandmark');
    final cState = await StorageService.getString('userCityState');
    final pin = await StorageService.getString('userPincode');

    final savedLat = await StorageService.getString('userLat');
    final savedLng = await StorageService.getString('userLng');
    if (savedLat != null && savedLng != null) {
      setState(() {
        _latitude = double.tryParse(savedLat);
        _longitude = double.tryParse(savedLng);
      });
    }

    if (hNo != null && hNo.isNotEmpty) _houseNoController.text = hNo;
    if (stArea != null && stArea.isNotEmpty) _streetAreaController.text = stArea;
    if (lm != null && lm.isNotEmpty) _landmarkController.text = lm;
    if (cState != null && cState.isNotEmpty) _cityStateController.text = cState;
    if (pin != null && pin.isNotEmpty) _pincodeController.text = pin;

    // Auto-fetch real GPS location & pre-fill address fields if not already loaded!
    if (_latitude == null || _streetAreaController.text.isEmpty || _streetAreaController.text == 'Vijay Nagar') {
      _autoDetectGpsLocation(silent: true);
    }
  }

  Future<void> _autoDetectGpsLocation({bool silent = false}) async {
    setState(() => _isDetectingLocation = true);
    final position = await LocationService.getCurrentLocation(
      onError: (msg) {
        if (mounted && !silent) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
    );

    if (position != null && mounted) {
      final addressDetails = await LocationService.reverseGeocode(position.latitude, position.longitude);

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        if (addressDetails.houseNo.isNotEmpty) _houseNoController.text = addressDetails.houseNo;
        if (addressDetails.streetArea.isNotEmpty) _streetAreaController.text = addressDetails.streetArea;
        if (addressDetails.landmark.isNotEmpty) _landmarkController.text = addressDetails.landmark;
        if (addressDetails.cityState.isNotEmpty) _cityStateController.text = addressDetails.cityState;
        if (addressDetails.pincode.isNotEmpty) _pincodeController.text = addressDetails.pincode;
      });

      final fullAddr = _getFormattedFullAddress();

      // Save granular address & coordinates to StorageService
      await StorageService.setString('userHouseNo', _houseNoController.text);
      await StorageService.setString('userStreetArea', _streetAreaController.text);
      await StorageService.setString('userLandmark', _landmarkController.text);
      await StorageService.setString('userCityState', _cityStateController.text);
      await StorageService.setString('userPincode', _pincodeController.text);
      await StorageService.setString('userAddress', fullAddr);
      await StorageService.setString('userLat', position.latitude.toString());
      await StorageService.setString('userLng', position.longitude.toString());

      setState(() => _isDetectingLocation = false);

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-detected real-time GPS location address!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() => _isDetectingLocation = false);
    }
  }

  String _getFormattedFullAddress() {
    final parts = <String>[];
    final h = _houseNoController.text.trim();
    final s = _streetAreaController.text.trim();
    final l = _landmarkController.text.trim();
    final c = _cityStateController.text.trim();
    final p = _pincodeController.text.trim();

    if (h.isNotEmpty) parts.add(h);
    if (s.isNotEmpty) parts.add(s);
    if (l.isNotEmpty) {
      final lower = l.toLowerCase();
      if (lower.startsWith('near') || lower.startsWith('landmark')) {
        parts.add(l);
      } else {
        parts.add('Near $l');
      }
    }
    if (c.isNotEmpty) parts.add(c);
    if (p.isNotEmpty) parts.add('- $p');
    return parts.isNotEmpty ? parts.join(', ') : 'Flat No 789, LIG Square, Ambedkar Nagar, Indore - 452010';
  }

  double _calculateDistanceInKm(RestaurantModel? rest) {
    if (_latitude == null || _longitude == null || rest == null) {
      return 2.5; // default fallback distance
    }
    final shopLat = rest.latitude ?? 22.7196; // default Indore lat
    final shopLng = rest.longitude ?? 75.8577; // default Indore lng

    final meters = Geolocator.distanceBetween(_latitude!, _longitude!, shopLat, shopLng);
    final km = meters / 1000.0;
    return km < 0.5 ? 0.5 : km;
  }

  double _calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 3.0) {
      return 40.0;
    } else {
      double extraKm = distanceKm - 3.0;
      return 40.0 + (extraKm * 5.0);
    }
  }

  void _showSwiggyOrderSuccessAnimation(OrderResponse order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Pulsing Green Check Circle Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF60b246).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, size: 64, color: Color(0xFF60b246)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ORDER PLACED!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFfc8019), fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sent to restaurant partner live.\nArriving in ~30 mins.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Color(0xFF60b246), strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 6),
                  const Text('Redirecting to Home...', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Automatically navigate back to HomeScreen after 2.2 seconds
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  Future<void> _placeOrder(double computedTotal) async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty || cartState.restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final fullAddress = _getFormattedFullAddress();

    if (name.isEmpty || phone.isEmpty || _streetAreaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out name, phone and street address')),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final orderRequest = OrderRequest(
        restaurantId: cartState.restaurantId!,
        customerName: name,
        customerPhone: phone,
        deliveryAddress: fullAddress,
        latitude: _latitude,
        longitude: _longitude,
        paymentMethod: 'ONLINE',
        totalAmount: computedTotal,
        items: cartState.items.values.toList(),
      );

      final api = ref.read(userApiServiceProvider);
      final createdOrder = await api.placeOrder(orderRequest);

      // Save granular address to StorageService
      await StorageService.setString('userHouseNo', _houseNoController.text.trim());
      await StorageService.setString('userStreetArea', _streetAreaController.text.trim());
      await StorageService.setString('userLandmark', _landmarkController.text.trim());
      await StorageService.setString('userCityState', _cityStateController.text.trim());
      await StorageService.setString('userPincode', _pincodeController.text.trim());
      await StorageService.setString('userAddress', fullAddress);

      // Set Active Order and Clear Cart
      ref.read(activeOrderProvider.notifier).setActiveOrder(createdOrder);
      ref.read(cartProvider.notifier).clearCart();

      setState(() => _isPlacingOrder = false);

      if (mounted) {
        _showSwiggyOrderSuccessAnimation(createdOrder);
      }
    } catch (e) {
      setState(() => _isPlacingOrder = false);
      if (mounted) {
        String msg = e is UserApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order failed: $msg'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final restaurantsAsync = ref.watch(restaurantsProvider);
    final restaurants = restaurantsAsync.value ?? [];

    final RestaurantModel? currentShop = cartState.restaurantId != null
        ? restaurants.firstWhere(
            (r) => r.id == cartState.restaurantId,
            orElse: () => RestaurantModel(
              id: cartState.restaurantId!,
              name: cartState.restaurantName ?? 'Restaurant',
              address: 'Indore',
              latitude: 22.7196,
              longitude: 75.8577,
            ),
          )
        : null;

    final distanceKm = _calculateDistanceInKm(currentShop);
    final computedDeliveryFee = _calculateDeliveryFee(distanceKm);
    final computedTaxes = cartState.itemTotal * 0.05;
    final grandTotal = cartState.itemTotal + computedDeliveryFee + computedTaxes;

    if (cartState.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Checkout', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Good food is always waiting for you', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFfc8019)),
                onPressed: () => Navigator.pop(context),
                child: const Text('BROWSE RESTAURANTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          cartState.restaurantName ?? 'Checkout',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Restaurant Name Banner
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: Color(0xFFfc8019), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ordering from', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                          cartState.restaurantName ?? 'Restaurant',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Delivery Address Header & Granular Fields
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on, color: Color(0xFFfc8019), size: 24),
                          SizedBox(width: 8),
                          Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      TextButton.icon(
                        icon: _isDetectingLocation
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfc8019)))
                            : const Icon(Icons.my_location, size: 16, color: Color(0xFFfc8019)),
                        label: const Text('AUTO-GPS', style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: _isDetectingLocation ? null : _autoDetectGpsLocation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Customer Name *',
                            prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFFfc8019)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone *',
                            prefixIcon: const Icon(Icons.phone_android, size: 20, color: Color(0xFFfc8019)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _houseNoController,
                    decoration: InputDecoration(
                      labelText: 'Flat / House / Building No. *',
                      hintText: 'e.g. Flat No 789',
                      prefixIcon: const Icon(Icons.home_outlined, size: 20, color: Color(0xFFfc8019)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _streetAreaController,
                    decoration: InputDecoration(
                      labelText: 'Street / Area / Colony *',
                      hintText: 'e.g. LIG Square, Ambedkar Nagar',
                      prefixIcon: const Icon(Icons.add_road, size: 20, color: Color(0xFFfc8019)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _landmarkController,
                          decoration: InputDecoration(
                            labelText: 'Landmark (Optional)',
                            hintText: 'e.g. Hanuman Mandir',
                            prefixIcon: const Icon(Icons.explore_outlined, size: 20, color: Color(0xFFfc8019)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'Pincode *',
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_drop_outlined, size: 20, color: Color(0xFFfc8019)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cityStateController,
                    decoration: InputDecoration(
                      labelText: 'City & State *',
                      prefixIcon: const Icon(Icons.location_city, size: 20, color: Color(0xFFfc8019)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),

            // Order Items
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        onPressed: () => ref.read(cartProvider.notifier).clearCart(),
                        child: const Text('Clear Cart', style: TextStyle(color: Colors.red)),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...cartState.items.values.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: item.isVeg ? Colors.green[700] : Colors.red[700],
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.dishName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('₹${item.unitPrice.toStringAsFixed(0)} each', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          // Qty counter
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.remove, size: 16, color: Colors.green),
                                  onPressed: () => ref.read(cartProvider.notifier).decrementQuantity(item.dishId),
                                ),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                IconButton(
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.add, size: 16, color: Colors.green),
                                  onPressed: () => ref.read(cartProvider.notifier).incrementQuantity(item.dishId),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text('₹${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            // Bill Details with Dynamic Distance & Delivery Fee Calculation
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bill Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Item Total', style: TextStyle(color: Colors.black87)),
                      Text('₹${cartState.itemTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Delivery Fee ', style: TextStyle(color: Colors.black87)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFfc8019), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      Text('₹${computedDeliveryFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    distanceKm <= 3.0
                        ? 'Base delivery fee (Within 3 km)'
                        : '₹40 base + ₹5/km for ${(distanceKm - 3.0).toStringAsFixed(1)} extra km',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Taxes & Charges (5%)', style: TextStyle(color: Colors.black87)),
                      Text('₹${computedTaxes.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('To Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₹${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('ONLINE PAYMENT', style: TextStyle(fontSize: 11, color: Color(0xFFfc8019), fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF60b246),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isPlacingOrder ? null : () => _placeOrder(grandTotal),
                child: _isPlacingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('PROCEED TO PAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
