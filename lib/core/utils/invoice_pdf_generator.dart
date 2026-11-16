import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/cash_transaction.dart';
import '../../data/models/nota_invoice.dart';
import '../../data/models/workspace.dart';
import 'rupiah_formatter.dart';

/// Pure-Dart Swiss-editorial commercial A4 PDF 1.4 generator matching the Go backend's RenderInvoicePDF.
class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  static String _pdfEscape(String s) {
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
        ascii.write(' / ');
      } else if (rune == 0x2014 || rune == 0x2013) {
        ascii.write('-');
      } else {
        ascii.write(' ');
      }
    }
    return ascii.toString();
  }

  static String _truncate(String s, int maxLen) {
    final trimmed = s.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen - 3)}...';
  }

  /// Exact Adobe Type1 AFM glyph widths (in 1/1000 em) for Helvetica (F1) and Helvetica-Bold (F2).
  static int _glyphWidthPermille(String font, int rune) {
    final bold = font == 'F2';
    final ch = String.fromCharCode(rune);
    switch (ch) {
      case ' ':
      case '.':
      case ',':
      case ':':
      case ';':
      case '!':
      case '|':
      case 'i':
      case 'l':
      case 'I':
      case "'":
        if (bold && (ch == '!' || ch == ':' || ch == ';')) return 333;
        if (ch == 'i' || ch == 'l') return bold ? 278 : 222;
        return 278;
      case '-':
      case '(':
      case ')':
      case '[':
      case ']':
      case '`':
        return 333;
      case '/':
      case '\\':
        return 278;
      case 'f':
      case 'j':
      case 'r':
      case 't':
        if (bold) {
          return ch == 'r' ? 389 : 333;
        }
        return ch == 'r' ? 333 : 278;
      case 's':
      case 'z':
      case 'c':
      case 'k':
      case 'v':
      case 'x':
      case 'y':
      case 'J':
        return bold ? 556 : 500;
      case 'a':
      case 'b':
      case 'd':
      case 'e':
      case 'g':
      case 'h':
      case 'n':
      case 'o':
      case 'p':
      case 'q':
      case 'u':
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
      case r'$':
      case '#':
      case '+':
      case '=':
      case '~':
      case '^':
      case '?':
      case '_':
      case '*':
        if (bold &&
            (ch == 'b' ||
                ch == 'd' ||
                ch == 'g' ||
                ch == 'h' ||
                ch == 'n' ||
                ch == 'o' ||
                ch == 'p' ||
                ch == 'q' ||
                ch == 'u')) {
          return 611;
        }
        return 556;
      case 'F':
      case 'L':
      case 'T':
      case 'Z':
      case 'E':
      case 'P':
      case 'S':
        if (bold) return ch == 'L' ? 611 : 667;
        if (ch == 'L') return 556;
        if (ch == 'T' || ch == 'Z') return 611;
        return 667;
      case 'A':
      case 'B':
      case 'C':
      case 'D':
      case 'G':
      case 'H':
      case 'K':
      case 'N':
      case 'O':
      case 'Q':
      case 'R':
      case 'U':
      case 'V':
      case 'X':
      case 'Y':
      case 'w':
        if (ch == 'G' || ch == 'O' || ch == 'Q') return 778;
        if (bold &&
            (ch == 'C' ||
                ch == 'D' ||
                ch == 'H' ||
                ch == 'N' ||
                ch == 'R' ||
                ch == 'U')) {
          return 722;
        }
        return 685;
      case 'M':
      case 'm':
        return bold ? 889 : 833;
      case 'W':
        return 944;
      case '@':
      case '%':
        return 889;
      default:
        return 556;
    }
  }

  static double _measureTextWidth(String font, double size, String text) {
    final escaped = _pdfEscape(text);
    var total = 0;
    for (final rune in escaped.runes) {
      total += _glyphWidthPermille(font, rune);
    }
    return total * size / 1000.0;
  }

  static List<String> _wrapTextByWidth(
    String font,
    double size,
    String text,
    double maxWidth,
    int maxLines,
  ) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const ['-'];
    final lines = <String>[];
    var current = words.first;
    for (final w in words.skip(1)) {
      final candidate = '$current $w';
      if (_measureTextWidth(font, size, candidate) <= maxWidth) {
        current = candidate;
      } else {
        lines.add(current);
        current = w;
        if (lines.length == maxLines - 1) break;
      }
    }
    lines.add(current);
    if (lines.length > maxLines) {
      return lines.sublist(0, maxLines);
    }
    return lines;
  }

  static ({Uint8List bytes, int width, int height})? _extractJpegFromLogoUrl(
    String logoUrl,
  ) {
    var trimmed = logoUrl.trim();
    if (trimmed.isEmpty) return null;
    final idx = trimmed.indexOf('base64,');
    if (idx >= 0) {
      trimmed = trimmed.substring(idx + 7);
    }
    try {
      final raw = base64Decode(trimmed);
      if (raw.length < 20 || raw[0] != 0xFF || raw[1] != 0xD8) {
        return null;
      }
      var i = 2;
      while (i + 9 < raw.length) {
        if (raw[i] != 0xFF) {
          i++;
          continue;
        }
        final marker = raw[i + 1];
        if (marker == 0xFF) {
          i++;
          continue;
        }
        if (marker == 0xD8 ||
            marker == 0xD9 ||
            (marker >= 0xD0 && marker <= 0xD7)) {
          i += 2;
          continue;
        }
        final segLen = (raw[i + 2] << 8) | raw[i + 3];
        if (segLen < 2 || i + 2 + segLen > raw.length) break;
        if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
          final h = (raw[i + 5] << 8) | raw[i + 6];
          final w = (raw[i + 7] << 8) | raw[i + 8];
          if (w > 0 && h > 0) {
            return (bytes: raw, width: w, height: h);
          }
          break;
        }
        i += 2 + segLen;
      }
      return (bytes: raw, width: 120, height: 120);
    } catch (_) {
      return null;
    }
  }

  static ({Uint8List bytes, String filename}) generate({
    required NotaInvoice nota,
    required Workspace workspace,
    bool? isProOverride,
  }) {
    final isPro = isProOverride ?? workspace.isPro;
    final content = StringBuffer();
    String fmtNum(double v) => v.toStringAsFixed(2);
    String fmtCol(double v) => v.toStringAsFixed(3);

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
        '${fmtCol(r)} ${fmtCol(g)} ${fmtCol(b)} rg ${fmtNum(x)} ${fmtNum(y)} ${fmtNum(w)} ${fmtNum(h)} re f',
      );
    }

    void strokeRect(
      double x,
      double y,
      double w,
      double h,
      double lineW,
      double r,
      double g,
      double b,
    ) {
      content.writeln(
        '${fmtNum(lineW)} w ${fmtCol(r)} ${fmtCol(g)} ${fmtCol(b)} RG ${fmtNum(x)} ${fmtNum(y)} ${fmtNum(w)} ${fmtNum(h)} re S',
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
        '${fmtNum(width)} w ${fmtCol(r)} ${fmtCol(g)} ${fmtCol(b)} RG ${fmtNum(x1)} ${fmtNum(y1)} m ${fmtNum(x2)} ${fmtNum(y2)} l S',
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
        'BT /$font ${fmtNum(size)} Tf ${fmtCol(r)} ${fmtCol(g)} ${fmtCol(b)} rg 1 0 0 1 ${fmtNum(x)} ${fmtNum(y)} Tm (${_pdfEscape(text)}) Tj ET',
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
      final w = _measureTextWidth(font, size, text);
      var x = rightX - w;
      if (x < 48) x = 48;
      drawText(font, size, x, y, r, g, b, text);
    }

    // Color tokens (Clean Swiss Financial Ledger)
    const inkR = 0.035, inkG = 0.051, inkB = 0.086; // #090D16
    const bodyR = 0.200, bodyG = 0.255, bodyB = 0.333; // #334155
    const mutedR = 0.392, mutedG = 0.455, mutedB = 0.545; // #64748B
    const ruleR = 0.886, ruleG = 0.910, ruleB = 0.941; // #E2E8F0
    const softR = 0.973, softG = 0.980, softB = 0.988; // #F8FAFC

    // 1. Pure white A4 sheet (595 x 842 pt) + top 4pt structural ink rule
    drawRect(0, 0, 595, 842, 1.0, 1.0, 1.0);
    drawRect(0, 838, 595, 4, inkR, inkG, inkB);

    final wsName =
        workspace.name.trim().isEmpty ? 'UcapKas UMKM' : workspace.name.trim();
    var shortMark = workspace.shortName.trim().toUpperCase();
    if (shortMark.isEmpty) {
      shortMark = wsName.length >= 2
          ? wsName.substring(0, 2).toUpperCase()
          : 'UK';
    } else if (shortMark.length > 3) {
      shortMark = shortMark.substring(0, 3);
    }

    // 2. Editorial Header (Asymmetric Split)
    final customJpeg =
        isPro ? _extractJpegFromLogoUrl(workspace.logoUrl) : null;

    if (!isPro) {
      // Starter / Free Tier: Render Official UcapKas Vector Brand Logo (28x28pt)
      drawRect(48, 760, 28, 28, 0.051, 0.580, 0.533); // Primary Teal #0D9488
      drawRect(54.16, 779.18, 3.5, 3.5, 0.961, 0.620, 0.043); // Spark Gold #F59E0B
      drawRect(54.16, 767.00, 3.5, 8.68, 1.0, 1.0, 1.0); // Bar 1
      drawRect(60.32, 767.00, 3.5, 12.32, 1.0, 1.0, 1.0); // Bar 2
      drawRect(66.48, 767.00, 3.5, 16.24, 1.0, 1.0, 1.0); // Bar 3
      drawRect(54.16, 767.00, 15.82, 3.5, 1.0, 1.0, 1.0); // Base bar
    } else if (customJpeg != null) {
      // Pro Tier with Custom Uploaded Logo Image (JPEG XObject /Im1)
      content.writeln('q 28.00 0 0 28.00 48.00 760.00 cm /Im1 Do Q');
      strokeRect(48, 760, 28, 28, 0.5, ruleR, ruleG, ruleB);
    } else {
      // Pro Tier Custom Monogram Box (28x28pt)
      drawRect(48, 760, 28, 28, inkR, inkG, inkB);
      final markW = _measureTextWidth('F2', 10, shortMark);
      drawText(
        'F2',
        10,
        48 + (28 - markW) / 2,
        770.5,
        1.0,
        1.0,
        1.0,
        shortMark,
      );
    }

    drawText('F2', 16, 86, 775, inkR, inkG, inkB, _truncate(wsName, 32));
    drawText(
      'F1',
      9,
      86,
      762,
      mutedR,
      mutedG,
      mutedB,
      !isPro
          ? 'Dokumen Tagihan / Powered by UcapKas'
          : 'Dokumen Tagihan & Faktur Komersial',
    );

    drawTextRight('F2', 22, 547, 772, inkR, inkG, inkB, 'INVOICE');
    drawTextRight('F1', 9.5, 547, 757, bodyR, bodyG, bodyB, '#${nota.number}');

    final (
      String statusText,
      double stFgR,
      double stFgG,
      double stFgB,
      double stBgR,
      double stBgG,
      double stBgB,
      double stBdR,
      double stBdG,
      double stBdB,
    ) = switch (nota.status) {
      NotaStatus.lunas => (
          'LUNAS',
          0.024,
          0.373,
          0.275,
          0.925,
          0.992,
          0.961,
          0.655,
          0.953,
          0.816,
        ),
      NotaStatus.jatuhTempo => (
          'JATUH TEMPO',
          0.600,
          0.106,
          0.106,
          0.996,
          0.949,
          0.949,
          0.996,
          0.792,
          0.792,
        ),
      NotaStatus.menunggu => (
          'MENUNGGU PEMBAYARAN',
          0.573,
          0.251,
          0.055,
          1.000,
          0.984,
          0.922,
          0.992,
          0.902,
          0.541,
        ),
    };

    final pillW = _measureTextWidth('F2', 7.5, statusText) + 18;
    final pillX = 547 - pillW;
    drawRect(pillX, 735, pillW, 16, stBgR, stBgG, stBgB);
    strokeRect(pillX, 735, pillW, 16, 0.6, stBdR, stBdG, stBdB);
    drawText('F2', 7.5, pillX + 9, 740.5, stFgR, stFgG, stFgB, statusText);

    // 3. Structured 3-Column Metadata Grid (y = 640 .. 718)
    drawLine(48, 718, 547, 718, 0.8, inkR, inkG, inkB);
    drawLine(48, 640, 547, 640, 0.6, ruleR, ruleG, ruleB);
    drawLine(218, 640, 218, 718, 0.5, ruleR, ruleG, ruleB);
    drawLine(378, 640, 378, 718, 0.5, ruleR, ruleG, ruleB);

    // Column 1: DITAGIHKAN KEPADA
    drawText('F2', 7.5, 48, 703, mutedR, mutedG, mutedB, 'DITAGIHKAN KEPADA');
    final clientTitle = nota.clientName.split('—').first.trim();
    drawText(
      'F2',
      11,
      48,
      686,
      inkR,
      inkG,
      inkB,
      _truncate(clientTitle, 26),
    );
    final contact =
        nota.clientContact.trim().isEmpty ? '-' : nota.clientContact.trim();
    drawText(
      'F1',
      9,
      48,
      671,
      bodyR,
      bodyG,
      bodyB,
      'WA / Telp: ${_truncate(contact, 22)}',
    );
    drawText('F1', 8.5, 48, 656, mutedR, mutedG, mutedB, 'Pelanggan Terdaftar');

    // Column 2: DITERBITKAN OLEH
    drawText('F2', 7.5, 230, 703, mutedR, mutedG, mutedB, 'DITERBITKAN OLEH');
    drawText('F2', 10.5, 230, 686, inkR, inkG, inkB, _truncate(wsName, 23));
    final bankMeta = workspace.bankName.trim().isNotEmpty
        ? 'Bank ${workspace.bankName.trim()}'
        : 'Pembayaran Transfer / Tunai';
    drawText('F1', 9, 230, 671, bodyR, bodyG, bodyB, _truncate(bankMeta, 25));
    drawText(
      'F1',
      8.5,
      230,
      656,
      mutedR,
      mutedG,
      mutedB,
      'Mata Uang: IDR (Rupiah)',
    );

    // Column 3: RINCIAN DOKUMEN
    drawText('F2', 7.5, 390, 703, mutedR, mutedG, mutedB, 'RINCIAN DOKUMEN');
    drawText('F1', 8.5, 390, 686, mutedR, mutedG, mutedB, 'Tgl. Terbit');
    drawTextRight('F2', 8.5, 547, 686, inkR, inkG, inkB, nota.dateIssued);

    drawText('F1', 8.5, 390, 671, mutedR, mutedG, mutedB, 'Jatuh Tempo');
    final dueClean = nota.dueDateLabel.replaceFirst('Tempo: ', '');
    final (dueR, dueG, dueB) = nota.status == NotaStatus.jatuhTempo
        ? (stFgR, stFgG, stFgB)
        : (inkR, inkG, inkB);
    drawTextRight(
      'F2',
      8.5,
      547,
      671,
      dueR,
      dueG,
      dueB,
      _truncate(dueClean, 20),
    );

    drawText('F1', 8.5, 390, 656, mutedR, mutedG, mutedB, 'No. Dokumen');
    drawTextRight(
      'F1',
      8.5,
      547,
      656,
      bodyR,
      bodyG,
      bodyB,
      _truncate(nota.number, 20),
    );

    // 4. Line Items Table (Swiss Financial Grid)
    const tableTop = 614.0;
    drawLine(48, tableTop, 547, tableTop, 0.8, inkR, inkG, inkB);
    drawLine(48, tableTop - 22, 547, tableTop - 22, 0.6, ruleR, ruleG, ruleB);

    drawText('F2', 7.5, 48, tableTop - 14, mutedR, mutedG, mutedB, 'NO');
    drawText(
      'F2',
      7.5,
      76,
      tableTop - 14,
      mutedR,
      mutedG,
      mutedB,
      'DESKRIPSI BARANG / JASA',
    );
    drawTextRight('F2', 7.5, 336, tableTop - 14, mutedR, mutedG, mutedB, 'QTY');
    drawTextRight(
      'F2',
      7.5,
      438,
      tableTop - 14,
      mutedR,
      mutedG,
      mutedB,
      'HARGA SATUAN',
    );
    drawTextRight(
      'F2',
      7.5,
      547,
      tableTop - 14,
      mutedR,
      mutedG,
      mutedB,
      'JUMLAH',
    );

    final items = nota.items.isNotEmpty
        ? nota.items
        : [
            TransactionLineItem(
              name: clientTitle,
              quantity: 1,
              unitPrice: nota.amount,
            ),
          ];

    var y = tableTop - 40.0;
    final maxRows = items.length > 10 ? 10 : items.length;
    var computedSubtotal = 0;

    for (var i = 0; i < maxRows; i++) {
      final item = items[i];
      final sub = item.subtotal;
      computedSubtotal += sub;

      final descLines = _wrapTextByWidth('F1', 9.5, item.name, 224.0, 2);
      final rowHeight = descLines.length > 1 ? 36.0 : 26.0;

      drawText(
        'F1',
        9,
        48,
        y,
        mutedR,
        mutedG,
        mutedB,
        (i + 1).toString().padLeft(2, '0'),
      );
      drawText('F2', 9.5, 76, y, inkR, inkG, inkB, descLines.first);
      if (descLines.length > 1) {
        drawText('F1', 8.5, 76, y - 12, bodyR, bodyG, bodyB, descLines[1]);
      }

      drawTextRight(
        'F1',
        9.5,
        336,
        y,
        bodyR,
        bodyG,
        bodyB,
        '${item.quantity}',
      );
      drawTextRight(
        'F1',
        9.5,
        438,
        y,
        bodyR,
        bodyG,
        bodyB,
        RupiahFormatter.format(item.unitPrice),
      );
      drawTextRight(
        'F2',
        9.5,
        547,
        y,
        inkR,
        inkG,
        inkB,
        RupiahFormatter.format(sub),
      );

      final lineY = y - (rowHeight - 16.0);
      drawLine(48, lineY, 547, lineY, 0.4, ruleR, ruleG, ruleB);
      y -= rowHeight;
    }

    if (computedSubtotal == 0) {
      computedSubtotal = nota.amount;
    }

    // 5. Right-Aligned Financial Summary Block
    final sumTop = y - 6.0;
    drawText('F1', 9, 350, sumTop, bodyR, bodyG, bodyB, 'Subtotal');
    drawTextRight(
      'F1',
      9,
      547,
      sumTop,
      inkR,
      inkG,
      inkB,
      RupiahFormatter.format(computedSubtotal),
    );

    drawText(
      'F1',
      9,
      350,
      sumTop - 16,
      bodyR,
      bodyG,
      bodyB,
      'Pajak / Biaya Tambahan',
    );
    drawTextRight('F1', 9, 547, sumTop - 16, mutedR, mutedG, mutedB, 'Rp 0');

    drawLine(350, sumTop - 26, 547, sumTop - 26, 1.0, inkR, inkG, inkB);

    final totalRowY = sumTop - 44;
    drawRect(342, totalRowY - 8, 205, 26, softR, softG, softB);
    drawText('F2', 10, 350, totalRowY, inkR, inkG, inkB, 'Total Tagihan');
    final (totalR, totalG, totalB) = nota.status == NotaStatus.lunas
        ? (stFgR, stFgG, stFgB)
        : (inkR, inkG, inkB);
    drawTextRight(
      'F2',
      12.5,
      547,
      totalRowY - 1,
      totalR,
      totalG,
      totalB,
      RupiahFormatter.format(nota.amount),
    );
    drawLine(350, totalRowY - 10, 547, totalRowY - 10, 0.8, inkR, inkG, inkB);

    // 6. Notes (Left Side Aligned with Summary if Present)
    if (nota.notes.trim().isNotEmpty) {
      drawText('F2', 7.5, 48, sumTop, mutedR, mutedG, mutedB, 'CATATAN TAGIHAN');
      final noteLines = _wrapTextByWidth('F1', 8.5, nota.notes, 260.0, 3);
      var ny = sumTop - 13.0;
      for (final nl in noteLines) {
        drawText('F1', 8.5, 48, ny, bodyR, bodyG, bodyB, nl);
        ny -= 12.0;
      }
    }

    // 7. Settlement & Verification Section
    const settleTop = 168.0;
    drawLine(48, settleTop, 547, settleTop, 0.5, ruleR, ruleG, ruleB);

    drawRect(48, 102, 2.5, 52, inkR, inkG, inkB);
    drawText(
      'F2',
      7.5,
      58,
      146,
      mutedR,
      mutedG,
      mutedB,
      'INSTRUKSI PEMBAYARAN',
    );

    var bankTitle = 'Transfer Bank / QRIS Resmi $wsName';
    var bankSub =
        'Cantumkan nomor referensi #${nota.number} pada berita pembayaran.';
    if (workspace.bankName.trim().isNotEmpty ||
        workspace.bankAccountNumber.trim().isNotEmpty) {
      bankTitle =
          '${workspace.bankName.trim()}  -  ${workspace.bankAccountNumber.trim()}'
              .trim();
      if (workspace.bankAccountHolder.trim().isNotEmpty) {
        bankSub =
            'a.n. ${workspace.bankAccountHolder.trim()}  |  Ref: #${nota.number}';
      }
    }
    drawText('F2', 10, 58, 130, inkR, inkG, inkB, _truncate(bankTitle, 52));
    drawText('F1', 8.5, 58, 116, bodyR, bodyG, bodyB, _truncate(bankSub, 64));
    drawText(
      'F1',
      8,
      58,
      103,
      mutedR,
      mutedG,
      mutedB,
      'Harap simpan bukti transfer sebagai referensi pelunasan yang sah.',
    );

    drawTextRight(
      'F2',
      7.5,
      547,
      146,
      mutedR,
      mutedG,
      mutedB,
      'VERIFIKASI DIGITAL',
    );
    drawTextRight('F2', 9.5, 547, 130, inkR, inkG, inkB, _truncate(wsName, 30));
    drawTextRight(
      'F1',
      8,
      547,
      116,
      bodyR,
      bodyG,
      bodyB,
      'Diterbitkan: ${nota.dateIssued}',
    );
    drawTextRight(
      'F1',
      8,
      547,
      103,
      mutedR,
      mutedG,
      mutedB,
      'Sah tanpa tanda tangan basah',
    );

    // 8. Footer (Starter Watermark vs Pro White-Label)
    drawLine(48, 68, 547, 68, 0.5, ruleR, ruleG, ruleB);
    if (!isPro) {
      drawRect(48, 40, 499, 22, softR, softG, softB);
      strokeRect(48, 40, 499, 22, 0.5, ruleR, ruleG, ruleB);
      // Mini UcapKas Logo Mark (12x12pt) inside footer watermark
      drawRect(55, 45, 12, 12, 0.051, 0.580, 0.533);
      drawRect(57.6, 53.2, 1.5, 1.5, 0.961, 0.620, 0.043);
      drawRect(57.6, 48.0, 1.5, 3.7, 1.0, 1.0, 1.0);
      drawRect(60.3, 48.0, 1.5, 5.3, 1.0, 1.0, 1.0);
      drawRect(63.0, 48.0, 1.5, 7.0, 1.0, 1.0, 1.0);
      drawRect(57.6, 48.0, 6.9, 1.5, 1.0, 1.0, 1.0);

      drawText(
        'F2',
        8.5,
        73,
        48.5,
        inkR,
        inkG,
        inkB,
        'Invoice dibuat oleh aplikasi UcapKas, tersedia di Play Store gratis',
      );
      drawTextRight(
        'F1',
        8,
        539,
        48.5,
        mutedR,
        mutedG,
        mutedB,
        'Dokumen #${nota.number}',
      );
    } else {
      drawText(
        'F1',
        8,
        48,
        53,
        mutedR,
        mutedG,
        mutedB,
        '${_truncate(wsName, 36)}  /  Dokumen #${nota.number}',
      );
      drawTextRight(
        'F1',
        8,
        547,
        53,
        mutedR,
        mutedG,
        mutedB,
        'Halaman 1 dari 1  -  Faktur Resmi ${_truncate(wsName, 24)}',
      );
    }

    final streamBytes = ascii.encode(content.toString());
    final out = BytesBuilder();
    void writeAscii(String s) => out.add(ascii.encode(s));

    writeAscii('%PDF-1.4\n');

    final totalObjs = customJpeg != null ? 7 : 6;
    final offsets = List<int>.filled(totalObjs + 1, 0);
    void writeObj(int id, String body) {
      offsets[id] = out.length;
      writeAscii('$id 0 obj\n$body\nendobj\n');
    }

    final pageResources = customJpeg != null
        ? '<< /Font << /F1 4 0 R /F2 5 0 R >> /XObject << /Im1 7 0 R >> >>'
        : '<< /Font << /F1 4 0 R /F2 5 0 R >> >>';

    writeObj(1, '<< /Type /Catalog /Pages 2 0 R >>');
    writeObj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    writeObj(
      3,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources $pageResources /Contents 6 0 R >>',
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
    if (customJpeg != null) {
      offsets[7] = out.length;
      writeAscii(
        '7 0 obj\n<< /Type /XObject /Subtype /Image /Width ${customJpeg.width} /Height ${customJpeg.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${customJpeg.bytes.length} >>\nstream\n',
      );
      out.add(customJpeg.bytes);
      writeAscii('\nendstream\nendobj\n');
    }

    final xrefPos = out.length;
    writeAscii('xref\n0 ${totalObjs + 1}\n0000000000 65535 f \n');
    for (var i = 1; i <= totalObjs; i++) {
      final padded = offsets[i].toString().padLeft(10, '0');
      writeAscii('$padded 00000 n \n');
    }
    writeAscii(
      'trailer\n<< /Size ${totalObjs + 1} /Root 1 0 R >>\nstartxref\n$xrefPos\n%%EOF\n',
    );

    final safeNumber = nota.number
        .replaceAll('/', '-')
        .replaceAll('\\', '-')
        .replaceAll(' ', '_');
    return (
      bytes: out.toBytes(),
      filename: '$safeNumber.pdf',
    );
  }
}
