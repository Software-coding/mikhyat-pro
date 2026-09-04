import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../models/withdrawal.dart';

class WithdrawalFormSheet extends StatefulWidget {
  const WithdrawalFormSheet({
    super.key,
    this.withdrawal,
    required this.onSave,
  });

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
    _amount = TextEditingController(
      text: widget.withdrawal?.amount.toString() ?? '',
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغ السحب')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(amount, _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppTheme.card,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.mintSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.withdrawal == null
                              ? 'تسجيل سحب نقدي'
                              : 'تعديل السحب',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'أدخل المبلغ وأضف ملاحظة تساعدك لاحقًا',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'المبلغ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amount,
                autofocus: widget.withdrawal == null,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  hintText: 'مثال: 1000',
                  suffixText: 'ريال',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'الملاحظة',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(
                  hintText: 'مثال: مصروف شخصي',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 54,
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
                  label: Text(
                    _saving ? 'جارٍ الحفظ...' : 'حفظ السحب',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
