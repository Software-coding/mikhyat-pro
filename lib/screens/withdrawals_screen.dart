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
      builder: (_) => WithdrawalFormSheet(
        withdrawal: item,
        onSave: (amount, note) => store.saveWithdrawal(id: item.id, amount: amount, note: note),
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
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
    final total = _items.fold<int>(0, (s, e) => s + e.amount);
    return SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('السحبيات', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('المصروف الشخصي فقط'),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (value) {
              _searchChanged(value);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'بحث في الملاحظات',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        _load();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي النتائج', style: TextStyle(color: Colors.black54)), Text(money(total), style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.deficit))]),
        ]),
      ),
      Expanded(child: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? ListView(children: const [SizedBox(height: 180), Center(child: CircularProgressIndicator())])
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.black38),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: FilledButton.tonalIcon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                ? ListView(children: const [SizedBox(height: 100), Icon(Icons.payments_outlined, size: 50, color: Colors.black26), SizedBox(height: 12), Center(child: Text('لا توجد سحبيات'))])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == _items.length) {
                        return Center(child: FilledButton.tonalIcon(
                          onPressed: _loadingMore ? null : () => _load(reset: false),
                          icon: _loadingMore
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(_loadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'),
                        ));
                      }
                      final w = _items[i];
                      return Card(child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(child: Icon(Icons.payments_rounded)),
                        title: Text(w.note.isEmpty ? 'سحب نقدي' : w.note, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(shortDateTime(w.createdAt)),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('- ${money(w.amount)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.deficit)),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            onSelected: (v) => v == 'edit' ? _edit(w) : _delete(w),
                            itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))],
                          ),
                        ]),
                      ));
                    },
                  ),
      )),
    ]));
  }
}
