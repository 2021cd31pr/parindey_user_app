import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_address_model.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import 'swiggy_location_loading.dart';

class SwiggyAddressModal {
  /// Opens the Swiggy-Style Address Selector Bottom Sheet
  static Future<SavedAddressModel?> showSelectionSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<SavedAddressModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _AddressSelectionSheet(),
    );
  }

  /// Opens the Swiggy-Style Add/Edit Address Form Bottom Sheet
  static Future<SavedAddressModel?> showFormSheet(
    BuildContext context,
    WidgetRef ref, {
    SavedAddressModel? addressToEdit,
  }) {
    return showModalBottomSheet<SavedAddressModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AddressFormSheet(addressToEdit: addressToEdit),
    );
  }
}

class _AddressSelectionSheet extends ConsumerWidget {
  const _AddressSelectionSheet();

  IconData _getIconForLabel(String label) {
    switch (label.toUpperCase()) {
      case 'WORK':
        return Icons.work_outline;
      case 'OTHER':
        return Icons.location_on_outlined;
      case 'HOME':
      default:
        return Icons.home_outlined;
    }
  }

  Color _getColorForLabel(String label) {
    switch (label.toUpperCase()) {
      case 'WORK':
        return Colors.blue;
      case 'OTHER':
        return Colors.purple;
      case 'HOME':
      default:
        return const Color(0xFFfc8019);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAddresses = ref.watch(savedAddressesProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Add New Address Button
          InkWell(
            onTap: () async {
              Navigator.pop(context);
              final newAddr = await SwiggyAddressModal.showFormSheet(context, ref);
              if (newAddr != null) {
                ref.read(selectedAddressProvider.notifier).selectAddress(newAddr);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFfc8019).withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_location_alt_outlined, color: Color(0xFFfc8019), size: 22),
                  SizedBox(width: 12),
                  Text(
                    'ADD NEW ADDRESS',
                    style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (savedAddresses.isNotEmpty)
            const Text('SAVED ADDRESSES', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),

          // Saved Addresses List
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: savedAddresses.map((addr) {
                  final isSelected = selectedAddress?.id == addr.id;
                  final labelColor = _getColorForLabel(addr.label);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange[50]?.withValues(alpha: 0.5) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFfc8019) : Colors.grey[300]!,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: labelColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_getIconForLabel(addr.label), color: labelColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          addr.label.toUpperCase(),
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: labelColor),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.check_circle, color: Color(0xFF60b246), size: 16),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      addr.fullAddress,
                                      style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.3),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${addr.receiverName} • +91 ${addr.receiverPhone}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      final updated = await SwiggyAddressModal.showFormSheet(context, ref, addressToEdit: addr);
                                      if (updated != null) {
                                        ref.read(selectedAddressProvider.notifier).selectAddress(updated);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () {
                                      ref.read(savedAddressesProvider.notifier).removeAddress(addr.id);
                                    },
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected ? const Color(0xFF60b246) : const Color(0xFFfc8019),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  ref.read(selectedAddressProvider.notifier).selectAddress(addr);
                                  Navigator.pop(context, addr);
                                },
                                child: Text(
                                  isSelected ? 'DELIVERING HERE' : 'DELIVER HERE',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  final SavedAddressModel? addressToEdit;

  const _AddressFormSheet({this.addressToEdit});

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  late String _selectedLabel;
  late TextEditingController _houseNoController;
  late TextEditingController _streetAreaController;
  late TextEditingController _landmarkController;
  late TextEditingController _cityStateController;
  late TextEditingController _pincodeController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool _isDetectingGps = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    final addr = widget.addressToEdit;
    final authState = ref.read(authProvider);

    _selectedLabel = addr?.label ?? 'HOME';
    _houseNoController = TextEditingController(text: addr?.houseNo ?? '');
    _streetAreaController = TextEditingController(text: addr?.streetArea ?? '');
    _landmarkController = TextEditingController(text: addr?.landmark ?? '');
    _cityStateController = TextEditingController(text: addr?.cityState ?? '');
    _pincodeController = TextEditingController(text: addr?.pincode ?? '');
    _nameController = TextEditingController(text: addr?.receiverName ?? authState.name ?? 'User');
    _phoneController = TextEditingController(text: addr?.receiverPhone ?? authState.phone ?? '');
    _lat = addr?.latitude;
    _lng = addr?.longitude;
  }

  @override
  void dispose() {
    _houseNoController.dispose();
    _streetAreaController.dispose();
    _landmarkController.dispose();
    _cityStateController.dispose();
    _pincodeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _runAutoGps() async {
    setState(() => _isDetectingGps = true);
    SwiggyLocationPulseDialog.show(context, title: 'Detecting live address...');

    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
        final details = await LocationService.reverseGeocode(pos.latitude, pos.longitude);

        if (mounted) {
          setState(() {
            if (details.houseNo.isNotEmpty) _houseNoController.text = details.houseNo;
            if (details.streetArea.isNotEmpty) _streetAreaController.text = details.streetArea;
            if (details.landmark.isNotEmpty) _landmarkController.text = details.landmark;
            if (details.cityState.isNotEmpty) _cityStateController.text = details.cityState;
            if (details.pincode.isNotEmpty) _pincodeController.text = details.pincode;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
        setState(() => _isDetectingGps = false);
      }
    }
  }

  void _saveAddress() {
    final h = _houseNoController.text.trim();
    final s = _streetAreaController.text.trim();
    final l = _landmarkController.text.trim();
    final c = _cityStateController.text.trim();
    final p = _pincodeController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (s.isEmpty || c.isEmpty || name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out street area, city/state, name, and phone')),
      );
      return;
    }

    final newAddr = SavedAddressModel(
      id: widget.addressToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: _selectedLabel,
      houseNo: h,
      streetArea: s,
      landmark: l,
      cityState: c,
      pincode: p,
      latitude: _lat,
      longitude: _lng,
      receiverName: name,
      receiverPhone: phone,
    );

    ref.read(savedAddressesProvider.notifier).addAddress(newAddr);
    Navigator.pop(context, newAddr);
  }

  Widget _buildLabelChip(String label, IconData icon) {
    final isSelected = _selectedLabel == label;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black87),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFFfc8019),
      onSelected: (_) {
        setState(() {
          _selectedLabel = label;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  widget.addressToEdit != null ? 'Edit Address' : 'Add New Address',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      ),
                      icon: _isDetectingGps
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfc8019)))
                          : const Icon(Icons.my_location, size: 15, color: Color(0xFFfc8019)),
                      label: const Text('AUTO-GPS', style: TextStyle(color: Color(0xFFfc8019), fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _isDetectingGps ? null : _runAutoGps,
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
            const SizedBox(height: 8),

            // Save Address As Label Chips
            const Text('Save address as *', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildLabelChip('HOME', Icons.home_outlined),
                const SizedBox(width: 8),
                _buildLabelChip('WORK', Icons.work_outline),
                const SizedBox(width: 8),
                _buildLabelChip('OTHER', Icons.location_on_outlined),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _houseNoController,
              decoration: InputDecoration(
                labelText: 'Flat / House / Building No.',
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
                      hintText: 'e.g. Near Hanuman Mandir',
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Receiver's Name *",
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
                      labelText: "Receiver's Phone *",
                      prefixIcon: const Icon(Icons.phone_android, size: 20, color: Color(0xFFfc8019)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
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
                onPressed: _saveAddress,
                child: const Text('SAVE ADDRESS & DELIVER HERE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
