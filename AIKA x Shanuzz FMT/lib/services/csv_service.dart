import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import '../models/raw_table_entry.dart';

/// Handles CSV import and export for RawTableEntry data.
class CsvService {
  // The order of CSV columns for export/import
  static const List<String> _headers = [
    'Reffid', 'Date', 'Month', 'Amount', 'Mode Of Payment',
    'Row Desc', 'Row Note', 'Entry Timestamp', 'Entry User',
    'Edit Timestamp', 'Edit User',
  ];

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Converts entries to CSV string.
  String entriesToCsv(List<RawTableEntry> entries) {
    final buffer = StringBuffer();
    // Header row
    buffer.writeln(_headers.map(_escapeCsvField).join(','));
    // Data rows
    for (final entry in entries) {
      final row = [
        entry.reffid,
        entry.date,
        entry.month,
        entry.amount.toString(),
        entry.modeOfPayment,
        entry.rowDesc,
        entry.rowNote,
        entry.entryTimestamp,
        entry.entryUser,
        entry.editTimestamp,
        entry.editUser,
      ];
      buffer.writeln(row.map(_escapeCsvField).join(','));
    }
    return buffer.toString();
  }

  /// Triggers a browser download of the CSV file.
  void downloadCsv(String csv, String filename) {
    final blob = html.Blob([csv], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.Url.revokeObjectUrl(url);
    anchor.remove();
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Opens a file picker for CSV and returns parsed entries.
  /// Returns null if the user cancels.
  Future<List<RawTableEntry>?> pickAndParseCsv() async {
    final completer = Completer<List<RawTableEntry>?>();

    final input = html.FileUploadInputElement()..accept = '.csv';
    input.click();

    input.onChange.listen((_) {
      final file = input.files?.first;
      if (file == null) {
        completer.complete(null);
        return;
      }

      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoadEnd.listen((_) {
        final text = reader.result as String;
        try {
          final entries = _parseCsv(text);
          completer.complete(entries);
        } catch (e) {
          completer.completeError(e);
        }
      });
    });

    // Handle cancellation (no file selected)
    Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// Parse CSV text into a list of [RawTableEntry].
  List<RawTableEntry> _parseCsv(String text) {
    final lines = const LineSplitter().convert(text.trim());
    if (lines.length < 2) {
      throw FormatException('CSV must have a header row and at least one data row.');
    }

    // Parse header
    final headers = _parseCsvLine(lines[0]).map((h) => h.trim()).toList();
    if (headers.isEmpty || headers[0] != 'Reffid') {
      throw FormatException('First column must be "Reffid". Is this a valid FMT export?');
    }

    // Build a column index map
    final colIndex = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      colIndex[headers[i]] = i;
    }

    final entries = <RawTableEntry>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = _parseCsvLine(line);
      if (fields.length < headers.length) continue;

      entries.add(RawTableEntry(
        reffid: _safeGet(fields, colIndex['Reffid']),
        date: _safeGet(fields, colIndex['Date']),
        month: _safeGet(fields, colIndex['Month']),
        amount: double.tryParse(_safeGet(fields, colIndex['Amount'])) ?? 0.0,
        modeOfPayment: _safeGet(fields, colIndex['Mode Of Payment']),
        rowDesc: _safeGet(fields, colIndex['Row Desc']),
        rowNote: _safeGet(fields, colIndex['Row Note']),
        entryTimestamp: _safeGet(fields, colIndex['Entry Timestamp']),
        entryUser: _safeGet(fields, colIndex['Entry User']),
        editTimestamp: _safeGet(fields, colIndex['Edit Timestamp']),
        editUser: _safeGet(fields, colIndex['Edit User']),
      ));
    }

    return entries;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Escape a CSV field (wrap in quotes if it contains comma, quote, or newline).
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Parse a single CSV line into fields (handles quoted fields).
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++; // skip next quote
          } else {
            inQuotes = false;
          }
        } else {
          current.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(current.toString());
          current = StringBuffer();
        } else {
          current.write(char);
        }
      }
    }
    fields.add(current.toString());
    return fields;
  }

  /// Safe field access by index.
  String _safeGet(List<String> fields, int? index) {
    if (index == null || index >= fields.length) return '';
    return fields[index].trim();
  }
}
