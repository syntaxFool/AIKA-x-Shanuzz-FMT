import 'package:pocketbase/pocketbase.dart';

class RawTableEntry {
  final String? pbId; // PocketBase record ID (null for new entries)
  final String reffid;
  final String date;
  final String month;
  final double amount;
  final String modeOfPayment;
  final String rowDesc;
  final String rowNote;
  final String entryTimestamp;
  final String entryUser;
  final String editTimestamp;
  final String editUser;

  RawTableEntry({
    this.pbId,
    required this.reffid,
    required this.date,
    required this.month,
    required this.amount,
    required this.modeOfPayment,
    required this.rowDesc,
    required this.rowNote,
    required this.entryTimestamp,
    required this.entryUser,
    required this.editTimestamp,
    required this.editUser,
  });

  /// Create from a PocketBase [RecordModel].
  factory RawTableEntry.fromRecord(RecordModel record) {
    return RawTableEntry(
      pbId: record.id,
      reffid: record.getStringValue('reffid'),
      date: record.getStringValue('date'),
      month: record.getStringValue('month'),
      amount: record.getDoubleValue('amount'),
      modeOfPayment: record.getStringValue('modeOfPayment'),
      rowDesc: record.getStringValue('rowDesc'),
      rowNote: record.getStringValue('rowNote'),
      entryTimestamp: record.getStringValue('entryTimestamp'),
      entryUser: record.getStringValue('entryUser'),
      editTimestamp: record.getStringValue('editTimestamp'),
      editUser: record.getStringValue('editUser'),
    );
  }

  /// Convert to a body map for PocketBase create/update.
  Map<String, dynamic> toRecordBody() {
    return {
      'reffid': reffid,
      'date': date,
      'month': month,
      'amount': amount,
      'modeOfPayment': modeOfPayment,
      'rowDesc': rowDesc,
      'rowNote': rowNote,
      'entryTimestamp': entryTimestamp,
      'entryUser': entryUser,
      'editTimestamp': editTimestamp,
      'editUser': editUser,
    };
  }

  /// Legacy: create from a Google Sheets JSON row.
  factory RawTableEntry.fromJson(Map<String, dynamic> json) {
    return RawTableEntry(
      reffid: json['Reffid'] ?? '',
      date: json['Date'] ?? '',
      month: json['Month'] ?? '',
      amount: double.tryParse(json['Amount']?.toString() ?? '0') ?? 0.0,
      modeOfPayment: json['Mode Of Payment'] ?? '',
      rowDesc: json['Row Desc'] ?? '',
      rowNote: json['Row Note'] ?? '',
      entryTimestamp: json['Entry Timestamp'] ?? '',
      entryUser: json['Entry User'] ?? '',
      editTimestamp: json['Edit Timestamp'] ?? '',
      editUser: json['Edit User'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Reffid': reffid,
      'Date': date,
      'Month': month,
      'Amount': amount,
      'Mode Of Payment': modeOfPayment,
      'Row Desc': rowDesc,
      'Row Note': rowNote,
      'Entry Timestamp': entryTimestamp,
      'Entry User': entryUser,
      'Edit Timestamp': editTimestamp,
      'Edit User': editUser,
    };
  }

  RawTableEntry copyWith({
    String? pbId,
    String? reffid,
    String? date,
    String? month,
    double? amount,
    String? modeOfPayment,
    String? rowDesc,
    String? rowNote,
    String? entryTimestamp,
    String? entryUser,
    String? editTimestamp,
    String? editUser,
  }) {
    return RawTableEntry(
      pbId: pbId ?? this.pbId,
      reffid: reffid ?? this.reffid,
      date: date ?? this.date,
      month: month ?? this.month,
      amount: amount ?? this.amount,
      modeOfPayment: modeOfPayment ?? this.modeOfPayment,
      rowDesc: rowDesc ?? this.rowDesc,
      rowNote: rowNote ?? this.rowNote,
      entryTimestamp: entryTimestamp ?? this.entryTimestamp,
      entryUser: entryUser ?? this.entryUser,
      editTimestamp: editTimestamp ?? this.editTimestamp,
      editUser: editUser ?? this.editUser,
    );
  }
}
