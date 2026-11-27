import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_model.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import 'favourites_screen.dart';
import 'help_support_screen.dart';
import 'order_history_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showEditProfileBottomSheet(BuildContext context, WidgetRef ref, AuthState authState) async {
    final nameController = TextEditingController(text: authState.name ?? 'Parindey Customer');
    final phoneController = TextEditingController(text: authState.phone ?? '9876543210');

    final hNo = await StorageService.getString('userHouseNo') ?? '';
    final stArea = await StorageService.getString('userStreetArea') ?? '';
    final lm = await StorageService.getString('userLandmark') ?? '';
    final cState = await StorageService.getString('userCityState') ?? '';
    final pin = await StorageService.getString('userPincode') ?? '';

    final houseNoController = TextEditingController(text: hNo);
    final streetAreaController = TextEditingController(text: stArea);
    final landmarkController = TextEditingController(text: lm);
    final cityStateController = TextEditingController(text: cState);
    final pincodeController = TextEditingController(text: pin);

    bool isDetectingGps = false;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                            'Edit Profile & Address',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFfc8019)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number *',
                        prefixIcon: const Icon(Icons.phone_android, color: Color(0xFFfc8019)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Address Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        TextButton.icon(
                          icon: isDetectingGps
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfc8019)))
                              : const Icon(Icons.my_location, size: 16, color: Color(0xFFfc8019)),
                          label: const Text('AUTO GPS', style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: isDetectingGps
                              ? null
                              : () async {
                                  setState(() => isDetectingGps = true);
                                  final pos = await LocationService.getCurrentLocation(
                                    onError: (msg) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                      }
                                    },
                                  );
                                  if (pos != null) {
                                    final details = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
                                    if (details.houseNo.isNotEmpty) houseNoController.text = details.houseNo;
                                    if (details.streetArea.isNotEmpty) streetAreaController.text = details.streetArea;
                                    if (details.landmark.isNotEmpty) landmarkController.text = details.landmark;
                                    if (details.cityState.isNotEmpty) cityStateController.text = details.cityState;
                                    if (details.pincode.isNotEmpty) pincodeController.text = details.pincode;

                                    setState(() => isDetectingGps = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Auto-detected real-time GPS location address!'), backgroundColor: Colors.green),
                                      );
                                    }
                                  } else {
                                    setState(() => isDetectingGps = false);
                                  }
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: houseNoController,
                      decoration: InputDecoration(
                        labelText: 'Flat / House / Building No. *',
                        prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFFfc8019)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: streetAreaController,
                      decoration: InputDecoration(
                        labelText: 'Street / Area / Colony *',
                        prefixIcon: const Icon(Icons.add_road, color: Color(0xFFfc8019)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: landmarkController,
                            decoration: InputDecoration(
                              labelText: 'Landmark (Optional)',
                              prefixIcon: const Icon(Icons.explore_outlined, color: Color(0xFFfc8019)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: pincodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: 'Pincode *',
                              counterText: '',
                              prefixIcon: const Icon(Icons.pin_drop_outlined, color: Color(0xFFfc8019)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cityStateController,
                      decoration: InputDecoration(
                        labelText: 'City & State *',
                        prefixIcon: const Icon(Icons.location_city, color: Color(0xFFfc8019)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          final h = houseNoController.text.trim();
                          final s = streetAreaController.text.trim();
                          final l = landmarkController.text.trim();
                          final c = cityStateController.text.trim();
                          final p = pincodeController.text.trim();

                          final parts = <String>[];
                          if (h.isNotEmpty) parts.add(h);
                          if (s.isNotEmpty) parts.add(s);
                          if (l.isNotEmpty) parts.add('Near $l');
                          if (c.isNotEmpty) parts.add(c);
                          if (p.isNotEmpty) parts.add('- $p');

                          final fullAddr = parts.isNotEmpty ? parts.join(', ') : '';

                          await StorageService.setString('userHouseNo', h);
                          await StorageService.setString('userStreetArea', s);
                          await StorageService.setString('userLandmark', l);
                          await StorageService.setString('userCityState', c);
                          await StorageService.setString('userPincode', p);
                          await StorageService.setString('userAddress', fullAddr);

                          final dummyAuth = AuthResponse(
                            userId: authState.userId ?? '',
                            phone: phoneController.text.trim(),
                            role: 'ROLE_CUSTOMER',
                            accessToken: authState.token ?? '',
                            refreshToken: '',
                          );

                          ref.read(authProvider.notifier).setLoggedIn(
                                dummyAuth,
                                name: nameController.text.trim(),
                                email: authState.email,
                                address: fullAddr,
                              );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile & Address updated successfully!')),
                            );
                          }
                        },
                        child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showPaymentsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Methods', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.purple, size: 28),
                title: const Text('UPI Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Google Pay, PhonePe, Paytm'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.blue, size: 28),
                title: const Text('Saved Cards', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Visa, Mastercard, RuPay'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.money, color: Colors.green, size: 28),
                title: const Text('Cash on Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Pay when food arrives'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final displayName = (authState.name != null && authState.name!.isNotEmpty)
        ? authState.name!
        : 'Parindey Customer';
    final displayPhone = (authState.phone != null && authState.phone!.isNotEmpty)
        ? authState.phone!
        : '9999999999';
    final displayEmail = (authState.email != null && authState.email!.isNotEmpty)
        ? authState.email!
        : null;

    String displayAddress = (authState.address != null && authState.address!.isNotEmpty)
        ? authState.address!
        : 'Tap EDIT to add your delivery address';
    displayAddress = displayAddress.replaceAll(RegExp(r'\s*\(Lat:.*, Lng:.*\)', caseSensitive: false), '');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        children: [
          // Profile Details Header Container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFfc8019),
                  child: Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('+91 $displayPhone', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      if (displayEmail != null)
                        Text(displayEmail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showEditProfileBottomSheet(context, ref, authState),
                  child: const Text('EDIT', style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Swiggy-style Saved Address Card in Profile
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_filled, color: Color(0xFFfc8019), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                      const SizedBox(height: 4),
                      Text(
                        displayAddress,
                        style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.3),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showEditProfileBottomSheet(context, ref, authState),
                  child: const Text('EDIT', style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Menu Options
          _buildMenuItem(
            context,
            Icons.shopping_bag_outlined,
            'Orders',
            'Past orders history',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
            },
          ),
          _buildMenuItem(
            context,
            Icons.favorite_border,
            'Favourites',
            'Your favourite restaurants',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FavouritesScreen()));
            },
          ),
          _buildMenuItem(
            context,
            Icons.payment,
            'Payments',
            'Saved cards & UPI',
            onTap: () => _showPaymentsBottomSheet(context),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            Icons.help_outline,
            'Help & Support',
            'FAQ & customer care',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
            },
          ),
          const SizedBox(height: 16),

          // Logout Button
          Container(
            color: Colors.white,
            child: ListTile(
              title: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              trailing: const Icon(Icons.power_settings_new, color: Colors.red),
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                ref.read(cartProvider.notifier).clearCart();
                ref.read(activeOrderProvider.notifier).clearActiveOrder();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Colors.black54),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: onTap,
          ),
          const Divider(height: 1, indent: 50),
        ],
      ),
    );
  }
}
