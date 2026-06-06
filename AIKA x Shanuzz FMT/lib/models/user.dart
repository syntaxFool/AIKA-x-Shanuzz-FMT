import 'package:pocketbase/pocketbase.dart';

class User {
  final String? pbId; // PocketBase record ID
  final String reffid;
  final String name;
  final String email; // replaces old 'token' — maps to PocketBase email

  User({
    this.pbId,
    required this.reffid,
    required this.name,
    this.email = '',
  });

  /// Create from a PocketBase [RecordModel].
  factory User.fromRecord(RecordModel record) {
    return User(
      pbId: record.id,
      reffid: record.getStringValue('reffid'),
      name: record.getStringValue('name'),
      email: record.getStringValue('email'),
    );
  }

  /// Body map for PocketBase create/update.
  Map<String, dynamic> toRecordBody() {
    return {
      'reffid': reffid,
      'name': name,
      'email': email,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      reffid: json['Reffid'] ?? '',
      name: json['Name'] ?? '',
      email: json['Token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Reffid': reffid,
      'Name': name,
      'Token': email,
    };
  }

  User copyWith({
    String? pbId,
    String? reffid,
    String? name,
    String? email,
  }) {
    return User(
      pbId: pbId ?? this.pbId,
      reffid: reffid ?? this.reffid,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }
}
