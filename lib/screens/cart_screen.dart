import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/order_model.dart';
import '../models/restaurant_model.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/user_api_service.dart';
import '../widgets/swiggy_location_loading.dart';
import 'home_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Granular Address Controllers (Start empty — no fake hardcoded defaults)
  final TextEditingController _houseNoController = TextEditingController();
  final TextEditingController _streetAreaController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _cityStateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  bool _isPlacingOrder = false;
  bool _isDetectingLocation = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadSavedUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _houseNoController.dispose();
    _streetAreaController.dispose();
    _landmarkController.dispose();
    _cityStateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUserData() async {
    // 1. Load user auth profile info
    final authState = ref.read(authProvider);
    if (authState.name != null && authState.name!.isNotEmpty) {
      _nameController.text = authState.name!;
    } else {
      _nameController.text = 'User';
    }

    if (authState.phone != null && authState.phone!.isNotEmpty) {
      _phoneController.text = authState.phone!;
    } else {
      _phoneController.text = '9876543210';
    }

    // 2. Read saved address and coordinates from StorageService
    final hNo = await StorageService.getString('userHouseNo');
    final stArea = await StorageService.getString('userStreetArea');
    final lm = await StorageService.getString('userLandmark');
    final cState = await StorageService.getString('userCityState');
    final pin = await StorageService.getString('userPincode');
    final savedLat = await StorageService.getString('userLat');
    final savedLng = await StorageService.getString('userLng');

    if (savedLat != null && savedLng != null) {
      _latitude = double.tryParse(savedLat);
      _longitude = double.tryParse(savedLng);
    }

    // Clean out old fake dummy address if it was saved previously
    final isDummyAddress = stArea == 'LIG Square, Ambedkar Nagar' || stArea == 'Vijay Nagar' || stArea == 'Unnamed Road';

    if (!isDummyAddress && stArea != null && stArea.isNotEmpty) {
      if (hNo != null) _houseNoController.text = hNo;
      _streetAreaController.text = stArea;
      if (lm != null) _landmarkController.text = lm;
      if (cState != null) _cityStateController.text = cState;
      if (pin != null) _pincodeController.text = pin;
      if (mounted) setState(() {});
    }

    // 3. If no real address exists or coordinates are missing, detect GPS immediately!
    if (_latitude == null || _longitude == null || _streetAreaController.text.trim().isEmpty || isDummyAddress) {
      _autoDetectGpsLocation(silent: true);
    }
  }

  /// Ensures GPS permissions and services are active on the device
  Future<Position?> _ensureGpsPosition({bool silent = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location services are disabled. Please turn on GPS.'),
              action: SnackBarAction(
                label: 'SETTINGS',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission was denied.')),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permissions are permanently denied.'),
              action: SnackBarAction(
                label: 'APP SETTINGS',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return null;
      }

      // Fetch precise GPS position with timeout
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      // Fallback to last known position if active GPS timed out
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Reverse geocode using LocationService with an OpenStreetMap fallback
  Future<void> _autoDetectGpsLocation({bool silent = false}) async {
    if (_isDetectingLocation) return;
    setState(() => _isDetectingLocation = true);

    if (!silent && mounted) {
      SwiggyLocationPulseDialog.show(context, title: 'Locating your delivery address...');
    }

    try {
      Position? position;

      // 1. Try custom LocationService first
      try {
        position = await LocationService.getCurrentLocation(
          onError: (msg) {
            if (!silent && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          },
        );
      } catch (_) {}

      // 2. Direct Geolocator fallback if LocationService didn't return
      position ??= await _ensureGpsPosition(silent: silent);

      if (position == null) {
        if (!silent && mounted) {
          Navigator.pop(context); // Dismiss dialog if open
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not obtain GPS location. Please check device GPS.')),
          );
        }
        return;
      }

      _latitude = position.latitude;
      _longitude = position.longitude;

      String houseNo = '';
      String streetArea = '';
      String landmark = '';
      String cityState = '';
      String pincode = '';

      // 3. Attempt reverse geocoding via LocationService
      try {
        final addressDetails = await LocationService.reverseGeocode(position.latitude, position.longitude);
        if (addressDetails.houseNo.isNotEmpty) houseNo = addressDetails.houseNo;
        if (addressDetails.streetArea.isNotEmpty) streetArea = addressDetails.streetArea;
        if (addressDetails.landmark.isNotEmpty) landmark = addressDetails.landmark;
        if (addressDetails.cityState.isNotEmpty) cityState = addressDetails.cityState;
        if (addressDetails.pincode.isNotEmpty) pincode = addressDetails.pincode;
      } catch (_) {}

      // 4. Resilient Fallback: If streetArea or cityState is still blank, query reverse geocode API
      if (streetArea.isEmpty || cityState.isEmpty) {
        try {
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
          );
          final res = await http.get(url, headers: {'User-Agent': 'ParindeyFoodApp/1.0'}).timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final addr = data['address'] as Map<String, dynamic>?;
            if (addr != null) {
              houseNo = addr['house_number'] ?? addr['building'] ?? houseNo;
              streetArea = [
                addr['road'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'],
                addr['city_district'] ?? addr['subdistrict'],
              ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');

              final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? 'Indore';
              final state = addr['state'] ?? 'Madhya Pradesh';
              cityState = '$city, $state';
              pincode = addr['postcode'] ?? pincode;
            }
          }
        } catch (_) {}
      }

      // 5. Update UI controllers
      if (mounted) {
        setState(() {
          if (houseNo.isNotEmpty) _houseNoController.text = houseNo;
          if (streetArea.isNotEmpty) _streetAreaController.text = streetArea;
          if (landmark.isNotEmpty) _landmarkController.text = landmark;
          if (cityState.isNotEmpty) _cityStateController.text = cityState;
          if (pincode.isNotEmpty) _pincodeController.text = pincode;
        });

        final fullAddr = _getFormattedFullAddress();

        // 6. Persist to storage
        await StorageService.setString('userHouseNo', _houseNoController.text.trim());
        await StorageService.setString('userStreetArea', _streetAreaController.text.trim());
        await StorageService.setString('userLandmark', _landmarkController.text.trim());
        await StorageService.setString('userCityState', _cityStateController.text.trim());
        await StorageService.setString('userPincode', _pincodeController.text.trim());
        await StorageService.setString('userAddress', fullAddr);
        await StorageService.setString('userLat', position.latitude.toString());
        await StorageService.setString('userLng', position.longitude.toString());
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to detect location: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (!silent && mounted) {
        Navigator.pop(context); // Dismiss pulse dialog when finished
      }
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
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

    if (parts.isNotEmpty) return parts.join(', ');
    return _isDetectingLocation ? 'Detecting current GPS location...' : 'Tap CHANGE to set delivery address';
  }

  void _showAddressEditBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Delivery Address',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              ),
                              icon: _isDetectingLocation
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfc8019)))
                                  : const Icon(Icons.my_location, size: 16, color: Color(0xFFfc8019)),
                              label: Text(
                                _isDetectingLocation ? 'LOCATING...' : 'AUTO-GPS',
                                style: const TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: _isDetectingLocation
                                  ? null
                                  : () async {
                                setBottomSheetState(() => _isDetectingLocation = true);
                                await _autoDetectGpsLocation(silent: false);
                                setBottomSheetState(() => _isDetectingLocation = false);
                              },
                            ),
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
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
                        labelText: 'Flat / House / Building No.',
                        hintText: 'e.g. Flat 302, Tower B',
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
                        hintText: 'e.g. MG Road, Near City Mall',
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
                              hintText: 'e.g. Opposite Bank',
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
                        hintText: 'e.g. Indore, Madhya Pradesh',
                        prefixIcon: const Icon(Icons.location_city, size: 20, color: Color(0xFFfc8019)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFfc8019),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final fullAddr = _getFormattedFullAddress();
                          await StorageService.setString('userHouseNo', _houseNoController.text.trim());
                          await StorageService.setString('userStreetArea', _streetAreaController.text.trim());
                          await StorageService.setString('userLandmark', _landmarkController.text.trim());
                          await StorageService.setString('userCityState', _cityStateController.text.trim());
                          await StorageService.setString('userPincode', _pincodeController.text.trim());
                          await StorageService.setString('userAddress', fullAddr);

                          if (mounted) setState(() {});
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('SAVE & DELIVER HERE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _calculateDistanceInKm(RestaurantModel? rest) {
    if (_latitude == null || _longitude == null || rest == null) {
      return 2.5; // default fallback distance
    }
    final shopLat = rest.latitude ?? 22.7196;
    final shopLng = rest.longitude ?? 75.8577;

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
    FocusScope.of(context).unfocus();

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
        const SnackBar(content: Text('Please fill out name, phone and delivery address')),
      );
      return;
    }

    // Ensure GPS coordinates are loaded or fetched before submitting order
    if (_latitude == null || _longitude == null) {
      await _autoDetectGpsLocation(silent: false);
    }

    final double finalLat = _latitude ?? 22.7196;
    final double finalLng = _longitude ?? 75.8577;

    setState(() => _isPlacingOrder = true);

    try {
      final orderRequest = OrderRequest(
        restaurantId: cartState.restaurantId!,
        customerName: name,
        customerPhone: phone,
        deliveryAddress: fullAddress,
        latitude: finalLat,
        longitude: finalLng,
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

            // Delivery Address Summary Card
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
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFfc8019), size: 22),
                          const SizedBox(width: 8),
                          const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          if (_isDetectingLocation) ...[
                            const SizedBox(width: 8),
                            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfc8019))),
                          ],
                        ],
                      ),
                      TextButton(
                        onPressed: () => _showAddressEditBottomSheet(),
                        child: const Text('CHANGE', style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getFormattedFullAddress(),
                    style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _showAddressEditBottomSheet(),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_nameController.text.isEmpty ? 'User' : _nameController.text} • +91 ${_phoneController.text.isEmpty ? '...' : _phoneController.text}',
                            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFfc8019)),
                      ],
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

            // Bill Details
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