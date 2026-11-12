import 'package:flutter/material.dart';
import '../config/stripe_config.dart';
import '../models/item.dart';
import '../models/shop_order.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/card_payment.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'order_success_screen.dart';

const List<String> kCities = [
  'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad',
  'Multan', 'Peshawar', 'Quetta', 'Hyderabad', 'Other',
];

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.items,
    this.priceOverrides = const {},
  });

  final List<Item> items;

  /// itemId -> agreed offer price. Empty for a normal checkout.
  final Map<String, int> priceOverrides;

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
  String _method = 'cod';
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
      String paymentMethod = 'cod';
      String paymentStatus = 'due';
      String? paymentIntentId;

      if (_method == 'card') {
        final session =
            await PaymentService.instance.createCardSession(widget.items);
        if (!mounted) return;
        await presentCardPayment(context, session);
        if (!mounted) return;
        await PaymentService.instance.verifyCardPayment(session);
        if (!mounted) return;
        paymentMethod = 'card';
        paymentStatus = 'paid';
        paymentIntentId = session.paymentIntentId;
      }

      final List<String> orderIds;
      try {
        orderIds = await OrderService.instance.placeOrder(
          buyer: profile,
          items: widget.items,
          priceOverrides: widget.priceOverrides,
          paymentMethod: paymentMethod,
          paymentStatus: paymentStatus,
          paymentIntentId: paymentIntentId,
          shipping: ShippingAddress(
            name: _nameController.text.trim(),
            phone: _normalizedPhone(),
            city: _city!,
            address: _addressController.text.trim(),
          ),
        );
      } on OrderException catch (e) {
        // Card already charged: never let this look like a plain failed order.
        if (paymentIntentId != null) {
          throw PaymentException(
            '${e.message} Your card was charged (ref $paymentIntentId). '
            'Keep this reference and contact support for a refund.',
          );
        }
        rethrow;
      }
      for (final item in widget.items) {
        CartService.instance.remove(item.id);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderIds: orderIds,
            paidByCard: paymentMethod == 'card',
          ),
        ),
        (route) => route.isFirst,
      );
    } on PaymentException catch (e) {
      _showMessage(e.message);
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

  int _priceFor(Item item) => widget.priceOverrides[item.id] ?? item.price;

  Widget _paymentOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool selected = _method == value;
    return GestureDetector(
      onTap: _placing ? null : () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal =
        widget.items.fold<int>(0, (s, i) => s + _priceFor(i));
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
                _paymentOption(
                  value: 'cod',
                  icon: Icons.payments_outlined,
                  title: 'Cash on delivery',
                  subtitle: 'Pay when you receive your order',
                ),
                if (stripeConfigured) ...[
                  const SizedBox(height: 10),
                  _paymentOption(
                    value: 'card',
                    icon: Icons.credit_card_rounded,
                    title: 'Card payment',
                    subtitle:
                        'Visa / Mastercard · charged as ${usdLabelForPkr(subtotal + delivery)} via Stripe',
                  ),
                  if (_method == 'card')
                    const Padding(
                      padding: EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        'Stripe test mode: use 4242 4242 4242 4242 with any future expiry and CVC.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ),
                ],
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
                        _summaryLine(
                          widget.priceOverrides.containsKey(item.id)
                              ? '${item.name} · offer price'
                              : item.name,
                          formatPrice(_priceFor(item)),
                        ),
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
                      : Text(_method == 'card'
                          ? 'Pay & place order'
                          : 'Place order'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
