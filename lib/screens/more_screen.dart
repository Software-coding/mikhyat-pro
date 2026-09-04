import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../models/piece.dart';
import '../models/withdrawal.dart';
import '../providers/app_store.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  List<Customer> _customers = const [];
  List<Piece> _pieces = const [];
  List<Withdrawal> _withdrawals = const [];
  bool _loadingTrash = false;
  bool _busy = false;

  Future<void> _loadTrash() async {
    setState(() => _loadingTrash = true);
    try {
      final db = context.read<AppStore>().db;
      final results = await Future.wait<dynamic>([
        db.customers(deleted: true),
        db.pieces(deleted: true),
        db.withdrawals(deleted: true),
      ]);

      if (mounted) {
        setState(() {
          _customers = results[0] as List<Customer>;
          _pieces = results[1] as List<Piece>;
          _withdrawals = results[2] as List<Withdrawal>;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingTrash = false);
    }
  }

  Future<void> _restoreCustomer(Customer customer) async {
    await context.read<AppStore>().restoreCustomer(customer.id);
    await _loadTrash();
  }

  Future<void> _restorePiece(Piece piece) async {
    await context.read<AppStore>().restorePiece(piece.id);
    await _loadTrash();
  }

  Future<void> _restoreWithdrawal(Withdrawal withdrawal) async {
    await context.read<AppStore>().restoreWithdrawal(withdrawal.id);
    await _loadTrash();
  }

  Future<void> _permanentPiece(Piece piece) async {
    final store = context.read<AppStore>();
    if (!await _confirmPermanent()) return;
    if (!mounted) return;

    await store.db.permanentlyDeletePiece(piece.id);
    await store.refresh();

    if (!mounted) return;
    await _loadTrash();
  }

  Future<void> _permanentWithdrawal(Withdrawal withdrawal) async {
    final store = context.read<AppStore>();
    if (!await _confirmPermanent()) return;
    if (!mounted) return;

    await store.db.permanentlyDeleteWithdrawal(withdrawal.id);
    await store.refresh();

    if (!mounted) return;
    await _loadTrash();
  }

  Future<bool> _confirmPermanent() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.deficit,
            ),
            title: const Text('حذف نهائي؟'),
            content: const Text(
              'لن تتمكن من استعادة هذه العملية بعد الحذف النهائي.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف نهائي'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      await context.read<AppStore>().db.exportBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تجهيز النسخة الاحتياطية')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء النسخة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    final store = context.read<AppStore>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.restore_rounded),
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text(
          'سيتم استبدال البيانات الحالية بمحتوى النسخة المختارة، '
          'وسيحتفظ التطبيق بنسخة أمان من بياناتك الحالية أولًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('متابعة'),
          ),
        ],
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت استعادة البيانات بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الاستعادة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          _Header(theme: theme),
          const SizedBox(height: 26),

          const _SectionTitle(
            icon: Icons.shield_outlined,
            title: 'حماية البيانات',
            subtitle: 'نسخ بياناتك واستعادتها بأمان',
          ),
          const SizedBox(height: 12),

          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.cloud_upload_rounded,
                iconBackground: AppTheme.mintSoft,
                title: 'نسخة احتياطية',
                subtitle: 'احفظ نسخة من بياناتك خارج التطبيق',
                trailing: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _busy ? null : _exportBackup,
              ),
              const _GroupDivider(),
              _SettingsTile(
                icon: Icons.history_rounded,
                iconBackground: const Color(0xFFEAF0FF),
                title: 'استعادة نسخة',
                subtitle: 'استرجع بياناتك من نسخة محفوظة سابقًا',
                onTap: _busy ? null : _importBackup,
              ),
            ],
          ),

          const SizedBox(height: 28),

          _SectionTitle(
            icon: Icons.inventory_2_outlined,
            title: 'المحذوفات والأرشيف',
            subtitle: 'استعادة العناصر المحذوفة والمؤرشفة',
            badge: store.trashCount,
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _loadingTrash ? null : _loadTrash,
              icon: _loadingTrash
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              label: Text(
                _loadingTrash
                    ? 'جارٍ التحميل...'
                    : 'عرض المحذوفات والأرشيف',
              ),
            ),
          ),

          if (_customers.isNotEmpty ||
              _pieces.isNotEmpty ||
              _withdrawals.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ArchiveGroup(
              customers: _customers,
              pieces: _pieces,
              withdrawals: _withdrawals,
              onRestoreCustomer: _restoreCustomer,
              onRestorePiece: _restorePiece,
              onRestoreWithdrawal: _restoreWithdrawal,
              onDeletePiece: _permanentPiece,
              onDeleteWithdrawal: _permanentWithdrawal,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الإعدادات',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'إدارة بيانات التطبيق وخيارات الاستعادة',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.sage,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.mintSoft,
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: AppTheme.ink,
            size: 26,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.sage.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: AppTheme.sage,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.sage,
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: badge == 0
                  ? AppTheme.sage.withValues(alpha: .10)
                  : AppTheme.deficit.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$badge',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: badge == 0 ? AppTheme.sage : AppTheme.deficit,
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.ink,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.sage,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.cream,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: AppTheme.sage,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.line,
      ),
    );
  }
}

class _ArchiveGroup extends StatelessWidget {
  const _ArchiveGroup({
    required this.customers,
    required this.pieces,
    required this.withdrawals,
    required this.onRestoreCustomer,
    required this.onRestorePiece,
    required this.onRestoreWithdrawal,
    required this.onDeletePiece,
    required this.onDeleteWithdrawal,
  });

  final List<Customer> customers;
  final List<Piece> pieces;
  final List<Withdrawal> withdrawals;
  final Future<void> Function(Customer) onRestoreCustomer;
  final Future<void> Function(Piece) onRestorePiece;
  final Future<void> Function(Withdrawal) onRestoreWithdrawal;
  final Future<void> Function(Piece) onDeletePiece;
  final Future<void> Function(Withdrawal) onDeleteWithdrawal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...customers.map(
          (customer) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ArchiveCard(
              icon: Icons.person_outline_rounded,
              title: customer.name,
              subtitle: customer.phone.isEmpty
                  ? 'عميل مؤرشف'
                  : '${customer.phone} • عميل مؤرشف',
              onRestore: () => onRestoreCustomer(customer),
            ),
          ),
        ),
        ...pieces.map(
          (piece) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ArchiveCard(
              icon: Icons.content_cut_rounded,
              title: piece.description.isEmpty
                  ? 'عمل خياطة'
                  : piece.description,
              subtitle:
                  '${shortDate(piece.createdAt)} • ${money(piece.total)}',
              onRestore: () => onRestorePiece(piece),
              onDelete: () => onDeletePiece(piece),
            ),
          ),
        ),
        ...withdrawals.map(
          (withdrawal) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ArchiveCard(
              icon: Icons.payments_rounded,
              title: withdrawal.note.isEmpty
                  ? 'سحب نقدي'
                  : withdrawal.note,
              subtitle:
                  '${shortDate(withdrawal.createdAt)} • ${money(withdrawal.amount)}',
              onRestore: () => onRestoreWithdrawal(withdrawal),
              onDelete: () => onDeleteWithdrawal(withdrawal),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRestore,
    this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.mintSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: AppTheme.ink,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onDelete == null)
            IconButton(
              tooltip: 'استعادة',
              onPressed: onRestore,
              icon: const Icon(Icons.restore_rounded),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'خيارات',
              onSelected: (value) {
                if (value == 'restore') {
                  onRestore();
                } else {
                  onDelete?.call();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(Icons.restore_rounded),
                      SizedBox(width: 10),
                      Text('استعادة'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever_outlined,
                        color: AppTheme.deficit,
                      ),
                      SizedBox(width: 10),
                      Text('حذف نهائي'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
