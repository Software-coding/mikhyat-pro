import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customer.dart';

class CustomerFormSheet extends StatefulWidget {
  const CustomerFormSheet({super.key, this.customer, required this.onSave});

  final Customer? customer;
  final Future<void> Function(
    String name,
    String phone,
    String notes,
    double? shoulder,
    double? chest,
    double? waist,
    double? hips,
    double? sleeveLength,
    double? garmentLength,
  ) onSave;

  @override
  State<CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<CustomerFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  late final Map<String, TextEditingController> _measurements;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
    _notes = TextEditingController(text: customer?.notes ?? '');
    _measurements = {
      'shoulder': TextEditingController(text: _measurementText(customer?.shoulder)),
      'chest': TextEditingController(text: _measurementText(customer?.chest)),
      'waist': TextEditingController(text: _measurementText(customer?.waist)),
      'hips': TextEditingController(text: _measurementText(customer?.hips)),
      'sleeve': TextEditingController(text: _measurementText(customer?.sleeveLength)),
      'length': TextEditingController(text: _measurementText(customer?.garmentLength)),
    };
  }

  String _measurementText(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  double? _measurement(String key) {
    final raw = _measurements[key]!.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    for (final controller in _measurements.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم العميل')),
      );
      return;
    }

    final invalidMeasurement = _measurements.values.any((controller) {
      final raw = controller.text.trim().replaceAll(',', '.');
      if (raw.isEmpty) return false;
      final value = double.tryParse(raw);
      return value == null || value <= 0 || value > 500;
    });
    if (invalidMeasurement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تحقق من المقاسات المدخلة بالسنتيمتر')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(
        _name.text.trim(),
        _phone.text.trim(),
        _notes.text.trim(),
        _measurement('shoulder'),
        _measurement('chest'),
        _measurement('waist'),
        _measurement('hips'),
        _measurement('sleeve'),
        _measurement('length'),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ العميل: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customer == null ? 'عميل جديد' : 'تعديل بيانات العميل',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 3),
                        const Text('بيانات التواصل والمقاسات في مكان واحد'),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم العميل *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'المقاسات',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text('بالسنتيمتر — اترك أي خانة غير مطلوبة فارغة'),
                  const SizedBox(height: 12),
                  _MeasurementGrid(controllers: _measurements),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      hintText: 'تفاصيل القماش، الموديل، ملاحظات خاصة...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE6E1D8))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ العميل'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementGrid extends StatelessWidget {
  const _MeasurementGrid({required this.controllers});

  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    const fields = [
      ('shoulder', 'الكتف'),
      ('chest', 'الصدر'),
      ('waist', 'الخصر'),
      ('hips', 'الورك'),
      ('sleeve', 'طول الكم'),
      ('length', 'الطول'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: fields
              .map(
                (field) => SizedBox(
                  width: width,
                  child: TextField(
                    controller: controllers[field.$1],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: field.$2,
                      suffixText: 'سم',
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
