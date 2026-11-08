import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Create a new listing, or edit an existing one when [item] is given.
class AddEditItemScreen extends StatefulWidget {
  const AddEditItemScreen({super.key, this.item});

  final Item? item;

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  // Photos are compressed and stored inside the Firestore document.
  static const int _maxPhotos = 4;
  static const int _maxTotalBytes = 600 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  final ImagePicker _picker = ImagePicker();

  final List<Uint8List> _photos = [];
  String? _category;
  String? _size;
  String? _condition;
  bool _photoError = false;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _brandController = TextEditingController(text: item?.brand ?? '');
    _priceController =
        TextEditingController(text: item == null ? '' : item.price.toString());
    _descriptionController =
        TextEditingController(text: item?.description ?? '');
    _priceController.addListener(() => setState(() {}));

    if (item != null) {
      _category = item.category;
      _size = item.size;
      _condition = item.condition;
      for (final encoded in item.images) {
        try {
          _photos.add(base64Decode(encoded));
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) {
      _showMessage('You can add up to $_maxPhotos photos');
      return;
    }
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 700,
        imageQuality: 55,
      );
      for (final file in files.take(remaining)) {
        _photos.add(await file.readAsBytes());
      }
      if (mounted) setState(() => _photoError = false);
    } catch (_) {
      _showMessage('Could not open your gallery');
    }
  }

  Future<void> _save() async {
    final bool formValid = _formKey.currentState!.validate();
    if (_photos.isEmpty) setState(() => _photoError = true);
    if (!formValid || _photos.isEmpty) return;

    final totalBytes = _photos.fold<int>(0, (sum, b) => sum + b.length);
    if (totalBytes > _maxTotalBytes) {
      _showMessage('Photos are too large. Remove one or pick smaller photos.');
      return;
    }

    final images = _photos.map(base64Encode).toList();
    final price = int.parse(_priceController.text.trim());

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ItemService.instance.updateItem(
          widget.item!.id,
          name: _nameController.text,
          category: _category!,
          brand: _brandController.text,
          size: _size!,
          condition: _condition!,
          price: price,
          description: _descriptionController.text,
          images: images,
        );
      } else {
        final user = AuthService.instance.currentUser;
        final UserProfile? seller = user == null
            ? null
            : await AuthService.instance.getProfile(user.uid);
        if (seller == null) {
          _showMessage('Your profile was not found. Please log in again.');
          return;
        }
        await ItemService.instance.addItem(
          seller: seller,
          name: _nameController.text,
          category: _category!,
          brand: _brandController.text,
          size: _size!,
          condition: _condition!,
          price: price,
          description: _descriptionController.text,
          images: images,
        );
      }
      if (!mounted) return;
      _showMessage(_isEdit ? 'Item updated' : 'Item posted');
      Navigator.of(context).pop();
    } catch (_) {
      _showMessage('Could not save the item. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoTile(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              _photos[index],
              width: 92,
              height: 92,
              fit: BoxFit.cover,
            ),
          ),
          if (index == 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Cover',
                    style: TextStyle(color: Colors.white, fontSize: 10.5)),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _photos.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Photos', style: Theme.of(context).textTheme.titleMedium),
            Text('${_photos.length}/$_maxPhotos',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (_photos.length < _maxPhotos)
                GestureDetector(
                  onTap: _pickPhotos,
                  child: Container(
                    width: 92,
                    height: 92,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.fill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _photoError
                            ? AppColors.error
                            : AppColors.border,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: AppColors.primary),
                        SizedBox(height: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              for (var i = 0; i < _photos.length; i++) _photoTile(i),
            ],
          ),
        ),
        if (_photoError)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text('Add at least one photo',
                style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: options
          .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Select ${label.toLowerCase()}' : null,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildFeePreview() {
    final price = int.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) return const SizedBox.shrink();
    final fee = (price * kPlatformFeeRate).round();
    final percent = (kPlatformFeeRate * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined,
                size: 18, color: AppColors.textDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ThriftMate fee ($percent%): ${formatPrice(fee)}   •   '
                'You receive: ${formatPrice(price - fee)}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit item' : 'Sell an item')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPhotos(),
                const SizedBox(height: 22),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Item name is required';
                    if (t.length < 3) return 'At least 3 characters';
                    if (t.length > 60) return 'At most 60 characters';
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g. Embroidered lawn kurta',
                  ),
                ),
                const SizedBox(height: 16),

                _dropdown(
                  label: 'Category',
                  options: kCategories,
                  value: _category,
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _brandController,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? "Brand is required (write 'No brand' if none)"
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    hintText: 'e.g. Khaadi, Nike or No brand',
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        label: 'Size',
                        options: kSizes,
                        value: _size,
                        onChanged: (v) => setState(() => _size = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdown(
                        label: 'Condition',
                        options: kConditions,
                        value: _condition,
                        onChanged: (v) => setState(() => _condition = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Price is required';
                    final value = int.tryParse(t);
                    if (value == null) return 'Enter a valid price';
                    if (value < 50) return 'Minimum price is Rs. 50';
                    if (value > 1000000) return 'Maximum price is Rs. 1,000,000';
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Price (PKR)',
                    prefixText: 'Rs. ',
                  ),
                ),
                _buildFeePreview(),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Description is required';
                    if (t.length < 10) return 'Write at least 10 characters';
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Fabric, fit, any flaws, how many times worn...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 22),

                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEdit ? 'Save changes' : 'Post item'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
