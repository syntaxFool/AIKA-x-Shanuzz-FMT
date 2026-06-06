# PocketBase Migration Implementation Plan

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement this plan task-by-task.

**Goal:** Replace Google Sheets + Apps Script backend with a self-hosted PocketBase backend, including email/password auth, for the AIKA x Shanuzz FMT Flutter web app.

**Architecture:** PocketBase runs as a single Go binary in `noc/`, storing data in embedded SQLite. The Flutter web app communicates directly with PocketBase's REST API using the `pocketbase` Dart SDK. The Netlify proxy, Apps Script, and Google Sheets are removed. Authentication switches from token strings to PocketBase's native email/password + JWT.

**Tech Stack:** PocketBase (Go binary), `pocketbase` Dart SDK 0.22+, `shared_preferences` (already in project), Flutter Web PWA, Netlify hosting (frontend only).

**Self-hosting path:** `noc/` directory at project root. PocketBase serves on `http://127.0.0.1:8090` locally. For production, the binary runs on a server and is exposed behind a reverse proxy or direct.

---

## Phase 1: PocketBase Setup (Server-side)

### Task 1: Download and Prepare PocketBase

**TDD scenario:** No tests needed — infrastructure setup.

**Files:**
- Create: `noc/` directory structure

**Step 1: Download PocketBase binary**

```powershell
# On Windows (PowerShell) — the dev environment:
mkdir -Force noc
cd noc
Invoke-WebRequest -Uri "https://github.com/pocketbase/pocketbase/releases/latest/download/pocketbase_0.25.2_windows_amd64.zip" -OutFile pocketbase.zip
Expand-Archive pocketbase.zip -DestinationPath .
del pocketbase.zip
```

**Step 2: Verify binary works**

```powershell
.\pocketbase.exe --version
```

Expected: Prints version info.

**Step 3: Create data directory and start PocketBase**

```powershell
.\pocketbase.exe serve --dir=pb_data --http=127.0.0.1:8090
```

**Step 4: Commit**

```bash
git add noc/
# Note: binary is too large for git; add to .gitignore
echo "noc/pocketbase.exe" >> .gitignore
echo "noc/pb_data/" >> .gitignore
git add .gitignore
git commit -m "chore: add PocketBase binary and gitignore exclusions"
```
```

### Task 2: Create Admin Account and Collections

**TDD scenario:** No tests needed — manual setup via Admin UI.

**Files:**
- Create: collection schemas (via Admin UI or JS migration)

**Step 1: Open Admin UI at `http://127.0.0.1:8090/_/`**

Create the admin account when prompted (e.g., `admin@fmt.local` / secure password).

**Step 2: Configure the built-in `users` auth collection**

PocketBase ships with a `users` collection. Add custom fields:
- `reffid` — type `text`, required
- `name` — type `text`, required

Configure auth rules:
- **authRule:** `""` (empty = allow any user to authenticate)
- **manageRule:** `""` (allow self-management)
- For admin-only user management, we'll use the superuser token for creating/deleting users

**Step 3: Create `entries` base collection**

Fields:
| Name | Type | Required | Options |
|------|------|----------|---------|
| `reffid` | text | yes | |
| `date` | date | yes | |
| `month` | text | yes | |
| `amount` | number | yes | |
| `modeOfPayment` | select | yes | Options: Cash, Card, UPI, Bank Transfer, Other |
| `rowDesc` | text | yes | |
| `rowNote` | text | no | |
| `entryTimestamp` | date | no | |
| `entryUser` | text | no | |
| `editTimestamp` | date | no | |
| `editUser` | text | no | |

API rules:
- **listRule:** `@request.auth.id != ""` (any authenticated user can list)
- **viewRule:** `@request.auth.id != ""`
- **createRule:** `@request.auth.id != ""`
- **updateRule:** `@request.auth.id != ""`
- **deleteRule:** `@request.auth.id != ""`

**Step 4: (Optional) Create a seed admin user**

Add a test user via Admin UI under the `users` collection:
- email: `test@fmt.local`
- password: `test1234`
- name: `Test User`
- reffid: `USER001`

**Step 5: Commit the generated migration file**

```bash
# PocketBase auto-generates migrations in pb_migrations/
git add noc/pb_migrations/
git commit -m "feat: add PocketBase collection schemas and seed user"
```
```

---

## Phase 2: Flutter Integration

### Task 3: Add PocketBase SDK and Create Service

**TDD scenario:** New feature — full TDD cycle.

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/services/pocketbase_service.dart`
- Create: `test/services/pocketbase_service_test.dart`

**Step 1: Add dependency and remove unused ones**

```yaml
# In pubspec.yaml, add:
  pocketbase: ^0.22.0

# Remove if desired (no longer needed):
  http: ^1.1.0    # Keep for now, remove in cleanup task
```

Run: `flutter pub get`

**Step 2: Write the failing test for PocketBaseService**

```dart
// test/services/pocketbase_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('PocketBaseService', () {
    test('creates client with correct URL', () {
      // Test will be written after service is created
    });
  });
}
```

**Step 3: Create PocketBaseService**

```dart
// lib/services/pocketbase_service.dart
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketBaseService {
  late final PocketBase pb;
  bool _initialized = false;

  // Change this to your production URL when deployed
  static const String _defaultUrl = 'http://127.0.0.1:8090';

  Future<void> initialize({String? url}) async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    pb = PocketBase(
      url ?? _defaultUrl,
      authStore: AsyncAuthStore(
        save: (String data) async => prefs.setString('pb_auth', data),
        initial: prefs.getString('pb_auth'),
      ),
    );

    _initialized = true;
  }

  bool get isLoggedIn => pb.authStore.isValid;

  String? get userId => pb.authStore.record?.id;
  String? get userName => pb.authStore.record?.getStringValue('name');
  String? get userReffid => pb.authStore.record?.getStringValue('reffid');

  // --- Auth ---
  Future<RecordModel> login(String email, String password) async {
    final result = await pb.collection('users').authWithPassword(email, password);
    return result.record;
  }

  Future<void> logout() {
    pb.authStore.clear();
    return Future.value();
  }

  // --- Entries ---
  Future<List<RecordModel>> getEntries({String? month}) async {
    final filter = month != null ? 'month = "$month"' : null;
    final result = await pb.collection('entries').getList(
      sort: '-date',
      filter: filter,
      perPage: 500,
    );
    return result.items;
  }

  Future<RecordModel> createEntry(Map<String, dynamic> body) async {
    return await pb.collection('entries').create(body: body);
  }

  Future<RecordModel> updateEntry(String id, Map<String, dynamic> body) async {
    return await pb.collection('entries').update(id, body: body);
  }

  Future<void> deleteEntry(String id) async {
    await pb.collection('entries').delete(id);
  }

  // --- Users ---
  Future<List<RecordModel>> getUsers() async {
    final result = await pb.collection('users').getList(perPage: 100);
    return result.items;
  }

  Future<RecordModel> createUser(Map<String, dynamic> body) async {
    return await pb.collection('users').create(body: body);
  }

  Future<RecordModel> updateUser(String id, Map<String, dynamic> body) async {
    return await pb.collection('users').update(id, body: body);
  }

  Future<void> deleteUser(String id) async {
    await pb.collection('users').delete(id);
  }
}
```

**Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/pocketbase_service.dart
git commit -m "feat: add PocketBaseService with auth and CRUD"
```
```

### Task 4: Update Models for PocketBase Record Compatibility

**TDD scenario:** Modifying tested code — run existing tests first (none exist, write new).

**Files:**
- Modify: `lib/models/raw_table_entry.dart`
- Modify: `lib/models/user.dart`

**Step 1: Add `fromRecord` factory to RawTableEntry**

```dart
// Add to lib/models/raw_table_entry.dart
factory RawTableEntry.fromRecord(RecordModel record) {
  return RawTableEntry(
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

/// Returns the PocketBase record ID (null for new entries)
String? get pbId => null; // Set externally from RecordModel.id
```

**Step 2: Add `toRecordBody()` method**

```dart
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
```

**Step 3: Add `fromRecord` factory to User**

```dart
// Add to lib/models/user.dart
import 'package:pocketbase/pocketbase.dart';

factory User.fromRecord(RecordModel record) {
  return User(
    reffid: record.getStringValue('reffid'),
    name: record.getStringValue('name'),
    token: record.getStringValue('email'), // email as the identifier
  );
}
```

**Step 4: Commit**

```bash
git add lib/models/raw_table_entry.dart lib/models/user.dart
git commit -m "feat: add PocketBase RecordModel converters to models"
```
```

### Task 5: Rewrite Login Screen for Email/Password

**TDD scenario:** Modifying tested code — run existing tests first.

**Files:**
- Modify: `lib/screens/login_screen.dart`
- Modify: `lib/main.dart`

**Step 1: Add PocketBaseService provider at app root**

```dart
// lib/main.dart — wrap MaterialApp with FutureBuilder for PB init
class MyApp extends StatelessWidget {
  final PocketBaseService _pbService = PocketBaseService();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _pbService.initialize(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SplashScreen();
        return MaterialApp(
          // ... existing
          home: SplashScreen(pbService: _pbService),
        );
      },
    );
  }
}
```

**Step 2: Rewrite login screen**

Replace token TextField with email + password TextFields.
The `_login()` method changes from `getUserByToken()` to:

```dart
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    await widget.pbService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  } on ClientException catch (e) {
    // PocketBase returns ClientException for auth failures
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.response['message'] ?? 'Invalid credentials'}'),
              backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Step 3: Pass PocketBaseService to LoginScreen and HomeScreen**

Use constructor injection — pass `pbService` to each screen that needs it.

**Step 4: Commit**

```bash
git add lib/main.dart lib/screens/login_screen.dart
git commit -m "feat: replace token login with PocketBase email/password auth"
```
```

### Task 6: Update Home Screen for PocketBase

**TDD scenario:** Modifying tested code.

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Replace ApiService with PocketBaseService**

```dart
// Remove:
// final ApiService _apiService = ApiService();
// final StorageService _storageService = StorageService();

// Add:
final PocketBaseService _pbService; // via constructor

String _userName = '';
```

**Step 2: Update _loadUserName**

```dart
Future<void> _loadUserName() async {
  setState(() {
    _userName = widget.pbService.userName ?? 'User';
  });
}
```

**Step 3: Update _loadEntries**

```dart
Future<void> _loadEntries() async {
  setState(() => _isLoading = true);
  try {
    final records = await widget.pbService.getEntries(month: _filterMonth);
    setState(() {
      _entries = records.map((r) => RawTableEntry.fromRecord(r)).toList();
    });
  } catch (e) {
    // show snackbar error
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Step 4: Update _logout**

```dart
Future<void> _logout() async {
  await widget.pbService.logout();
  if (!mounted) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (context) => const LoginScreen()),
  );
}
```

**Step 5: Store PB record ID for edit/delete**

Entries now need their PocketBase `id` stored. Extend RawTableEntry to hold it, or create a wrapper.

Simplest approach: store a parallel `Map<String, String>` of reffid → pbId.

```dart
final Map<String, String> _pbIds = {};
// After loading:
_pbIds.clear();
for (final record in records) {
  _pbIds[record.getStringValue('reffid')] = record.id;
}
```

**Step 6: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: update HomeScreen to use PocketBaseService"
```
```

### Task 7: Update Entry Form Screen for PocketBase CRUD

**TDD scenario:** Modifying tested code.

**Files:**
- Modify: `lib/screens/entry_form_screen.dart`

**Step 1: Replace ApiService + StorageService with PocketBaseService**

Pass `pbService` via constructor. Get current user from `pbService.userName`.

**Step 2: Update _saveEntry**

```dart
Future<void> _saveEntry() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);

  try {
    final userName = widget.pbService.userName ?? 'Unknown';
    final timestamp = DateTime.now().toIso8601String();

    final body = {
      'reffid': _reffidController.text,
      'date': _dateController.text,
      'month': _monthController.text,
      'amount': double.parse(_amountController.text),
      'modeOfPayment': _modeOfPaymentController.text,
      'rowDesc': _rowDescController.text,
      'rowNote': _rowNoteController.text,
      'entryTimestamp': widget.entry?.entryTimestamp ?? timestamp,
      'entryUser': widget.entry?.entryUser ?? userName,
      'editTimestamp': timestamp,
      'editUser': userName,
    };

    if (widget.entry == null) {
      await widget.pbService.createEntry(body);
    } else {
      final pbId = widget.pbService.getEntryPbId(widget.entry!.reffid);
      await widget.pbService.updateEntry(pbId!, body);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.entry == null ? 'Added' : 'Updated'),
              backgroundColor: Colors.green),
    );
    Navigator.of(context).pop(true);
  } on ClientException catch (e) {
    // handle error
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Step 3: Update _deleteEntry**

```dart
final pbId = widget.pbService.getEntryPbId(widget.entry!.reffid);
await widget.pbService.deleteEntry(pbId!);
```

**Step 4: Commit**

```bash
git add lib/screens/entry_form_screen.dart
git commit -m "feat: update EntryFormScreen to use PocketBase CRUD"
```
```

### Task 8: Update User Management Screen for PocketBase

**TDD scenario:** Modifying tested code.

**Files:**
- Modify: `lib/screens/user_management_screen.dart`

**Step 1: Replace ApiService with PocketBaseService**

**Step 2: Update _loadUsers**

```dart
final records = await widget.pbService.getUsers();
_users = records.map((r) => User.fromRecord(r)).toList();
// Store PB ids for edit/delete
```

**Step 3: Update user create/edit dialog**

Creating a PocketBase auth user requires email + password + passwordConfirm:

```dart
await widget.pbService.createUser({
  'email': emailController.text,
  'password': passwordController.text,
  'passwordConfirm': passwordController.text,
  'name': nameController.text,
  'reffid': reffidController.text,
});
```

**Step 4: Handle user management permissions**

PocketBase users can only be created by superusers or via admin API. Options:
- Use superuser credentials for user management (add superuser email/password to PocketBaseService)
- Or: relax `createRule` on users collection to allow self-registration (simpler for this tool)

Simplest: create users as an admin function. Add `_superuserLogin()` to PocketBaseService that the user management screen calls before admin operations.

**Step 5: Commit**

```bash
git add lib/screens/user_management_screen.dart
git commit -m "feat: update UserManagementScreen to use PocketBase"
```
```

---

## Phase 3: Cleanup and Configuration

### Task 9: Remove Old Backend Files

**TDD scenario:** Trivial change — use judgment.

**Files:**
- Delete: `apps-script/Code.gs`
- Delete: `netlify/functions/apps-script-proxy.js`
- Delete: `lib/services/api_service.dart`
- Modify: `lib/services/storage_service.dart` — remove or simplify (PB handles auth persistence)
- Delete: `docs/APPS_SCRIPT_DEPLOYMENT.md`

**Step 1: Remove old files and update netlify.toml**

Remove the `publish` and `command` directives from netlify.toml since PocketBase handles the backend:

```toml
# netlify.toml — simplified
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

**Step 2: Commit**

```bash
git rm apps-script/Code.gs netlify/functions/apps-script-proxy.js lib/services/api_service.dart docs/APPS_SCRIPT_DEPLOYMENT.md
git add netlify.toml
git commit -m "chore: remove old Apps Script backend and Netlify proxy"
```
```

### Task 10: Configure CORS and Environment Variables

**TDD scenario:** No tests needed — configuration.

**Files:**
- Modify: `lib/services/pocketbase_service.dart`
- Modify: `web/index.html` or `lib/main.dart`

**Step 1: Configure PocketBase CORS**

PocketBase Admin UI → Settings → Application:
- Allow origins: add your Netlify domain (e.g., `https://aika-shanuzz-fmt.netlify.app`)
- For local dev: `http://localhost:*`

**Step 2: Make PocketBase URL configurable**

```dart
// In main.dart, determine the URL:
// - If running locally: http://127.0.0.1:8090
// - If in production: use environment or hardcode the server URL
const String pbUrl = kReleaseMode
    ? 'https://your-server.com'  // Production PocketBase URL
    : 'http://127.0.0.1:8090';   // Local development
```

**Step 3: Create a `noc/start.sh` and `noc/start.ps1` script**

```bash
# noc/start.sh
./pocketbase serve --dir=pb_data --http=0.0.0.0:8090
```

```powershell
# noc/start.ps1
.\pocketbase.exe serve --dir=pb_data --http=0.0.0.0:8090
```

**Step 4: Commit**

```bash
git add noc/start.sh noc/start.ps1 lib/services/pocketbase_service.dart
git commit -m "chore: add CORS config, environment URL, and start scripts"
```
```

---

## Optional Enhancements (out of scope, add later)

- Real-time list updates via `pb.collection('entries').subscribe()`
- Data migration script: read Google Sheets, push to PocketBase API
- Proper Provider/InheritedWidget for PocketBaseService singleton
- Dark mode toggle in PocketBase Admin UI settings
- Export existing Google Sheets data to JSON → import into PocketBase
```

