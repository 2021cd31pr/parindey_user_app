import 'package:flutter/material.dart';
import '../services/location_service.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    final position = await LocationService.getCurrentLocation(
      onError: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
    );

    setState(() => _isLoading = false);

    if (position != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPS Location: Lat ${position.latitude.toStringAsFixed(4)}, Lng ${position.longitude.toStringAsFixed(4)}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Address', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Color(0xFFfc8019)),
                hintText: 'Search for area, street name...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFfc8019)),
                ),
              ),
            ),
          ),
          ListTile(
            leading: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfc8019)))
                : const Icon(Icons.my_location, color: Color(0xFFfc8019)),
            title: const Text('Use current location', style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold)),
            subtitle: const Text('Using GPS device coordinates'),
            onTap: _isLoading ? null : _getCurrentLocation,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('SAVED ADDRESSES', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.black54),
            title: const Text('Home', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Flat 402, Sunshine Heights, Vijay Nagar, Indore'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.work, color: Colors.black54),
            title: const Text('Work', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('IT Park, Building 3, Palasia, Indore'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
