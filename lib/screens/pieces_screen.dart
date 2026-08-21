import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/piece.dart';
import '../providers/app_store.dart';
import '../widgets/piece_form_sheet.dart';

class PiecesScreen extends StatefulWidget {
  const PiecesScreen({super.key});
  @override
  State<PiecesScreen> createState() => _PiecesScreenState();
}

class _PiecesScreenState extends State<PiecesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Piece> _items = const [];
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
      setState(() { _loading = true; _error = null; });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final data = await context.read<AppStore>().db.pieces(
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

  Future<void> _edit(Piece piece) async {
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
          child: PieceFormSheet(
            piece: piece,
            onSave: (description, quantity, basePrice, mods) => store.savePiece(
              id: piece.id,
              description: description,
              quantity: quantity,
              basePrice: basePrice,
              modifications: mods,
            ),
          ),
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(Piece piece) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نقل إلى سلة المحذوفات؟'),
        content: const Text('يمكنك استعادة العملية لاحقًا من قسم المزيد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppStore>().deletePiece(piece.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final revision = context.watch<AppStore>().revision;
    if (revision != _seenRevision) {
      _seenRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الأعمال المنجزة', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('سجل القطع والتعديلات والأسعار'),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: _searchChanged,
              decoration: InputDecoration(
                hintText: 'بحث بالوصف أو اسم التعديل',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); _load(); setState(() {}); }, icon: const Icon(Icons.close_rounded)),
              ),
            ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading && _items.isEmpty
                ? const ListView(children: [SizedBox(height: 180), Center(child: CircularProgressIndicator())])
                : _error != null
                    ? ListView(children: [Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center))])
                    : _items.isEmpty
                        ? ListView(children: const [SizedBox(height: 100), Icon(Icons.content_cut_rounded, size: 50, color: Colors.black26), SizedBox(height: 12), Center(child: Text('لا توجد أعمال حتى الآن'))])
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
                              return _PieceCard(piece: _items[i], onEdit: () => _edit(_items[i]), onDelete: () => _delete(_items[i]));
                            },
                          ),
          ),
        ),
      ]),
    );
  }
}

class _PieceCard extends StatelessWidget {
  const _PieceCard({required this.piece, required this.onEdit, required this.onDelete});
  final Piece piece;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final revision = context.watch<AppStore>().revision;
    if (revision != _seenRevision) {
      _seenRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(piece.description.isEmpty ? 'عمل خياطة' : piece.description, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 3),
              Text('${shortDateTime(piece.createdAt)} • ${piece.quantity} قطعة', style: const TextStyle(color: Colors.black54)),
            ])),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('تعديل'))),
                PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline, color: AppTheme.deficit), title: Text('حذف'))),
              ],
            ),
          ]),
          if (piece.modifications.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: piece.modifications.map((m) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: AppTheme.sage.withOpacity(.09), borderRadius: BorderRadius.circular(99)),
                child: Text('${m.name} • ${money(m.pricePerPiece)} × ${m.appliedQuantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              )).toList(),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(piece.hasModifications ? 'من أسعار التعديلات' : '${money(piece.basePrice)} × ${piece.quantity}', style: const TextStyle(color: Colors.black54)),
            Text(money(piece.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: AppTheme.ink)),
          ]),
        ]),
      ),
    );
  }
}
