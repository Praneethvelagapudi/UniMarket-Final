import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app.dart';
import '../widgets/common.dart';
import 'item_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _department = TextEditingController(),
      _sale = TextEditingController(),
      _rent = TextEditingController();
  String _category = 'Books', _condition = 'Good';
  bool _buy = true, _rental = true, _busy = false;
  Uint8List? _image;
  String? _mime;
  @override
  void dispose() {
    for (final c in [_title, _description, _department, _sale, _rent]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw ArgumentError('Choose an image smaller than 5 MB.');
      }
      final mime =
          photo.mimeType ??
          (photo.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      if (!['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
        throw ArgumentError('Choose a JPEG, PNG or WebP image.');
      }
      if (mounted) {
        setState(() {
          _image = bytes;
          _mime = mime;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String? _price(String? value) {
    final n = double.tryParse(value ?? '');
    return n == null ||
            !n.isFinite ||
            n <= 0 ||
            n > 1000000 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value?.trim() ?? '')
        ? 'Enter a price from ₹0.01 to ₹1,000,000 (up to 2 decimals).'
        : null;
  }

  Future<void> _publish() async {
    if (!_form.currentState!.validate()) return;
    if (!_buy && !_rental) {
      showNotice(context, 'Choose buy, rent, or both.');
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await AppScope.of(context).market.publish(
        {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'department': _department.text.trim().toUpperCase(),
          'category': _category,
          'condition': _condition,
          'salePrice': _buy ? double.parse(_sale.text) : 0.0,
          'dailyRate': _rental ? double.parse(_rent.text) : 0.0,
        },
        _image,
        _mime,
      );
      if (mounted) {
        showNotice(context, 'Your item is now listed on campus.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ItemScreen(id: id)),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('List an item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Give it a second semester.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set your price. Help another student get started.',
                  ),
                  const SizedBox(height: 24),
                  if (_image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        _image!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Choose photo'),
                      ),
                      if (!kIsWeb)
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                        ),
                      if (_image != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _image = null),
                          child: const Text('Remove photo'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Photo optional · JPEG, PNG or WebP · up to 5 MB',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Item title'),
                    validator: (v) => v == null || v.trim().length < 3
                        ? 'Use at least 3 characters.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Edition, included components, and anything a buyer should know.',
                    ),
                    validator: (v) => v == null || v.trim().length < 10
                        ? 'Add a description of at least 10 characters.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _department,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Relevant department',
                      hintText: 'CSE, ECE, MECH…',
                    ),
                    validator: (v) =>
                        !RegExp(r'^[A-Za-z]{2,15}$').hasMatch(v?.trim() ?? '')
                        ? 'Enter the department abbreviation.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items:
                        [
                              'Books',
                              'Electronics',
                              'Lab equipment',
                              'Stationery',
                              'Other',
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _condition,
                    decoration: const InputDecoration(labelText: 'Condition'),
                    items: ['Like new', 'Good', 'Used']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _condition = v!),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available to buy'),
                    value: _buy,
                    onChanged: _busy ? null : (v) => setState(() => _buy = v),
                  ),
                  if (_buy)
                    TextFormField(
                      controller: _sale,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Sale price',
                        prefixText: '₹ ',
                      ),
                      validator: _price,
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available to rent'),
                    value: _rental,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _rental = v),
                  ),
                  if (_rental)
                    TextFormField(
                      controller: _rent,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Daily rental rate',
                        prefixText: '₹ ',
                      ),
                      validator: _price,
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: BusyButton(
                      busy: _busy,
                      onPressed: _publish,
                      label: 'Publish listing',
                      icon: Icons.add_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
