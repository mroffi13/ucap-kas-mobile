import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/cash_transaction.dart';
import '../../data/models/nota_invoice.dart';
import '../../data/models/workspace.dart';
import 'rupiah_formatter.dart';

/// Pure-Dart A4 PDF 1.4 generator matching the Go backend's RenderInvoicePDF.
/// Used as an instant offline / guest-mode fallback when downloading an invoice PDF.
class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  static ({Uint8List bytes, String filename}) generate({
    required NotaInvoice nota,
    required Workspace workspace,
  }) {
    final content = StringBuffer();

    String esc(String s) {
      final ascii = StringBuffer();
      for (final rune in s.runes) {
        if (rune >= 32 && rune <= 126) {
          final ch = String.fromCharCode(rune);
          if (ch == '\\' || ch == '(' || ch == ')') {
            ascii.write('\\$ch');
          } else {
            ascii.write(ch);
          }
        } else if (rune == 0x2022 || rune == 0x00B7) {
          ascii.write('-');
        } else if (rune == 0x2014 || rune == 0x2013) {
          ascii.write('-');
        } else {
          ascii.write(' ');
        }
      }
      return ascii.toString();
    }

    String fmtNum(double v) => v.toStringAsFixed(2);

    void drawRect(
      double x,
      double y,
      double w,
      double h,
      double r,
      double g,
      double b,
    ) {
      content.writeln(
        '${fmtNum(r)} ${fmtNum(g)} ${fmtNum(b)} rg ${fmtNum(x)} ${fmtNum(y)} ${fmtNum(w)} ${fmtNum(h)} re f',
      );
    }

    void drawLine(
      double x1,
      double y1,
      double x2,
      double y2,
      double width,
      double r,
      double g,
      double b,
    ) {
      content.writeln(
        '${fmtNum(width)} w ${fmtNum(r)} ${fmtNum(g)} ${fmtNum(b)} RG ${fmtNum(x1)} ${fmtNum(y1)} m ${fmtNum(x2)} ${fmtNum(y2)} l S',
      );
    }

    void drawText(
      String font,
      double size,
      double x,
      double y,
      double r,
      double g,
      double b,
      String text,
    ) {
      content.writeln(
        'BT /$font ${fmtNum(size)} Tf ${fmtNum(r)} ${fmtNum(g)} ${fmtNum(b)} rg 1 0 0 1 ${fmtNum(x)} ${fmtNum(y)} Tm (${esc(text)}) Tj ET',
      );
    }

    void drawTextRight(
      String font,
      double size,
      double rightX,
      double y,
      double r,
      double g,
      double b,
      String text,
    ) {
      final approxWidth = text.length * size * 0.52;
      var x = rightX - approxWidth;
      if (x < 48) x = 48;
      drawText(font, size, x, y, r, g, b, text);
    }

    // Header band (Nordic Ledger Deep Forest #0D2622)
    drawRect(0, 742, 595, 100, 0.05, 0.15, 0.13);
    drawText(
      'F2',
      20,
      48,
      792,
      1,
      1,
      1,
      workspace.name.isEmpty ? 'UcapKas UMKM' : workspace.name,
    );
    drawText(
      'F1',
      10,
      48,
      772,
      0.75,
      0.86,
      0.84,
      'INVOICE / NOTA TAGIHAN DIGITAL',
    );
    drawTextRight('F2', 14, 547, 792, 1, 1, 1, nota.number);
    drawTextRight(
      'F1',
      10,
      547,
      772,
      0.75,
      0.86,
      0.84,
      'Terbit: ${nota.dateIssued}',
    );

    // Status pill
    final (
      String statusText,
      double sr,
      double sg,
      double sb,
      double br,
      double bg,
      double bb,
    ) = switch (nota.status) {
      NotaStatus.lunas => (
          'STATUS: LUNAS',
          0.06,
          0.49,
          0.33,
          0.88,
          0.97,
          0.93,
        ),
      NotaStatus.jatuhTempo => (
          'STATUS: LEWAT JATUH TEMPO',
          0.78,
          0.16,
          0.22,
          0.99,
          0.91,
          0.92,
        ),
      NotaStatus.menunggu => (
          'STATUS: MENUNGGU PEMBAYARAN',
          0.72,
          0.43,
          0.04,
          0.99,
          0.96,
          0.88,
        ),
    };

    drawRect(48, 692, 230, 26, br, bg, bb);
    drawText('F2', 9.5, 58, 701, sr, sg, sb, statusText);

    // Recipient & Due Date section
    drawText('F1', 9.5, 48, 662, 0.42, 0.45, 0.49, 'DITAGIHKAN KEPADA');
    drawText('F2', 13, 48, 644, 0.07, 0.09, 0.11, nota.clientName);
    final contact =
        nota.clientContact.trim().isEmpty ? '-' : nota.clientContact.trim();
    drawText('F1', 10.5, 48, 628, 0.30, 0.34, 0.38, 'WhatsApp: $contact');

    drawTextRight('F1', 9.5, 547, 662, 0.42, 0.45, 0.49, 'BATAS PEMBAYARAN');
    drawTextRight('F2', 12, 547, 644, sr, sg, sb, nota.dueDateLabel);

    drawLine(48, 608, 547, 608, 0.8, 0.88, 0.90, 0.92);

    // Table header
    drawRect(48, 578, 499, 24, 0.95, 0.96, 0.97);
    drawText(
      'F2',
      9.5,
      58,
      586,
      0.30,
      0.34,
      0.38,
      'RINCIAN BARANG / JASA',
    );
    drawText('F2', 9.5, 310, 586, 0.30, 0.34, 0.38, 'QTY');
    drawText('F2', 9.5, 365, 586, 0.30, 0.34, 0.38, 'HARGA SATUAN');
    drawTextRight('F2', 9.5, 537, 586, 0.30, 0.34, 0.38, 'SUBTOTAL');

    final items = nota.items.isNotEmpty
        ? nota.items
        : [
            TransactionLineItem(
              name: nota.clientName,
              quantity: 1,
              unitPrice: nota.amount,
            ),
          ];

    var y = 556.0;
    for (var i = 0; i < items.length; i++) {
      if (y < 180) break;
      final item = items[i];
      var name = item.name.trim();
      if (name.length > 38) {
        name = '${name.substring(0, 35)}...';
      }
      drawText('F1', 10.5, 58, y, 0.07, 0.09, 0.11, '${i + 1}. $name');
      drawText('F1', 10.5, 310, y, 0.20, 0.24, 0.28, '${item.quantity}x');
      drawText(
        'F1',
        10.5,
        365,
        y,
        0.20,
        0.24,
        0.28,
        RupiahFormatter.format(item.unitPrice),
      );
      drawTextRight(
        'F2',
        10.5,
        537,
        y,
        0.07,
        0.09,
        0.11,
        RupiahFormatter.format(item.subtotal),
      );
      y -= 10;
      drawLine(48, y, 547, y, 0.5, 0.91, 0.93, 0.94);
      y -= 18;
    }

    // Total box
    y -= 6;
    drawRect(280, y - 28, 267, 38, 0.94, 0.97, 0.96);
    drawText('F2', 11, 294, y - 13, 0.07, 0.09, 0.11, 'TOTAL TAGIHAN');
    drawTextRight(
      'F2',
      13,
      537,
      y - 13,
      0.05,
      0.42,
      0.35,
      RupiahFormatter.format(nota.amount),
    );
    y -= 54;

    if (nota.notes.trim().isNotEmpty && y > 140) {
      drawText('F2', 9.5, 48, y, 0.42, 0.45, 0.49, 'CATATAN:');
      y -= 15;
      var notes = nota.notes.trim();
      if (notes.length > 85) {
        notes = '${notes.substring(0, 82)}...';
      }
      drawText('F1', 10, 48, y, 0.20, 0.24, 0.28, notes);
      y -= 24;
    }

    // Footer
    drawLine(48, 92, 547, 92, 0.6, 0.88, 0.90, 0.92);
    drawText(
      'F1',
      9,
      48,
      74,
      0.48,
      0.52,
      0.56,
      'Dokumen ini diterbitkan secara digital melalui UcapKas (${workspace.name}).',
    );

    final streamBytes = ascii.encode(content.toString());
    final pdf = StringBuffer();
    pdf.write('%PDF-1.4\n');

    final offsets = List<int>.filled(7, 0);
    void writeObj(int id, String body) {
      offsets[id] = pdf.length;
      pdf.write('$id 0 obj\n$body\nendobj\n');
    }

    writeObj(1, '<< /Type /Catalog /Pages 2 0 R >>');
    writeObj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    writeObj(
      3,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>',
    );
    writeObj(
      4,
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    );
    writeObj(
      5,
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
    );
    writeObj(
      6,
      '<< /Length ${streamBytes.length} >>\nstream\n${content.toString()}endstream',
    );

    final xrefPos = pdf.length;
    pdf.write('xref\n0 7\n0000000000 65535 f \n');
    for (var i = 1; i <= 6; i++) {
      final padded = offsets[i].toString().padLeft(10, '0');
      pdf.write('$padded 00000 n \n');
    }
    pdf.write(
      'trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n$xrefPos\n%%EOF\n',
    );

    final safeNumber = nota.number
        .replaceAll('/', '-')
        .replaceAll('\\', '-')
        .replaceAll(' ', '_');
    return (
      bytes: Uint8List.fromList(ascii.encode(pdf.toString())),
      filename: '$safeNumber.pdf',
    );
  }
}
