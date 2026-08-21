import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/formatters.dart';
import '../models/piece.dart';

class PieceFormSheet extends StatefulWidget {
  const PieceFormSheet({super.key, this.piece, required this.onSave});
  final Piece? piece;
  final Future<void> Function(String description, int quantity, int basePrice, List<PieceModification> mods) onSave;

  static const commonMods = <String>[
    'الطول', 'العرض', 'طول الكم', 'عرض الكم', 'توسيع', 'تضييق', 'تعديل الكتف', 'تعديل الياقة', 'تغيير سحاب'
  ];

  @override
  State<PieceFormSheet> createState() => _PieceFormSheetState();
}

class _PieceFormSheetState extends State<PieceFormSheet> {
  static const defaultModPrice = 500;
  late final TextEditingController _description;
  late final TextEditingController _basePrice;
  final _custom = TextEditingController();
  late int _quantity;
  late List<PieceModification> _mods;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.piece;
    _description = TextEditingController(text: p?.description ?? '');
    _basePrice = TextEditingController(text: p == null || p.hasModifications ? '' : p.basePrice.toString());
    _quantity = p?.quantity ?? 1;
    _mods = p?.modifications.map((m) => m.copyWith()).toList() ?? [];
  }

  @override
  void dispose() {
    _description.dispose();
    _basePrice.dispose();
    _custom.dispose();
    super.dispose();
  }

  int get _total {
    if (_mods.isNotEmpty) {
      return _mods.fold(0, (sum, m) => sum + m.pricePerPiece * m.appliedQuantity);
    }
    return _quantity * (int.tryParse(_basePrice.text) ?? 0);
  }

  void _toggleMod(String name) {
    setState(() {
      final i = _mods.indexWhere((m) => m.name == name);
      if (i >= 0) {
        _mods.removeAt(i);
      } else {
        _mods.add(PieceModification(name: name, pricePerPiece: defaultModPrice, appliedQuantity: _quantity));
      }
    });
  }

  void _changeQuantity(int delta) {
    setState(() {
      _quantity = (_quantity + delta).clamp(1, 9999).toInt();
      _mods = _mods
          .map((m) => m.appliedQuantity > _quantity ? m.copyWith(appliedQuantity: _quantity) : m)
          .toList();
    });
  }

  void _addCustom() {
    final name = _custom.text.trim();
    if (name.isEmpty) return;
    if (_mods.any((m) => m.name == name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا التعديل مضاف بالفعل')));
      return;
    }
    setState(() {
      _mods.add(PieceModification(name: name, pricePerPiece: defaultModPrice, appliedQuantity: _quantity));
      _custom.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final base = int.tryParse(_basePrice.text) ?? 0;
    if (_mods.isEmpty && base <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل سعر القطعة أو اختر تعديلًا')));
      return;
    }
    if (_mods.any((m) => m.pricePerPiece < 0 || m.appliedQuantity < 1 || m.appliedQuantity > _quantity)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من أسعار وأعداد التعديلات')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(_description.text.trim(), _quantity, base, _mods);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMods = _mods.isNotEmpty;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.piece == null ? 'إضافة عمل جديد' : 'تعديل العمل', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  const Text('سريع وواضح — بدون خطوات زائدة'),
                ])),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'وصف القطعة — اختياري', hintText: 'مثال: فستان أسود'),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: _QuantityCard(quantity: _quantity, onMinus: () => _changeQuantity(-1), onPlus: () => _changeQuantity(1)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _basePrice,
                        enabled: !hasMods,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'سعر القطعة',
                          suffixText: 'ريال',
                          hintText: hasMods ? 'غير مستخدم' : '0',
                          helperText: hasMods ? 'معطّل لأن الحساب من التعديلات' : 'يُستخدم إذا لم تختر تعديلات',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  Text('التعديلات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text('كل تعديل يبدأ بـ 500 ريال، وتستطيع تغيير السعر والعدد.'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PieceFormSheet.commonMods.map((name) {
                      final active = _mods.any((m) => m.name == name);
                      return FilterChip(
                        selected: active,
                        label: Text('$name  +500'),
                        onSelected: (_) => _toggleMod(name),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: TextField(controller: _custom, decoration: const InputDecoration(labelText: 'تعديل آخر', hintText: 'اكتب اسم التعديل'))),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(onPressed: _addCustom, icon: const Icon(Icons.add_rounded), tooltip: 'إضافة تعديل'),
                  ]),
                  if (_mods.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('تفاصيل التعديلات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    ..._mods.asMap().entries.map((entry) => _ModificationEditor(
                      modification: entry.value,
                      maxQuantity: _quantity,
                      onChanged: (m) => setState(() => _mods[entry.key] = m),
                      onRemove: () => setState(() => _mods.removeAt(entry.key)),
                    )),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: const Color(0xFF26352F), borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('الإجمالي الآن', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(money(_total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        hasMods ? 'الحساب من أسعار التعديلات فقط — سعر القطعة العادي لا يُضاف.' : '$_quantity × ${money(int.tryParse(_basePrice.text) ?? 0)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE6E1D8)))),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء'))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ العمل'),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityCard extends StatelessWidget {
  const _QuantityCard({required this.quantity, required this.onMinus, required this.onPlus});
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6E1D8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('عدد القطع', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton.filledTonal(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
          Text('$quantity', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          IconButton.filledTonal(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
        ]),
      ]),
    );
  }
}

class _ModificationEditor extends StatelessWidget {
  const _ModificationEditor({required this.modification, required this.maxQuantity, required this.onChanged, required this.onRemove});
  final PieceModification modification;
  final int maxQuantity;
  final ValueChanged<PieceModification> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(modification.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded), color: Colors.redAccent),
          ]),
          Row(children: [
            Expanded(child: TextFormField(
              key: ValueKey('price-${modification.name}-${modification.id ?? 0}'),
              initialValue: '${modification.pricePerPiece}',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'السعر', suffixText: 'ريال'),
              onChanged: (v) => onChanged(modification.copyWith(pricePerPiece: int.tryParse(v) ?? 0)),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              key: ValueKey('qty-${modification.name}-${modification.id ?? 0}-$maxQuantity'),
              initialValue: '${modification.appliedQuantity.clamp(1, maxQuantity).toInt()}',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'على عدد', suffixText: 'من $maxQuantity'),
              onChanged: (v) => onChanged(modification.copyWith(appliedQuantity: (int.tryParse(v) ?? 1).clamp(1, maxQuantity).toInt())),
            )),
          ]),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: Text('المجموع: ${money(modification.subtotal)}', style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
    );
  }
}
