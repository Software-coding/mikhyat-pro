import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/piece.dart';
import '../models/withdrawal.dart';
import '../providers/app_store.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  List<Piece> _pieces = const [];
  List<Withdrawal> _withdrawals = const [];
  bool _loadingTrash = false;
  bool _busy = false;

  Future<void> _loadTrash() async {
    setState(() => _loadingTrash = true);
    try {
      final db = context.read<AppStore>().db;
      final results = await Future.wait<dynamic>([db.pieces(deleted: true), db.withdrawals(deleted: true)]);
      if (mounted) setState(() { _pieces = results[0] as List<Piece>; _withdrawals = results[1] as List<Withdrawal>; });
    } finally {
      if (mounted) setState(() => _loadingTrash = false);
    }
  }

  Future<void> _restorePiece(Piece p) async {
    await context.read<AppStore>().restorePiece(p.id);
    await _loadTrash();
  }

  Future<void> _restoreWithdrawal(Withdrawal w) async {
    await context.read<AppStore>().restoreWithdrawal(w.id);
    await _loadTrash();
  }

  Future<void> _permanentPiece(Piece p) async {
    final store = context.read<AppStore>();
    if (!await _confirmPermanent()) return;
    if (!mounted) return;
    await store.db.permanentlyDeletePiece(p.id);
    await store.refresh();
    if (!mounted) return;
    await _loadTrash();
  }

  Future<void> _permanentWithdrawal(Withdrawal w) async {
    final store = context.read<AppStore>();
    if (!await _confirmPermanent()) return;
    if (!mounted) return;
    await store.db.permanentlyDeleteWithdrawal(w.id);
    await store.refresh();
    if (!mounted) return;
    await _loadTrash();
  }

  Future<bool> _confirmPermanent() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف نهائي؟'),
        content: const Text('لن تتمكن من استعادة هذه العملية بعد الحذف النهائي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف نهائي')),
        ],
      ),
    ) ?? false;
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      await context.read<AppStore>().db.exportBackup();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز النسخة الاحتياطية')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء النسخة: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    final store = context.read<AppStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text('سيتم استبدال البيانات الحالية بمحتوى النسخة المختارة. سيحتفظ التطبيق بنسخة أمان من البيانات الحالية أولًا.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('متابعة'))],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final changed = await store.db.importBackup();
      if (changed) {
        await store.refresh();
        if (!mounted) return;
        await _loadTrash();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة البيانات بنجاح')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الاستعادة: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          Text('المزيد', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('حماية البيانات وإدارة المحذوفات'),
          const SizedBox(height: 20),
          Text('البيانات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Card(child: Column(children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.backup_rounded)),
              title: const Text('نسخة احتياطية', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('احفظ ملف قاعدة البيانات خارج التطبيق'),
              trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_left_rounded),
              onTap: _busy ? null : _exportBackup,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.restore_rounded)),
              title: const Text('استعادة نسخة', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('استرجع بياناتك من ملف mikhyat.db'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _busy ? null : _importBackup,
            ),
          ])),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: Text('سلة المحذوفات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.sage.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
              child: Text('${store.trashCount}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(onPressed: _loadingTrash ? null : _loadTrash, icon: const Icon(Icons.delete_sweep_outlined), label: Text(_loadingTrash ? 'جارٍ التحميل...' : 'عرض المحذوفات')),
          if (_pieces.isNotEmpty || _withdrawals.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._pieces.map((p) => Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.content_cut_rounded)),
              title: Text(p.description.isEmpty ? 'عمل خياطة' : p.description, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${shortDate(p.createdAt)} • ${money(p.total)}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => v == 'restore' ? _restorePiece(p) : _permanentPiece(p),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'restore', child: Text('استعادة')),
                  PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
                ],
              ),
            ))),
            ..._withdrawals.map((w) => Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.payments_rounded)),
              title: Text(w.note.isEmpty ? 'سحب نقدي' : w.note, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${shortDate(w.createdAt)} • ${money(w.amount)}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => v == 'restore' ? _restoreWithdrawal(w) : _permanentWithdrawal(w),
                itemBuilder: (_) => const [PopupMenuItem(value: 'restore', child: Text('استعادة')), PopupMenuItem(value: 'delete', child: Text('حذف نهائي'))],
              ),
            ))),
          ],
          const SizedBox(height: 22),
          const Card(child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مِخيط Pro • Flutter', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              SizedBox(height: 6),
              Text('يعمل محليًا على الهاتف بدون خادم وبدون حسابات وبدون سحابة. قاعدة البيانات SQLite داخل الجهاز.'),
            ]),
          )),
        ],
      ),
    );
  }
}
