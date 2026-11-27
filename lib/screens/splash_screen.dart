import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _radarController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _radarScaleAnimation;

  String _locationStatusText = 'Locating delivery address...';

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _logoScaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _radarScaleAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeOut),
    );

    _initAppAndLocation();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _initAppAndLocation() async {
    // 1. Read cached address for instant display (<10ms)
    final cachedAddr = await StorageService.getString('userAddress');
    if (cachedAddr != null && cachedAddr.isNotEmpty && mounted) {
      setState(() {
        _locationStatusText = cachedAddr;
      });
    }

    // 2. Fetch fresh high-precision GPS position & address in background during splash screen
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        final addressDetails = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
        final fullAddr = addressDetails.fullAddress;

        if (fullAddr.isNotEmpty && mounted) {
          setState(() {
            _locationStatusText = fullAddr;
          });
        }

        // Save granular address & coordinates to StorageService
        await StorageService.setString('userHouseNo', addressDetails.houseNo);
        await StorageService.setString('userStreetArea', addressDetails.streetArea);
        await StorageService.setString('userLandmark', addressDetails.landmark);
        await StorageService.setString('userCityState', addressDetails.cityState);
        await StorageService.setString('userPincode', addressDetails.pincode);
        await StorageService.setString('userAddress', fullAddr);
        await StorageService.setString('userLat', pos.latitude.toString());
        await StorageService.setString('userLng', pos.longitude.toString());

        // Pre-match city with DB
        final userCity = addressDetails.city.isNotEmpty ? addressDetails.city : 'Indore';
        final api = ref.read(userApiServiceProvider);
        final dbCities = await api.getCities();
        final match = dbCities.where((c) => c.name.toLowerCase() == userCity.toLowerCase()).firstOrNull;
        if (match != null) {
          ref.read(selectedCityProvider.notifier).selectCity(match);
        }
      }
    } catch (_) {}

    // 3. Ensure Auth State is read from StorageService before routing decision
    await ref.read(authProvider.notifier).checkLoginStatus();

    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;
    final authState = ref.read(authProvider);

    if (!authState.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/auth');
    } else if (authState.name == null || authState.name!.trim().isEmpty) {
      Navigator.pushReplacementNamed(context, '/signup-profile');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFfc8019);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Brand Logo & Pulsing Rings Animation
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Concentric Pulsing Radar Ring
                      AnimatedBuilder(
                        animation: _radarController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _radarScaleAnimation.value,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor.withValues(
                                    alpha: (1.0 - _radarController.value).clamp(0.0, 0.4),
                                  ),
                                  width: 2,
                                ),
                                color: primaryColor.withValues(
                                  alpha: (1.0 - _radarController.value).clamp(0.0, 0.15),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Animated Main Logo Circle
                      ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 20,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              width: 130,
                              height: 130,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.restaurant_menu, size: 54, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'PARINDEY FOODS',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'DELIVERING HAPPINESS AT YOUR DOORSTEP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Swiggy-Style Live Location Radar Bar
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange[200]!),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _radarController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _radarScaleAnimation.value,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor.withValues(
                                    alpha: (1.0 - _radarController.value).clamp(0.0, 0.35),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const Icon(Icons.location_on, color: primaryColor, size: 20),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'DELIVERY LOCATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _locationStatusText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
