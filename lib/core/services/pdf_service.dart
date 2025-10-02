import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:recibos_flutter/core/models/receipt.dart';
import 'package:recibos_flutter/core/models/receipt_item.dart';
import 'package:flutter/widgets.dart' show Locale;

class PdfService {
  Future<Uint8List> buildReceiptPdf({
    required Receipt receipt,
    required List<ReceiptItem> items,
    required Locale locale,
  }) async {
    final doc = pw.Document();
    final fmt = NumberFormat.simpleCurrency(locale: locale.toLanguageTag());

    String money(num? v) {
      if (v == null) return '-';
      final s = fmt.format(v);
      if (_isAscii(s)) return s;
      final code = (receipt.currency ?? '').trim();
      if (code.isNotEmpty) {
        final f = NumberFormat.currency(locale: locale.toLanguageTag(), name: code, symbol: code);
        return f.format(v);
      }
      // Fallback genérico si el símbolo no es ASCII
      return NumberFormat.currency(locale: locale.toLanguageTag(), symbol: '', name: '').format(v);
    }
    String dateStr(DateTime? d) => d == null ? '' : DateFormat.yMMMd(locale.toLanguageTag()).format(d.toLocal());

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _th('Item'), _th('Qty'), _th('Unit'), _th('Unit Price'), _th('Total'),
      ]),
      ...items.map((it) {
        final name = it.product?.name ?? it.originalText ?? '';
        return pw.TableRow(children: [
          _td(name),
          _td((it.quantity ?? 1).toString()),
          _td(it.unit ?? ''),
          _td(money(it.unitPrice ?? 0)),
          _td(money(it.totalPrice ?? ((it.quantity ?? 1) * (it.unitPrice ?? 0)))),
        ]);
      })
    ];

    final total = receipt.amount ?? items.fold<double>(0, (a, it) => a + (it.totalPrice ?? (it.unitPrice ?? 0) * (it.quantity ?? 1)));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kv('Merchant', receipt.merchantName ?? '-'),
                    _kv('Category', receipt.category ?? '-'),
                    _kv('Date', dateStr(receipt.purchaseDate)),
                    if ((receipt.notes ?? '').isNotEmpty) _kv('Notes', receipt.notes!),
                  ],
                ),
              ),
              pw.Container(
                alignment: pw.Alignment.topRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(money(total), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: rows,
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _th(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        color: PdfColors.grey200,
        child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _td(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: pw.Text(text),
      );

  pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '$k: ', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: v),
          ]),
        ),
      );
}

bool _isAscii(String s) {
  for (final ch in s.codeUnits) {
    if (ch > 0x7F) return false;
  }
  return true;
}
