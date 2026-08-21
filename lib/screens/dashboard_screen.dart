import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/report_data.dart';
import '../providers/app_store.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: store.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('مِخيط Pro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.ink)),
                const Text('إدارة أعمالك ببساطة ووضوح'),
              ])),
              IconButton.filledTonal(onPressed: store.refresh, icon: const Icon(Icons.refresh_rounded)),
            ]),
            const SizedBox(height: 22),
            if (store.loading && store.currentWeek == null)
              const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator()))
            else if (store.error != null)
              _ErrorCard(error: store.error!, retry: store.refresh)
            else if (store.currentWeek != null) ...[
              _WeekHero(report: store.currentWeek!),
              const SizedBox(height: 14),
              _MetricsGrid(report: store.currentWeek!),
              const SizedBox(height: 22),
              Text('الأسبوع يومًا بيوم', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _DailyStrip(report: store.currentWeek!),
              const SizedBox(height: 22),
              Text('منذ بداية الاستخدام', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _SmallCard(label: 'كل القطع', value: '${store.totals['pieces'] ?? 0}')),
                const SizedBox(width: 10),
                Expanded(child: _SmallCard(label: 'كل الإيرادات', value: money(store.totals['revenue'] ?? 0))),
              ]),
              const SizedBox(height: 22),
              _RecentSection(store: store),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.report});
  final ReportData report;
  Color get color => switch (report.status) { FinancialStatus.profit => AppTheme.profit, FinancialStatus.deficit => AppTheme.deficit, FinancialStatus.balanced => AppTheme.balanced };
  String get label => switch (report.status) { FinancialStatus.profit => 'ربح هذا الأسبوع', FinancialStatus.deficit => 'عجز هذا الأسبوع', FinancialStatus.balanced => 'الأسبوع متعادل' };
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF26352F), Color(0xFF52685E)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${shortDate(report.start)} — ${shortDate(report.end)}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 14),
        Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(money(report.net.abs()), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(.3), borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.report});
  final ReportData report;
  @override
  Widget build(BuildContext context) {
    final items = [
      ('القطع', '${report.pieceCount}', Icons.content_cut_rounded),
      ('الإيرادات', money(report.revenue), Icons.trending_up_rounded),
      ('السحبيات', money(report.expenses), Icons.trending_down_rounded),
      ('متوسط القطعة', money(report.averagePerPiece), Icons.calculate_rounded),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: items.map((e) => SizedBox(width: width, child: Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(e.$3, color: AppTheme.sage),
          const SizedBox(height: 12),
          Text(e.$1, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 3),
          Text(e.$2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      )))).toList());
    });
  }
}

class _DailyStrip extends StatelessWidget {
  const _DailyStrip({required this.report});
  final ReportData report;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: report.daily.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = report.daily[i];
          return Container(
            width: 118,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(shortDate(d.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('+ ${money(d.revenue)}', style: const TextStyle(color: AppTheme.profit, fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('- ${money(d.expenses)}', style: const TextStyle(color: AppTheme.deficit, fontSize: 11, fontWeight: FontWeight.w800)),
              const Divider(),
              Text(money(d.net), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
          );
        },
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 5), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))])));
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('آخر العمليات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      if (store.recentPieces.isEmpty && store.recentWithdrawals.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(22), child: Center(child: Text('ابدأ بإضافة أول عمل أو سحب.'))))
      else ...[
        ...store.recentPieces.take(4).map((p) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const CircleAvatar(child: Icon(Icons.content_cut_rounded)),
          title: Text(p.description.isEmpty ? 'عمل خياطة' : p.description, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${shortDate(p.createdAt)} • ${p.quantity} قطعة'),
          trailing: Text(money(p.total), style: const TextStyle(fontWeight: FontWeight.w900)),
        )),
        ...store.recentWithdrawals.take(3).map((w) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const CircleAvatar(child: Icon(Icons.payments_rounded)),
          title: Text(w.note.isEmpty ? 'سحب نقدي' : w.note, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(shortDate(w.createdAt)),
          trailing: Text('- ${money(w.amount)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.deficit)),
        )),
      ],
    ]);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.retry});
  final String error;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Icon(Icons.error_outline_rounded, size: 40), const SizedBox(height: 10), Text(error, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: retry, child: const Text('إعادة المحاولة'))])));
}
