/// PDF portfolio of pinned proof (plan v2 6.8). Photos stay on the phone: the
/// file is built locally and only leaves if the user shares it.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'day.dart';
import 'engine.dart';
import 'vault.dart';

Future<Uint8List> buildPortfolioPdf(DayView v) async {
  final doc = pw.Document(title: 'Work I can show', author: v.name.isEmpty ? 'Challenger Timer' : v.name);
  final items = pinned(v).isEmpty ? v.proofs.take(30).toList() : pinned(v);
  final widgets = <pw.Widget>[
    pw.Header(level: 0, child: pw.Text(v.name.isEmpty ? 'Work I can show' : "${v.name}: work I can show", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
    pw.Text('${v.master.totalDays} days shown up, ${(v.metrics["minutes"]! / 60).toStringAsFixed(1)} hours of work, ${v.proofs.length} pieces of proof.'),
    pw.SizedBox(height: 14),
  ];
  for (final p in items) {
    final proj = v.rec(p.str('projectId'))?.str('name') ?? '';
    widgets.add(pw.Text('${dayLabel(p.integer('day'))}${proj.isEmpty ? '' : '  -  $proj'}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)));
    if (p.str('type') == 'photo' && File(p.str('value')).existsSync()) {
      widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Image(pw.MemoryImage(File(p.str('value')).readAsBytesSync()), height: 220, fit: pw.BoxFit.contain)));
    } else if (p.str('type') == 'voice') {
      widgets.add(pw.Text('Voice note (not included in the PDF)'));
    } else {
      widgets.add(pw.Text(p.str('value'), style: const pw.TextStyle(fontSize: 12)));
    }
    widgets.add(pw.SizedBox(height: 12));
  }
  if (items.isEmpty) widgets.add(pw.Text('No proof saved yet.'));
  doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(36), build: (_) => widgets));
  return doc.save();
}
