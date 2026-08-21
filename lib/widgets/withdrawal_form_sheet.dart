import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/withdrawal.dart';

class WithdrawalFormSheet extends StatefulWidget {
  const WithdrawalFormSheet({super.key, this.withdrawal, required this.onSave});
  final Withdrawal? withdrawal;
  final Future<void> Function(int amount, String note) onSave;

  @override
  State<WithdrawalFormSheet> createState() => _WithdrawalFormSheetState();
}

class _WithdrawalFormSheetState extends State<WithdrawalFormSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.withdrawal?.amount.toString() ?? '');
    _note = TextEditingController(text: widget.withdrawal?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغ السحب')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(amount, _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.withdrawal == null ? 'تسجيل سحب نقدي' : 'تعديل السحب', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'المبلغ', suffixText: 'ريال'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة — اختياري', hintText: 'مثال: مصروف شخصي')),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.check_rounded), label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ السحب'))),
        ]),
      ),
    );
  }
}
