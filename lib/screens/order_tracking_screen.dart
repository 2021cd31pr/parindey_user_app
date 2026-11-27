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
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  late OrderResponse _currentOrder;
  bool _isRefreshing = false;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order ??
        OrderResponse(
          id: '',
          restaurantId: '',
          status: 'PLACED',
          totalAmount: 0.0,
          customerName: '',
          customerPhone: '',
          deliveryAddress: '',
        );

    _updateRemainingTime();
    _startCountdownTimer();
    _startPolling();

    // IMMEDIATELY FETCH LIVE ORDER FROM API ON PAGE OPEN
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOrderDetails();
    });
  }

  void _updateRemainingTime() {
    if (_currentOrder.prepEndsAt != null) {
      final diff = _currentOrder.prepEndsAt!.difference(DateTime.now()).inSeconds;
      _remainingSeconds = diff > 0 ? diff : 0;
    } else {
      _remainingSeconds = _currentOrder.remainingPrepSeconds > 0
          ? _currentOrder.remainingPrepSeconds
          : (_currentOrder.prepTimeMinutes * 60);
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0 &&
          (_currentOrder.status == 'PLACED' || _currentOrder.status == 'ACCEPTED' || _currentOrder.status == 'PREPARING')) {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshOrderDetails();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
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
          _updateRemainingTime();
          _isRefreshing = false;
        });
      }
    } catch (e) {
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
      case 'ACCEPTED':
        return 1;
      case 'PREPARING':
        return 2;
      case 'READY_FOR_PICKUP':
      case 'RIDER_ASSIGNED':
      case 'OUT_FOR_PICKUP':
      case 'REACHED_RESTAURANT':
        return 3;
      case 'OUT_FOR_DELIVERY':
        return 4;
      case 'ARRIVED_AT_CUSTOMER':
      case 'DELIVERED':
        return 5;
      default:
        return 0;
    }
  }

  Widget _buildCountdownWidget() {
    if (_currentOrder.status == 'OUT_FOR_DELIVERY' || _currentOrder.status == 'DELIVERED' || _currentOrder.status == 'ARRIVED_AT_CUSTOMER') {
      return const SizedBox.shrink();
    }

    final mins = (_remainingSeconds / 60).floor().toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final timeStr = '$mins:$secs';
    final progress = _currentOrder.prepTimeMinutes > 0
        ? 1.0 - (_remainingSeconds / (_currentOrder.prepTimeMinutes * 60))
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🍽️ Food is being prepared', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Est: $timeStr', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFfc8019), fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.orange[100],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFfc8019)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (_currentOrder.prepExtendedCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⏳ Restaurant added +${_currentOrder.prepExtendedCount * 5} mins extra time for thorough preparation.',
                      style: TextStyle(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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

    final riderName = _currentOrder.deliveryPartnerName ?? 'Delivery Partner';
    final riderPhone = _currentOrder.deliveryPartnerPhone ?? '';
    final hasRider = (currentStep >= 3) && riderPhone.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Track Order #${orderId.isNotEmpty ? orderId : "..."}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
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
                          'Status: ${status.replaceAll('_', ' ')}',
                          style: const TextStyle(color: Color(0xFF60b246), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),

            // Live Countdown Timer
            _buildCountdownWidget(),

            // Live Stepper Progress Card
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Order Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildStatusStep(
                    'Order Placed 🟢',
                    'Waiting for restaurant confirmation',
                    currentStep >= 0,
                    currentStep == 0,
                  ),
                  _buildStatusStep(
                    'Order Accepted 👍',
                    'Kitchen has started preparing your food',
                    currentStep >= 1,
                    currentStep == 1,
                  ),
                  _buildStatusStep(
                    'Food Preparing 👨‍🍳',
                    'Food in progress in the kitchen',
                    currentStep >= 2,
                    currentStep == 2,
                  ),
                  _buildStatusStep(
                    'Food Ready & Assigned 📦',
                    'Rider is at restaurant, waiting for packaging',
                    currentStep >= 3,
                    currentStep == 3,
                  ),
                  _buildStatusStep(
                    'Out for Delivery 🛵',
                    'Speeding towards your doorstep',
                    currentStep >= 4,
                    currentStep == 4,
                  ),
                  _buildStatusStep(
                    'Order Delivered 🎉',
                    'Enjoy your meal 😋',
                    currentStep >= 5,
                    currentStep == 5,
                    isLast: true,
                  ),
                ],
              ),
            ),

            // Delivery Partner Card with Call Button
            if (hasRider) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery Partner Assigned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange[50],
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
                          label: const Text('CALL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _callDeliveryPartner(riderPhone),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Pickup & Drop Location Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
              ),
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
