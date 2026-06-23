import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/session_data.dart';

class ExportService {
  static String toCsv(SessionData session) {
    final buf = StringBuffer();
    buf.writeln("Session,${session.startTime.toIso8601String()},${session.playerName}");
    buf.writeln("Duration (s),${session.duration.inSeconds}");
    buf.writeln("Max Speed (km/h),${session.maxSpeed.toStringAsFixed(1)}");
    buf.writeln("Avg Speed (km/h),${session.avgSpeed.toStringAsFixed(1)}");
    buf.writeln("Sprints,${session.sprintCount}");
    buf.writeln("Data Points,${session.points.length}");
    buf.writeln();
    buf.writeln("Index,Latitude,Longitude,Speed (km/h),HeartRate,Timestamp");
    for (var i = 0; i < session.points.length; i++) {
      final p = session.points[i];
      buf.writeln("${i + 1},${p.lat},${p.lng},${p.speed},${p.heartRate},${p.timestamp.toIso8601String()}");
    }
    return buf.toString();
  }

  static Future<Uint8List> toPdf(SessionData session) async {
    final doc = pw.Document();
    final date = "${session.startTime.day}/${session.startTime.month}/${session.startTime.year}";
    final dur = session.duration;
    final durStr = dur.inHours > 0
        ? "${dur.inHours}h ${dur.inMinutes.remainder(60)}m ${dur.inSeconds.remainder(60)}s"
        : "${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s";

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Header(level: 0, text: "Sendex — Session Report"),
          pw.Paragraph(text: "Player: ${session.playerName}"),
          pw.Paragraph(text: "Date: $date"),
          pw.Paragraph(text: "Duration: $durStr"),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, text: "Summary"),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ["Metric", "Value"],
            data: [
              ["Max Speed", "${session.maxSpeed.toStringAsFixed(1)} km/h"],
              ["Avg Speed", "${session.avgSpeed.toStringAsFixed(1)} km/h"],
              ["Sprints", "${session.sprintCount}"],
              ["Data Points", "${session.points.length}"],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: "GPS Data Log"),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headers: ["#", "Latitude", "Longitude", "Speed", "HR"],
            data: session.points.asMap().entries.map((e) => [
              "${e.key + 1}",
              e.value.lat.toStringAsFixed(5),
              e.value.lng.toStringAsFixed(5),
              "${e.value.speed} km/h",
              "${e.value.heartRate}",
            ]).toList(),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> exportCsv(SessionData session) async {
    await Clipboard.setData(ClipboardData(text: toCsv(session)));
  }

  static Future<void> exportPdf(SessionData session) async {
    final bytes = await toPdf(session);
    await Printing.sharePdf(
      bytes: bytes,
      filename: "sendex_${session.startTime.millisecondsSinceEpoch}.pdf",
    );
  }
}
