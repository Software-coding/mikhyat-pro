import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/report_data.dart';
import '../providers/app_store.dart';
import '../services/pdf_service.dart';
import '../services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _pdf = PdfService();
  ReportKind _kind = ReportKind.combined;
  ReportData? _data;
  bool _loading = true;
  bool _exporting = false;
  int _weekOffset = 0;
  int _monthOffset = 0;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final b = ReportService.weekBounds();
    _start = b.start;
    _end = b.end;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _title => switch (_kind) {
    ReportKind.pieces => 'تقرير الأعمال المنجزة',
    ReportKind.withdrawals => 'تقرير السحبيات',
    ReportKind.combined => 'التقرير المالي الشامل',
    ReportKind.weekly => 'ملخص الأسبوع',
    ReportKind.monthly => 'ملخص الشهر',
  };

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = context.read<AppStore>().reports;
      final data = switch (_kind) {
        ReportKind.weekly => await service.week(offset: _weekOffset),
        ReportKind.monthly => await service.month(offset: _monthOffset),
        _ => await service.range(_start, _end),
      };
      if (mounted) setState(() => _data = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeKind(ReportKind kind) {
    setState(() => _kind = kind);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: 'اختر فترة التقرير',
      saveText: 'اعتماد',
    );
    if (picked == null) return;
    setState(() { _start = picked.start; _end = picked.end; });
    await _load();
  }

  Future<void> _sharePdf() async {
    if (_data == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await _pdf.share(_kind, _data!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء PDF: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _printPdf() async {
    if (_data == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await _pdf.printReport(_kind, _data!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الطباعة: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مركز التقارير', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const Text('خمسة تقارير — كل واحد له PDF مستقل'),
            ])),
            IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          ]),
        ),
        SizedBox(
          height: 54,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            children: [
              _TypeChip(label: 'الأعمال', icon: Icons.content_cut_rounded, selected: _kind == ReportKind.pieces, onTap: () => _changeKind(ReportKind.pieces)),
              _TypeChip(label: 'السحبيات', icon: Icons.payments_rounded, selected: _kind == ReportKind.withdrawals, onTap: () => _changeKind(ReportKind.withdrawals)),
              _TypeChip(label: 'الشامل', icon: Icons.account_balance_wallet_rounded, selected: _kind == ReportKind.combined, onTap: () => _changeKind(ReportKind.combined)),
              _TypeChip(label: 'الأسبوع', icon: Icons.date_range_rounded, selected: _kind == ReportKind.weekly, onTap: () => _changeKind(ReportKind.weekly)),
              _TypeChip(label: 'الشهر', icon: Icons.calendar_month_rounded, selected: _kind == ReportKind.monthly, onTap: () => _changeKind(ReportKind.monthly)),
            ],
          ),
        ),
        Expanded(
          child: _loading && _data == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
                    children: [
                      _PeriodControls(
                        kind: _kind,
                        data: _data,
                        start: _start,
                        end: _end,
                        onPickRange: _pickRange,
                        onPrevious: () {
                          if (_kind == ReportKind.weekly) {
                            _weekOffset--;
                          } else if (_kind == ReportKind.monthly) {
                            _monthOffset--;
                          }
                          _load();
                        },
                        onNext: () {
                          if (_kind == ReportKind.weekly) {
                            _weekOffset++;
                          } else if (_kind == ReportKind.monthly) {
                            _monthOffset++;
                          }
                          _load();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_data != null) ...[
                        _ReportHero(title: _title, kind: _kind, data: _data!),
                        const SizedBox(height: 12),
                        _ReportMetrics(kind: _kind, data: _data!),
                        if (_kind != ReportKind.withdrawals && _data!.topModifications.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _TopModifications(data: _data!),
                        ],
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(child: FilledButton.icon(
                            onPressed: _exporting ? null : _sharePdf,
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: Text(_exporting ? 'جارٍ التجهيز...' : 'تصدير PDF'),
                          )),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(onPressed: _exporting ? null : _printPdf, icon: const Icon(Icons.print_rounded), tooltip: 'طباعة'),
                        ]),
                        const SizedBox(height: 22),
                        if (_kind == ReportKind.weekly) _DailyBreakdown(data: _data!),
                        if (_kind == ReportKind.monthly) _WeeklyBreakdown(data: _data!),
                        if (_kind != ReportKind.withdrawals) _PiecesBreakdown(data: _data!),
                        if (_kind != ReportKind.pieces) _WithdrawalsBreakdown(data: _data!),
                      ],
                    ],
                  ),
                ),
        ),
      ]),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: ChoiceChip(avatar: Icon(icon, size: 18), label: Text(label), selected: selected, onSelected: (_) => onTap()),
  );
}

class _PeriodControls extends StatelessWidget {
  const _PeriodControls({required this.kind, required this.data, required this.start, required this.end, required this.onPickRange, required this.onPrevious, required this.onNext});
  final ReportKind kind;
  final ReportData? data;
  final DateTime start;
  final DateTime end;
  final VoidCallback onPickRange;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final isFixed = kind == ReportKind.weekly || kind == ReportKind.monthly;
    final shownStart = data?.start ?? start;
    final shownEnd = data?.end ?? end;
    if (!isFixed) {
      return Card(child: ListTile(
        onTap: onPickRange,
        leading: const Icon(Icons.calendar_today_rounded),
        title: const Text('الفترة', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${shortDate(shownStart)} — ${shortDate(shownEnd)}'),
        trailing: const Icon(Icons.chevron_left_rounded),
      ));
    }
    return Card(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_right_rounded)),
        Expanded(child: Column(children: [
          Text(kind == ReportKind.weekly ? 'الأسبوع' : 'الشهر', style: const TextStyle(color: Colors.black54)),
          Text('${shortDate(shownStart)} — ${shortDate(shownEnd)}', style: const TextStyle(fontWeight: FontWeight.w900)),
        ])),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_left_rounded)),
      ]),
    ));
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.title, required this.kind, required this.data});
  final String title;
  final ReportKind kind;
  final ReportData data;
  @override
  Widget build(BuildContext context) {
    final color = switch (data.status) { FinancialStatus.profit => AppTheme.profit, FinancialStatus.deficit => AppTheme.deficit, FinancialStatus.balanced => AppTheme.balanced };
    final status = switch (data.status) { FinancialStatus.profit => 'ربح', FinancialStatus.deficit => 'عجز', FinancialStatus.balanced => 'متعادل' };
    final value = kind == ReportKind.pieces ? data.revenue : kind == ReportKind.withdrawals ? data.expenses : data.net;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.ink, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(money(value.abs()), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        if (kind != ReportKind.pieces && kind != ReportKind.withdrawals) ...[
          const SizedBox(height: 8),
          Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text('الصافي: $status', style: const TextStyle(color: Colors.white70))]),
        ],
      ]),
    );
  }
}

class _ReportMetrics extends StatelessWidget {
  const _ReportMetrics({required this.kind, required this.data});
  final ReportKind kind;
  final ReportData data;
  @override
  Widget build(BuildContext context) {
    final items = kind == ReportKind.pieces
        ? [('القطع', '${data.pieceCount}'), ('العمليات', '${data.jobsCount}'), ('متوسط القطعة', money(data.averagePerPiece)), ('أعلى عملية', money(data.highestPiece))]
        : kind == ReportKind.withdrawals
            ? [('عدد السحبيات', '${data.withdrawalCount}'), ('الإجمالي', money(data.expenses)), ('المتوسط', money(data.averageWithdrawal)), ('أعلى سحب', money(data.highestWithdrawal))]
            : [('القطع', '${data.pieceCount}'), ('الإيرادات', money(data.revenue)), ('السحبيات', money(data.expenses)), ('الصافي', money(data.net))];
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.9),
      itemCount: items.length,
      itemBuilder: (_, i) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(items[i].$1, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 4), Text(items[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]))),
    );
  }
}


class _TopModifications extends StatelessWidget {
  const _TopModifications({required this.data});
  final ReportData data;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('أكثر التعديلات استخدامًا', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.topModifications.map((m) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.sage.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
              child: Text('${m.name} • ${m.count} قطعة • ${money(m.revenue)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            )).toList(),
          ),
        ]),
      ),
    );
  }
}

class _DailyBreakdown extends StatelessWidget {
  const _DailyBreakdown({required this.data});
  final ReportData data;
  @override
  Widget build(BuildContext context) => _Section(
    title: 'الأداء اليومي',
    child: Column(children: data.daily.map((d) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(shortDate(d.date), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${d.pieces} قطعة • ${d.jobs} عملية'),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('+ ${money(d.revenue)}', style: const TextStyle(color: AppTheme.profit, fontWeight: FontWeight.w700)), Text('- ${money(d.expenses)}', style: const TextStyle(color: AppTheme.deficit, fontWeight: FontWeight.w700))]),
    )).toList()),
  );
}

class _WeeklyBreakdown extends StatelessWidget {
  const _WeeklyBreakdown({required this.data});
  final ReportData data;
  @override
  Widget build(BuildContext context) {
    final weeks = ReportService.aggregateWeeks(data);
    return _Section(
      title: 'الشهر حسب الأسابيع',
      child: Column(children: weeks.map((d) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('من ${shortDate(d.date)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${d.pieces} قطعة • ${d.jobs} عملية'),
        trailing: Text(money(d.net), style: TextStyle(fontWeight: FontWeight.w900, color: d.net > 0 ? AppTheme.profit : d.net < 0 ? AppTheme.deficit : AppTheme.balanced)),
      )).toList()),
    );
  }
}

class _PiecesBreakdown extends StatelessWidget {
  const _PiecesBreakdown({required this.data});
  final ReportData data;
  @override
  Widget build(BuildContext context) => _Section(
    title: 'الأعمال المنجزة بالتفصيل',
    child: data.pieces.isEmpty
        ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('لا توجد أعمال في هذه الفترة')))
        : Column(children: data.pieces.map((p) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p.description.isEmpty ? 'عمل خياطة' : p.description, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${shortDate(p.createdAt)} • ${p.quantity} قطعة${p.modifications.isEmpty ? '' : ' • ${p.modifications.map((m) => m.name).join('، ')}'}'),
          trailing: Text(money(p.total), style: const TextStyle(fontWeight: FontWeight.w900)),
        )).toList()),
  );
}

class _WithdrawalsBreakdown extends StatelessWidget {
  const _WithdrawalsBreakdown({required this.data});
  final ReportData data;
  @override
  Widget build(BuildContext context) => _Section(
    title: 'السحبيات بالتفصيل',
    child: data.withdrawals.isEmpty
        ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('لا توجد سحبيات في هذه الفترة')))
        : Column(children: data.withdrawals.map((w) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(w.note.isEmpty ? 'سحب نقدي' : w.note, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(shortDate(w.createdAt)),
          trailing: Text('- ${money(w.amount)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.deficit)),
        )).toList()),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 8), child]))),
  );
}
