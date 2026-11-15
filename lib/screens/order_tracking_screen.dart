import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_model.dart';
import '../providers/app_providers.dart';
import 'home_screen.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final OrderResponse? order;

  const OrderTrackingScreen({super.key, this.order});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _timer;
  late OrderResponse _currentOrder;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order ??
        OrderResponse(
          id: '123456789',
          restaurantId: 'd0e12345-6789-abcd-ef01-234567890abc',
          restaurantName: 'Royal Biryani House',
          restaurantAddress: 'Shop 12, Main Market, Indirapuram',
          status: 'PLACED',
          totalAmount: 450.0,
          customerName: 'Rahul Sharma',
          customerPhone: '9876543210',
          deliveryAddress: 'Flat 402, Sunshine Heights, Sector 18, Indirapuram',
        );

    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshOrderDetails();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrderDetails() async {
    if (_currentOrder.id.isEmpty) return;
    setState(() => _isRefreshing = true);

    try {
      final api = ref.read(userApiServiceProvider);
      final updated = await api.getOrderById(_currentOrder.id);
      if (mounted) {
        setState(() {
          _currentOrder = updated;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _callDeliveryPartner(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Calling +91 $phone')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot make phone call: $e')),
        );
      }
    }
  }

  int _getStepIndex(String status) {
    switch (status.toUpperCase()) {
      case 'PLACED':
        return 0;
      case 'CONFIRMED':
      case 'PREPARING':
        return 1;
      case 'ASSIGNED_TO_ADMIN':
      case 'ASSIGNED_TO_RIDER':
      case 'READY_FOR_PICKUP':
        return 2;
      case 'OUT_FOR_DELIVERY':
        return 3;
      case 'DELIVERED':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _currentOrder.id.length > 8 ? _currentOrder.id.substring(0, 8) : _currentOrder.id;
    final status = _currentOrder.status;
    final total = _currentOrder.totalAmount;
    final currentStep = _getStepIndex(status);

    final rName = _currentOrder.restaurantName ?? 'Restaurant';
    final rAddress = _currentOrder.restaurantAddress ?? 'Main Market, City Center';
    final dAddress = _currentOrder.deliveryAddress;

    final riderName = _currentOrder.deliveryPartnerName ?? 'Amit Kumar';
    final riderPhone = _currentOrder.deliveryPartnerPhone ?? '9811223344';
    final hasRider = status == 'OUT_FOR_DELIVERY' || status == 'DELIVERED' || _currentOrder.deliveryPartnerId != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Track Order #$orderId', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfc8019)))
                : const Icon(Icons.refresh, color: Color(0xFFfc8019)),
            onPressed: _isRefreshing ? null : _refreshOrderDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: Color(0xFFfc8019), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(
                          'Status: $status',
                          style: const TextStyle(color: Color(0xFF60b246), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Live Stepper Progress Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Order Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildStatusStep(
                    'Order Placed 🟢',
                    'Awaiting restaurant confirmation',
                    currentStep >= 0,
                    currentStep == 0,
                  ),
                  _buildStatusStep(
                    'Kitchen is Cooking 👨‍🍳',
                    'Food being freshly prepared',
                    currentStep >= 1,
                    currentStep == 1,
                  ),
                  _buildStatusStep(
                    'Food Ready & Assigned 📦',
                    'Assigning nearest delivery partner',
                    currentStep >= 2,
                    currentStep == 2,
                  ),
                  _buildStatusStep(
                    'Out for Delivery 🛵',
                    'Delivery partner is on the way',
                    currentStep >= 3,
                    currentStep == 3,
                  ),
                  _buildStatusStep(
                    'Order Delivered 🎉',
                    'Enjoy your delicious meal!',
                    currentStep >= 4,
                    currentStep == 4,
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Delivery Partner Card with Call Button
            if (hasRider) ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery Partner Assigned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          radius: 24,
                          child: const Icon(Icons.two_wheeler, color: Color(0xFFfc8019), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(riderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('+91 $riderPhone', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF60b246),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.phone, size: 16, color: Colors.white),
                          label: const Text('CALL RIDER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _callDeliveryPartner(riderPhone),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Pickup & Drop Location Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery Route Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.storefront, color: Color(0xFFfc8019), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(rAddress, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 10, top: 4, bottom: 4),
                    child: SizedBox(
                      height: 20,
                      child: VerticalDivider(thickness: 2, color: Colors.grey),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.green, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(dAddress, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStep(String title, String subtitle, bool isCompleted, bool isActive, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? const Color(0xFF60b246) : (isActive ? const Color(0xFFfc8019) : Colors.grey[300]),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: isCompleted ? const Color(0xFF60b246) : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isActive || isCompleted ? Colors.black : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: isActive || isCompleted ? Colors.black87 : Colors.grey[400], fontSize: 13)),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }
}
