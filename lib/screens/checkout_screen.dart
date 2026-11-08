import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/shop_order.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'order_success_screen.dart';

const List<String> kCities = [
  'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad',
  'Multan', 'Peshawar', 'Quetta', 'Hyderabad', 'Other',
];

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.items});

  final List<Item> items;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  UserProfile? _profile;
  String? _city;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await AuthService.instance.getProfile(user.uid);
      if (!mounted) return;
      setState(() => _profile = profile);
      if (profile != null && _nameController.text.isEmpty) {
        _nameController.text = profile.name;
      }
    } catch (_) {}
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizedPhone() =>
      _phoneController.text.replaceAll(RegExp(r'[\s-]'), '');

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = _profile;
    if (profile == null) {
      _showMessage('Your profile is still loading. Try again in a moment.');
      return;
    }

    setState(() => _placing = true);
    try {
      final orderIds = await OrderService.instance.placeOrder(
        buyer: profile,
        items: widget.items,
        shipping: ShippingAddress(
          name: _nameController.text.trim(),
          phone: _normalizedPhone(),
          city: _city!,
          address: _addressController.text.trim(),
        ),
      );
      for (final item in widget.items) {
        CartService.instance.remove(item.id);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(orderIds: orderIds)),
        (route) => route.isFirst,
      );
    } on OrderException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not place the order. Please try again.');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _summaryLine(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? AppColors.textDark : AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.items.fold<int>(0, (s, i) => s + i.price);
    final delivery = deliveryFeeFor(widget.items);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('Delivery address'),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'Enter the receiver name'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline,
                        color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final t = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                    if (t.isEmpty) return 'Phone number is required';
                    if (!RegExp(r'^03\d{9}$').hasMatch(t)) {
                      return 'Enter a valid mobile number (03XXXXXXXXX)';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '03XXXXXXXXX',
                    prefixIcon: Icon(Icons.phone_outlined,
                        color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _city,
                  isExpanded: true,
                  items: kCities
                      .map((c) =>
                          DropdownMenuItem<String>(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _city = v),
                  validator: (v) => v == null ? 'Select your city' : null,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    prefixIcon: Icon(Icons.location_city_outlined,
                        color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v ?? '').trim().length < 10
                      ? 'Enter the full address (house, street, area)'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Full address',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.home_outlined,
                        color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 24),

                _sectionTitle('Payment method'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary, width: 1.4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.payments_outlined, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cash on delivery',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text('Pay when you receive your order',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle, color: AppColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _sectionTitle('Order summary'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (final item in widget.items)
                        _summaryLine(item.name, formatPrice(item.price)),
                      const Divider(color: AppColors.border),
                      _summaryLine('Subtotal', formatPrice(subtotal)),
                      _summaryLine('Delivery', formatPrice(delivery)),
                      const Divider(color: AppColors.border),
                      _summaryLine('Total to pay', formatPrice(subtotal + delivery),
                          bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                ElevatedButton(
                  onPressed: _placing ? null : _placeOrder,
                  child: _placing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Place order'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
