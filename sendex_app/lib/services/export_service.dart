import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/session_data.dart';

class ExportService {
  static String _fmt(double v) => v.toStringAsFixed(1);

  static String _fmtDur(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    return h > 0 ? "${h}h ${m}m ${s}s" : "${m}m ${s}s";
  }

  static List<List<String>> _metrics(SessionData s) => [
        ["Max Speed (km/h)", _fmt(s.maxSpeed)],
        ["Avg Speed (km/h)", _fmt(s.avgSpeed)],
        ["Min Speed (km/h)", _fmt(s.minSpeed)],
        ["Total Distance (m)", _fmt(s.totalDistance)],
        ["Sprint Count", "${s.sprintCount}"],
        ["Avg Sprint Speed (km/h)", _fmt(s.avgSprintSpeed)],
        ["Max Sprint Speed (km/h)", _fmt(s.maxSprintSpeed)],
        ["Sprint Distance (m)", _fmt(s.totalSprintDistance)],
        ["Avg Heart Rate (bpm)", _fmt(s.avgHeartRate)],
        ["Max Heart Rate (bpm)", _fmt(s.maxHeartRate)],
        ["Min Heart Rate (bpm)", _fmt(s.minHeartRate)],
        ["Accelerations", "${s.accelerations}"],
        ["Decelerations", "${s.decelerations}"],
        ["Avg Acceleration (m/s²)", _fmt(s.avgAcceleration)],
        ["Zone 0-7 km/h", _fmtDur(s.timeInZone0to7)],
        ["Zone 7-12 km/h", _fmtDur(s.timeInZone7to12)],
        ["Zone 12-18 km/h", _fmtDur(s.timeInZone12to18)],
        ["Zone 18+ km/h", _fmtDur(s.timeInZone18plus)],
        ["Intensity Index (%)", _fmt(s.intensityIndex)],
        ["Workload", _fmt(s.workload)],
      ];

  static String toCsv(SessionData session) {
    final buf = StringBuffer();
    buf.writeln("Session,${session.startTime.toIso8601String()},${session.playerName}");
    buf.writeln("Duration (s),${session.duration.inSeconds}");
    for (final m in _metrics(session)) {
      buf.writeln("${m[0]},${m[1]}");
    }
    buf.writeln();
    buf.writeln("Index,Latitude,Longitude,Speed (km/h),HeartRate,Acceleration (m/s²),Timestamp");
    for (var i = 0; i < session.points.length; i++) {
      final p = session.points[i];
      buf.writeln(
          "${i + 1},${p.lat},${p.lng},${p.speed},${p.heartRate},${p.acceleration},${p.timestamp.toIso8601String()}");
    }
    return buf.toString();
  }

  static Future<Uint8List> toPdf(SessionData session) async {
    final doc = pw.Document();
    final date =
        "${session.startTime.day}/${session.startTime.month}/${session.startTime.year}";
    final durStr = _fmtDur(session.duration);

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
          pw.Header(level: 1, text: "Performance Metrics"),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ["Metric", "Value"],
            data: _metrics(session),
          ),
          pw.SizedBox(height: 24),
          pw.Header(level: 1, text: "GPS Data Log"),
          pw.TableHelper.fromTextArray(
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headers: ["#", "Latitude", "Longitude", "Speed", "HR", "Accel"],
            data: session.points.asMap().entries.map((e) => [
                  "${e.key + 1}",
                  e.value.lat.toStringAsFixed(5),
                  e.value.lng.toStringAsFixed(5),
                  "${e.value.speed} km/h",
                  "${e.value.heartRate}",
                  "${e.value.acceleration} m/s²",
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
