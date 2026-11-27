import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_model.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import '../services/user_api_service.dart';

class SignupProfileScreen extends ConsumerStatefulWidget {
  final String? phone;

  const SignupProfileScreen({super.key, this.phone});

  @override
  ConsumerState<SignupProfileScreen> createState() => _SignupProfileScreenState();
}

class _SignupProfileScreenState extends ConsumerState<SignupProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  void _loadPhone() async {
    final savedPhone = widget.phone ?? (await StorageService.getString('userPhone')) ?? '';
    _phoneController.text = savedPhone.isNotEmpty ? '+91 $savedPhone' : '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty || fullName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid full name (at least 2 characters)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(userApiServiceProvider);
      await api.updateProfile(fullName);

      // Update local Auth State with updated name
      final currentAuth = ref.read(authProvider);
      ref.read(authProvider.notifier).setLoggedIn(
        AuthResponse(
          userId: currentAuth.userId ?? '',
          phone: currentAuth.phone ?? '',
          fullName: fullName,
          role: 'ROLE_CUSTOMER',
          accessToken: currentAuth.token ?? '',
          refreshToken: '',
        ),
        name: fullName,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Parindey Foods!'),
            backgroundColor: Color(0xFF60b246),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String msg = e is UserApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $msg'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFfc8019);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars, color: primaryColor, size: 28),
                        SizedBox(width: 8),
                        Text(
                          "Almost there! 🎉",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Let's get to know you! Enter your full name so we can personalize your food delivery experience.",
                      style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Disabled Mobile Number Field
              const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                enabled: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),

              const SizedBox(height: 20),

              // Full Name Input
              const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Rahul Sharma',
                  prefixIcon: const Icon(Icons.person_outline, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _submitProfile,
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('CONTINUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
