import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/withdrawal.dart';
import '../providers/app_store.dart';
import '../widgets/withdrawal_form_sheet.dart';

class WithdrawalsScreen extends StatefulWidget {
  const WithdrawalsScreen({super.key});
  @override
  State<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends State<WithdrawalsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Withdrawal> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  int _seenRevision = -1;
  static const _pageSize = 50;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _load()); }
  @override
  void dispose() { _search.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final data = await context.read<AppStore>().db.withdrawals(
        query: _search.text.trim(),
        limit: _pageSize + 1,
        offset: reset ? 0 : _items.length,
      );
      final more = data.length > _pageSize;
      final page = data.take(_pageSize).toList();
      if (mounted) {
        setState(() {
          _items = reset ? page : [..._items, ...page];
          _hasMore = more;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _edit(Withdrawal item) async {
    final store = context.read<AppStore>();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .68,
        child: WithdrawalFormSheet(
          withdrawal: item,
          onSave: (amount, note) =>
              store.saveWithdrawal(id: item.id, amount: amount, note: note),
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(Withdrawal item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نقل السحب إلى المحذوفات؟'),
        content: const Text('يمكنك استعادته لاحقًا.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppStore>().deleteWithdrawal(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final revision = context.watch<AppStore>().revision;
    if (revision != _seenRevision) {
      _seenRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    final theme = Theme.of(context);
    final total = _items.fold<int>(0, (sum, item) => sum + item.amount);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السحبيات',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'سجل المصروف الشخصي',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.sage,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.mintSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _search,
                  onChanged: (value) {
                    _searchChanged(value);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث في ملاحظات السحب',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _search.clear();
                              _load();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.deficit.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.south_west_rounded,
                          size: 20,
                          color: AppTheme.deficit,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasMore ? 'إجمالي المعروض' : 'إجمالي النتائج',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.sage,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\${_items.length} عملية سحب',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.sage,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Text(
                          money(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.deficit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Colors.black38,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 14),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.mintSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.payments_outlined,
                size: 34,
                color: AppTheme.sage,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _search.text.trim().isEmpty
                  ? 'لا توجد سحبيات حتى الآن'
                  : 'لا توجد نتائج مطابقة',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _search.text.trim().isEmpty
                  ? 'أضف أول سحب من الزر أسفل الشاشة'
                  : 'جرّب عبارة بحث مختلفة',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.sage,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 128),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Center(
            child: FilledButton.tonalIcon(
              onPressed: _loadingMore ? null : () => _load(reset: false),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_loadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'),
            ),
          );
        }

        final item = _items[index];
        return _WithdrawalCard(
          withdrawal: item,
          onEdit: () => _edit(item),
          onDelete: () => _delete(item),
        );
      },
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({
    required this.withdrawal,
    required this.onEdit,
    required this.onDelete,
  });

  final Withdrawal withdrawal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        withdrawal.note.trim().isEmpty ? 'سحب نقدي' : withdrawal.note.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.mint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: AppTheme.sage,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  shortDateTime(withdrawal.createdAt),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.sage,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'خيارات السحب',
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppTheme.sage,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else {
                        onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.deficit,
                            ),
                            SizedBox(width: 10),
                            Text('حذف'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.deficit.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      'مبلغ السحب',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.sage,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '- \${money(withdrawal.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.deficit,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
