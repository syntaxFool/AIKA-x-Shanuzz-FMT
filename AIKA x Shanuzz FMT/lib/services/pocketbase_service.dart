import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service wrapping PocketBase SDK for the FMT app.
///
/// Handles authentication (email/password), entry CRUD, and user management.
/// Uses [AsyncAuthStore] to persist JWT automatically via shared_preferences.
class PocketBaseService {
  late final PocketBase _pb;
  bool _initialized = false;

  /// Production PocketBase URL (used in release builds).
  static const String _productionUrl = 'https://pb.aika-shuz.fyi';

  /// Local development PocketBase URL.
  static const String _devUrl = 'http://127.0.0.1:8090';

  /// Default URL switches based on build mode.
  static String get _defaultUrl =>
      kReleaseMode ? _productionUrl : _devUrl;

  /// URL of the PocketBase server (set after initialize).
  String get url => _initialized ? _pb.baseUrl : _defaultUrl;

  /// Whether the user has a valid (non-expired) auth session.
  bool get isLoggedIn => _initialized && _pb.authStore.isValid;

  /// Current authenticated user's display name, if logged in.
  String? get userName => _pb.authStore.record?.getStringValue('name');

  /// Current authenticated user's reference ID, if logged in.
  String? get userReffid => _pb.authStore.record?.getStringValue('reffid');

  /// Current authenticated user's PocketBase record ID.
  String? get userId => _pb.authStore.record?.id;

  /// Raw auth store (for advanced use — e.g. checking expiry).
  AuthStore get authStore => _pb.authStore;

  /// Initialize the PocketBase client.
  ///
  /// Must be called once before any other operations (typically in main()).
  /// Pass [url] to override the default (e.g. for production).
  Future<void> initialize({String? url}) async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _pb = PocketBase(
      url ?? _defaultUrl,
      authStore: AsyncAuthStore(
        save: (String data) async => prefs.setString('pb_auth', data),
        initial: prefs.getString('pb_auth'),
      ),
    );

    // If we have a stored token, try to refresh it so the UI knows
    // immediately whether the session is still valid.
    if (_pb.authStore.isValid) {
      try {
        await _pb.collection('users').authRefresh();
      } catch (_) {
        // Token expired — authStore will be cleared automatically.
      }
    }

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Log in with email and password.
  ///
  /// Returns the [RecordModel] on success.
  /// Throws [ClientException] on failure (wrong credentials, network error, etc.).
  Future<RecordModel> login(String email, String password) async {
    final result =
        await _pb.collection('users').authWithPassword(email, password);
    return result.record;
  }

  /// Log out the current user (clears persisted auth state).
  void logout() {
    _pb.authStore.clear();
  }

  // ---------------------------------------------------------------------------
  // Entries – CRUD
  // ---------------------------------------------------------------------------

  /// Fetch all entries, optionally filtered by [month].
  ///
  /// Uses [getFullList] (no pagination) since datasets are small.
  Future<List<RecordModel>> getEntries({String? month}) async {
    if (month != null && month.isNotEmpty) {
      return await _pb
          .collection('entries')
          .getFullList(sort: '-date', filter: 'month = "$month"');
    }
    return await _pb.collection('entries').getFullList(sort: '-date');
  }

  /// Create a new entry and return its [RecordModel].
  Future<RecordModel> createEntry(Map<String, dynamic> body) async {
    return await _pb.collection('entries').create(body: body);
  }

  /// Update an existing entry by its PocketBase [id].
  Future<RecordModel> updateEntry(
      String id, Map<String, dynamic> body) async {
    return await _pb.collection('entries').update(id, body: body);
  }

  /// Delete an entry by its PocketBase [id].
  Future<void> deleteEntry(String id) async {
    await _pb.collection('entries').delete(id);
  }

  // ---------------------------------------------------------------------------
  // Users – admin CRUD (requires superuser rights or relaxed rules)
  // ---------------------------------------------------------------------------

  /// Fetch all users.
  Future<List<RecordModel>> getUsers() async {
    return await _pb.collection('users').getFullList();
  }

  /// Create a new auth user.
  ///
  /// The [body] must include at least `email`, `password`, and `passwordConfirm`.
  Future<RecordModel> createUser(Map<String, dynamic> body) async {
    return await _pb.collection('users').create(body: body);
  }

  /// Update a user record.
  Future<RecordModel> updateUser(
      String id, Map<String, dynamic> body) async {
    return await _pb.collection('users').update(id, body: body);
  }

  /// Delete a user record.
  Future<void> deleteUser(String id) async {
    await _pb.collection('users').delete(id);
  }
}
