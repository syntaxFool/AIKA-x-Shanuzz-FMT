import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import '../models/raw_table_entry.dart';
import '../models/user.dart';

class ApiService {
  // Use Netlify Function proxy for CORS support
  static const String _baseUrl =
      '/.netlify/functions/apps-script-proxy';

  final StorageService _storageService = StorageService();

  Future<String?> _getToken() async {
    return await _storageService.getToken();
  }

  // Raw Table Operations
  Future<List<RawTableEntry>> getRawTableEntries() async {
    try {
      final token = await _getToken() ?? '';
      final response = await http.get(
        Uri.parse('$_baseUrl?action=getRawTable&token=$token'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<dynamic> entries = data['data'];
          return entries.map((e) => RawTableEntry.fromJson(e)).toList();
        }
      }
      throw Exception('Failed to load raw table entries');
    } catch (e) {
      print('Error getting raw table entries: $e');
      rethrow;
    }
  }

  Future<bool> addRawTableEntry(RawTableEntry entry) async {
    try {
      final token = await _getToken() ?? '';
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'addRawTable',
          'token': token,
          'data': entry.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error adding raw table entry: $e');
      return false;
    }
  }

  Future<bool> updateRawTableEntry(String reffid, RawTableEntry entry) async {
    try {
      final token = await _getToken() ?? '';
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'updateRawTable',
          'token': token,
          'reffid': reffid,
          'data': entry.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updating raw table entry: $e');
      return false;
    }
  }

  Future<bool> deleteRawTableEntry(String reffid) async {
    try {
      final token = await _getToken() ?? '';
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'deleteRawTable',
          'token': token,
          'reffid': reffid,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting raw table entry: $e');
      return false;
    }
  }

  // User Operations
  Future<List<User>> getUsers() async {
    try {
      final token = await _getToken() ?? '';
      final response = await http.get(
        Uri.parse('$_baseUrl?action=getUsers&token=$token'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<dynamic> users = data['data'];
          return users.map((e) => User.fromJson(e)).toList();
        }
      }
      throw Exception('Failed to load users');
    } catch (e) {
      print('Error getting users: $e');
      rethrow;
    }
  }

  Future<User?> getUserByToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=getUserByToken&token=$token'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return User.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting user by token: $e');
      return null;
    }
  }

  Future<bool> addUser(User user) async {
    try {
      final token = await _getToken() ?? '';
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'addUser',
          'token': token,
          'data': user.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error adding user: $e');
      return false;
    }
  }

  Future<bool> updateUser(String reffid, User user) async {
    try {
      final token = await _getToken() ?? '';
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'updateUser',
          'token': token,
          'reffid': reffid,
          'data': user.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String reffid) async {
    try {
      final token = await _getToken() ?? '';
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'deleteUser',
          'token': token,
          'reffid': reffid,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }
}
