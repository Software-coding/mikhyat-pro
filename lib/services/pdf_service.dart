import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../core/formatters.dart';
import '../models/report_data.dart';
import 'report_service.dart';

enum ReportKind { pieces, withdrawals, combined, weekly, monthly }

class PdfService {
  Future<pw.Font> _arabicFont() async {
    if (Platform.isAndroid) {
      const candidates = <String>[
        '/system/fonts/NotoNaskhArabic-Regular.ttf',
        '/system/fonts/NotoSansArabic-Regular.ttf',
        '/system/fonts/NotoSansArabicUI-Regular.ttf',
        '/system/fonts/NotoSansArabic-VF.ttf',
        '/system/fonts/DroidSansFallback.ttf',
      ];
      for (final path in candidates) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return pw.Font.ttf(ByteData.sublistView(bytes));
        }
      }
    }
    // محاولة عامة لأي خط عربي موجود في Android دون إنترنت.
    if (Platform.isAndroid) {
      final fontsDir = Directory('/system/fonts');
      if (await fontsDir.exists()) {
        await for (final entity in fontsDir.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path).toLowerCase();
          final isFont = name.endsWith('.ttf') || name.endsWith('.otf');
          final looksArabic = name.contains('arabic') || name.contains('naskh') || name.contains('kufi');
          if (!isFont || !looksArabic) continue;
          try {
            final bytes = await entity.readAsBytes();
            return pw.Font.ttf(ByteData.sublistView(bytes));
          } catch (_) {
            // نجرب الخط التالي.
          }
        }
      }
    }
    throw StateError('لم يتم العثور على خط عربي محلي مناسب لإنشاء PDF على هذا الجهاز.');
  }

  String _title(ReportKind kind) => switch (kind) {
        ReportKind.pieces => 'تقرير الأعمال المنجزة',
        ReportKind.withdrawals => 'تقرير السحبيات',
        ReportKind.combined => 'التقرير المالي الشامل',
        ReportKind.weekly => 'ملخص الأسبوع',
        ReportKind.monthly => 'ملخص الشهر',
      };

  String _statusLabel(ReportData r) => switch (r.status) {
        FinancialStatus.profit => 'ربح',
        FinancialStatus.deficit => 'عجز',
        FinancialStatus.balanced => 'متعادل',
      };

  Future<File> generate(ReportKind kind, ReportData r) async {
    final font = await _arabicFont();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
      title: _title(kind),
      author: 'مِخيط Pro',
      subject: 'تقرير محلي لأعمال الخياطة',
    );

    final header = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_title(kind), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold), textDirection: pw.TextDirection.rtl),
            pw.SizedBox(height: 3),
            pw.Text('${shortDate(r.start)} — ${shortDate(r.end)}', style: const pw.TextStyle(fontSize: 10), textDirection: pw.TextDirection.rtl),
          ]),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Text('مِخيط Pro', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold), textDirection: pw.TextDirection.rtl),
          ),
        ],
      ),
      pw.SizedBox(height: 14),
      _summaryCards(kind, r),
      if (kind != ReportKind.withdrawals && r.topModifications.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _topModifications(r),
      ],
      pw.SizedBox(height: 14),
    ];

    final body = <pw.Widget>[];
    if (kind == ReportKind.weekly) {
      body.addAll([_sectionTitle('الأداء اليومي'), _dailyTable(r.daily), pw.SizedBox(height: 14)]);
    }
    if (kind == ReportKind.monthly) {
      body.addAll([_sectionTitle('أداء الشهر حسب الأسابيع'), _weeklyTable(r), pw.SizedBox(height: 14)]);
    }
    if (kind != ReportKind.withdrawals) {
      body.addAll([_sectionTitle('الأعمال المنجزة بالتفصيل'), _piecesTable(r), pw.SizedBox(height: 14)]);
    }
    if (kind != ReportKind.pieces) {
      body.addAll([_sectionTitle('السحبيات بالتفصيل'), _withdrawalsTable(r), pw.SizedBox(height: 14)]);
    }
    if (kind == ReportKind.combined || kind == ReportKind.weekly || kind == ReportKind.monthly) {
      body.add(_accountingCheck(r));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        header: (_) => pw.SizedBox.shrink(),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('تم إنشاء التقرير من مِخيط Pro', style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl),
            pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl),
          ]),
        ),
        build: (_) => [...header, ...body],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final reports = Directory(p.join(dir.path, 'reports'));
    await reports.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File(p.join(reports.path, '${_fileName(kind)}_$stamp.pdf'));
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  Future<void> share(ReportKind kind, ReportData report) async {
    final file = await generate(kind, report);
    await Share.shareXFiles([XFile(file.path)], subject: _title(kind));
  }

  Future<void> printReport(ReportKind kind, ReportData report) async {
    final file = await generate(kind, report);
    await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
  }

  String _fileName(ReportKind kind) => switch (kind) {
        ReportKind.pieces => 'mikhyat_pieces',
        ReportKind.withdrawals => 'mikhyat_withdrawals',
        ReportKind.combined => 'mikhyat_financial',
        ReportKind.weekly => 'mikhyat_weekly',
        ReportKind.monthly => 'mikhyat_monthly',
      };

  pw.Widget _summaryCards(ReportKind kind, ReportData r) {
    final cells = switch (kind) {
      ReportKind.pieces => [
          ('عدد القطع', '${r.pieceCount}'),
          ('عدد العمليات', '${r.jobsCount}'),
          ('إجمالي الأعمال', money(r.revenue)),
          ('متوسط القطعة', money(r.averagePerPiece)),
        ],
      ReportKind.withdrawals => [
          ('عدد السحبيات', '${r.withdrawalCount}'),
          ('إجمالي السحبيات', money(r.expenses)),
          ('متوسط السحب', money(r.averageWithdrawal)),
          ('أعلى سحب', money(r.highestWithdrawal)),
        ],
      _ => [
          ('عدد القطع', '${r.pieceCount}'),
          ('الإيرادات', money(r.revenue)),
          ('السحبيات', money(r.expenses)),
          ('الصافي — ${_statusLabel(r)}', money(r.net)),
        ],
    };
    return pw.Row(
      children: cells.map((e) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(e.$1, style: const pw.TextStyle(fontSize: 9), textDirection: pw.TextDirection.rtl),
            pw.SizedBox(height: 4),
            pw.Text(e.$2, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold), textDirection: pw.TextDirection.rtl),
          ]),
        ),
      )).toList(),
    );
  }


  pw.Widget _topModifications(ReportData r) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('أكثر التعديلات استخدامًا', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textDirection: pw.TextDirection.rtl),
        pw.SizedBox(height: 5),
        pw.Wrap(
          spacing: 6,
          runSpacing: 4,
          children: r.topModifications.map((m) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(5)),
            child: pw.Text('${m.name} • ${m.count} قطعة • ${money(m.revenue)}', style: const pw.TextStyle(fontSize: 7), textDirection: pw.TextDirection.rtl),
          )).toList(),
        ),
      ]),
    );
  }

  pw.Widget _sectionTitle(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), textDirection: pw.TextDirection.rtl),
      );

  pw.Widget _piecesTable(ReportData r) {
    final data = <List<String>>[
      ['#', 'التاريخ', 'العميل', 'الوصف', 'العدد', 'السعر العادي', 'التعديلات — السعر × العدد', 'الإجمالي'],
      ...r.pieces.asMap().entries.map((entry) {
        final p = entry.value;
        final mods = p.modifications.isEmpty
            ? 'بدون تعديلات'
            : p.modifications.map((m) => '${m.name}: ${money(m.pricePerPiece)} × ${m.appliedQuantity} = ${money(m.subtotal)}').join('\n');
        return [
          '${entry.key + 1}',
          shortDate(p.createdAt),
          p.customerName ?? '—',
          p.description.isEmpty ? 'قطعة خياطة' : p.description,
          '${p.quantity}',
          p.modifications.isEmpty ? money(p.basePrice) : '—',
          mods,
          money(p.total),
        ];
      }),
    ];
    return pw.TableHelper.fromTextArray(
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headerDirection: pw.TextDirection.rtl,
      tableDirection: pw.TextDirection.rtl,
      cellPadding: const pw.EdgeInsets.all(5),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
    );
  }

  pw.Widget _withdrawalsTable(ReportData r) {
    final data = <List<String>>[
      ['#', 'التاريخ', 'المبلغ', 'الملاحظة'],
      ...r.withdrawals.asMap().entries.map((entry) => [
        '${entry.key + 1}', shortDate(entry.value.createdAt), money(entry.value.amount), entry.value.note.isEmpty ? 'سحب نقدي' : entry.value.note,
      ]),
    ];
    return pw.TableHelper.fromTextArray(
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headerDirection: pw.TextDirection.rtl,
      tableDirection: pw.TextDirection.rtl,
      cellPadding: const pw.EdgeInsets.all(5),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
    );
  }

  pw.Widget _dailyTable(List<DailySummary> rows) => pw.TableHelper.fromTextArray(
        data: [
          ['اليوم', 'القطع', 'العمليات', 'الإيرادات', 'السحبيات', 'الصافي'],
          ...rows.map((d) => [shortDate(d.date), '${d.pieces}', '${d.jobs}', money(d.revenue), money(d.expenses), money(d.net)]),
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignment: pw.Alignment.centerRight,
        headerAlignment: pw.Alignment.centerRight,
        headerDirection: pw.TextDirection.rtl,
        tableDirection: pw.TextDirection.rtl,
        cellPadding: const pw.EdgeInsets.all(5),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
      );

  pw.Widget _weeklyTable(ReportData r) {
    final weeks = ReportService.aggregateWeeks(r);
    return pw.TableHelper.fromTextArray(
      data: [
        ['بداية الفترة', 'القطع', 'العمليات', 'الإيرادات', 'السحبيات', 'الصافي'],
        ...weeks.map((d) => [shortDate(d.date), '${d.pieces}', '${d.jobs}', money(d.revenue), money(d.expenses), money(d.net)]),
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headerDirection: pw.TextDirection.rtl,
      tableDirection: pw.TextDirection.rtl,
      cellPadding: const pw.EdgeInsets.all(5),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
    );
  }

  pw.Widget _accountingCheck(ReportData r) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500), borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('المراجعة المحاسبية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textDirection: pw.TextDirection.rtl),
          pw.Text('${money(r.revenue)} − ${money(r.expenses)} = ${money(r.net)} (${_statusLabel(r)})', textDirection: pw.TextDirection.rtl),
        ]),
      );
}
