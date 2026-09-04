import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../providers/app_store.dart';
import '../widgets/customer_form_sheet.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Customer> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  int _seenRevision = -1;
  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

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
      final data = await context.read<AppStore>().db.customers(
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
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _edit(Customer customer) async {
    final store = context.read<AppStore>();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .96,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: CustomerFormSheet(
            customer: customer,
            onSave: (
              name,
              phone,
              notes,
              shoulder,
              chest,
              waist,
              hips,
              sleeveLength,
              garmentLength,
            ) =>
                store.saveCustomer(
              id: customer.id,
              name: name,
              phone: phone,
              notes: notes,
              shoulder: shoulder,
              chest: chest,
              waist: waist,
              hips: hips,
              sleeveLength: sleeveLength,
              garmentLength: garmentLength,
            ),
          ),
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _archive(Customer customer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أرشفة العميل؟'),
        content: Text(
          'سيختفي ${customer.name} من قائمة العملاء، وستبقى الأعمال السابقة محفوظة ومرتبطة باسمه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('أرشفة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppStore>().archiveCustomer(customer.id);
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

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'العملاء والمقاسات',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                const Text('احفظ بيانات العميل ومقاساته واربطها بكل عمل'),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (value) {
                    _searchChanged(value);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الهاتف أو الملاحظات',
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
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
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
      );
    }

    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Icon(Icons.people_outline_rounded, size: 54, color: Colors.black26),
          SizedBox(height: 12),
          Center(child: Text('لا يوجد عملاء حتى الآن')),
          SizedBox(height: 4),
          Center(child: Text('أضف أول عميل ثم احفظ مقاساته')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == _items.length) {
          return Center(
            child: FilledButton.tonalIcon(
              onPressed: _loadingMore ? null : () => _load(reset: false),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_loadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'),
            ),
          );
        }

        final customer = _items[index];
        return _CustomerCard(
          customer: customer,
          onEdit: () => _edit(customer),
          onArchive: () => _archive(customer),
        );
      },
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onArchive,
  });

  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.sage.withValues(alpha: .14),
                  foregroundColor: AppTheme.ink,
                  child: Text(
                    customer.name.trim().isEmpty ? '؟' : customer.name.trim()[0],
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      if (customer.phone.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          customer.phone,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onArchive(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('تعديل'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.archive_outlined),
                        title: Text('أرشفة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (customer.hasMeasurements) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: customer.measurements.entries
                    .map(
                      (entry) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.sage.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${entry.key}: ${_measurement(entry.value)} سم',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (customer.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                customer.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _measurement(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}
