import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/user_api_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  int _selectedTabIndex = 0; // 0 for LOGIN, 1 for SIGN UP
  bool _otpSent = false;
  bool _isLoading = false;

  // Controllers for Login
  final TextEditingController _loginPhoneController = TextEditingController();

  // Controllers for Sign Up
  final TextEditingController _signUpNameController = TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpPhoneController = TextEditingController();
  final TextEditingController _signUpAddressController = TextEditingController();

  // Common OTP controller
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPhoneController.dispose();
    _signUpAddressController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _cleanPhone(String raw) {
    String p = raw.trim().replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('91') && p.length == 12) return p.substring(2);
    return p;
  }

  String get _currentPhone {
    if (_selectedTabIndex == 0) {
      return _cleanPhone(_loginPhoneController.text);
    } else {
      return _cleanPhone(_signUpPhoneController.text);
    }
  }

  bool _isValidPhone(String phone) {
    return phone.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
  }

  bool _isValidEmail(String email) {
    if (email.trim().isEmpty) return true; // Email is optional
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
  }

  bool _isValidName(String name) {
    return name.trim().length >= 2;
  }

  bool _isValidOtp(String otp) {
    return RegExp(r'^\d{4,6}$').hasMatch(otp.trim());
  }

  Future<void> _sendOTP() async {
    final phone = _currentPhone;

    // 1. Phone number validation
    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number starting with 6, 7, 8, or 9'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 2. Sign Up validations if on Sign Up tab (Tab 1)
    if (_selectedTabIndex == 1) {
      final name = _signUpNameController.text;
      final email = _signUpEmailController.text;

      if (!_isValidName(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your full name (at least 2 characters)'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (!_isValidEmail(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid email address (e.g. name@example.com)'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(userApiServiceProvider);

      // 3. Check user existence in database for smart direction
      final exists = await api.checkUserExists(phone);

      if (_selectedTabIndex == 0 && !exists) {
        // User does NOT exist on Login -> Redirect automatically to SIGN UP (Tab 1)!
        setState(() {
          _selectedTabIndex = 1;
          _signUpPhoneController.text = phone;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mobile number not registered! Please enter your name to Sign Up.'),
              backgroundColor: Color(0xFFfc8019),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (_selectedTabIndex == 1 && exists) {
        // User ALREADY exists on Sign Up -> Redirect automatically to LOGIN (Tab 0) & continue sending OTP!
        setState(() {
          _selectedTabIndex = 0;
          _loginPhoneController.text = phone;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mobile number is already registered! Redirected to Sign In.'),
              backgroundColor: Color(0xFFfc8019),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // 4. Send OTP
      await api.sendOtp(phone);
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent successfully to +91 $phone'),
            backgroundColor: const Color(0xFF60b246),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String msg = e is UserApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (!_isValidOtp(otp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the valid OTP sent to your phone'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _currentPhone;
      final api = ref.read(userApiServiceProvider);
      final authResponse = await api.verifyOtp(phone, otp, requestedRole: 'ROLE_CUSTOMER');

      final name = _selectedTabIndex == 1 ? _signUpNameController.text.trim() : null;
      final email = _selectedTabIndex == 1 ? _signUpEmailController.text.trim() : null;
      final address = _selectedTabIndex == 1 ? _signUpAddressController.text.trim() : null;

      ref.read(authProvider.notifier).setLoggedIn(
            authResponse,
            name: name,
            email: email,
            address: address,
          );

      setState(() => _isLoading = false);

      final bool isNew = authResponse.isNewUser == true ||
          authResponse.fullName == null ||
          authResponse.fullName!.trim().isEmpty;

      if (mounted) {
        if (isNew) {
          Navigator.pushReplacementNamed(context, '/signup-profile');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome back to Parindey Foods!'),
              backgroundColor: Color(0xFF60b246),
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String msg = e is UserApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildToggleBar(Color themeColor) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = 0;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? themeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTabIndex == 0
                      ? [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'LOGIN',
                  style: TextStyle(
                    color: _selectedTabIndex == 0 ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = 1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? themeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTabIndex == 1
                      ? [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'SIGN UP',
                  style: TextStyle(
                    color: _selectedTabIndex == 1 ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFfc8019);
    final heroHeight = MediaQuery.of(context).size.height * 0.22;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Responsive Hero Banner
            Stack(
              children: [
                Container(
                  height: heroHeight < 160 ? 160 : heroHeight,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1504674900247-0877df9cc836?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  height: heroHeight < 160 ? 160 : heroHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        themeColor.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
                              ],
                            ),
                            child: const Icon(Icons.restaurant_menu, size: 36, color: themeColor),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PARINDEY FOOD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Card Container for Login & Sign Up / OTP
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Segmented Toggle Switcher (LOGIN / SIGN UP)
                      if (!_otpSent) ...[
                        _buildToggleBar(themeColor),

                        const SizedBox(height: 20),

                        // Form Body
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 250),
                          crossFadeState: _selectedTabIndex == 0
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Login to your account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 4),
                              const Text('Enter your mobile number to receive an OTP', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _loginPhoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: '10-Digit Mobile Number',
                                  prefixIcon: const Icon(Icons.phone_android, color: themeColor),
                                  prefixText: '+91 ',
                                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: themeColor, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Create a new account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 4),
                              const Text('Fill out your details to get started', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _signUpNameController,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Full Name *',
                                  prefixIcon: const Icon(Icons.person_outline, color: themeColor),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: themeColor, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _signUpEmailController,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Email Address (Optional)',
                                  prefixIcon: const Icon(Icons.email_outlined, color: themeColor),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: themeColor, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _signUpPhoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Mobile Number *',
                                  prefixIcon: const Icon(Icons.phone_android, color: themeColor),
                                  prefixText: '+91 ',
                                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: themeColor, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _signUpAddressController,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Delivery Address (Optional)',
                                  prefixIcon: const Icon(Icons.location_on_outlined, color: themeColor),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: themeColor, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // GET OTP Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                            onPressed: _isLoading ? null : _sendOTP,
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    _selectedTabIndex == 0 ? 'CONTINUE WITH OTP' : 'CREATE ACCOUNT & GET OTP',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                      ] else ...[
                        // Swiggy & Zomato Style OTP Verification View
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'VERIFICATION CODE',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: themeColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: const Text('Edit Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  onPressed: _isLoading ? null : () => setState(() => _otpSent = false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'We have sent a 6-digit OTP to +91 $_currentPhone',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 20),

                            TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              enabled: !_isLoading,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                              decoration: InputDecoration(
                                labelText: 'Enter 6-digit OTP',
                                hintText: '123456',
                                hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 8),
                                prefixIcon: const Icon(Icons.lock_outline, color: themeColor),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: themeColor, width: 2),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Helper Badge
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFFe65100), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Test Master OTP: Use 123456 or 000000',
                                      style: TextStyle(color: Color(0xFFe65100), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                ),
                                onPressed: _isLoading ? null : _verifyOTP,
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('VERIFY & PROCEED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Continue as Guest Option
            if (!_otpSent)
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text(
                  'Continue as Guest',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),

            const SizedBox(height: 12),

            // Terms Disclaimer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  children: [
                    TextSpan(text: 'By continuing, you agree to Parindey\'s '),
                    TextSpan(text: 'Terms of Service', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    TextSpan(text: ' & '),
                    TextSpan(text: 'Privacy Policy', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
