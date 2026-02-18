import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/raw_table_entry.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'entry_form_screen.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  List<RawTableEntry> _entries = [];
  bool _isLoading = false;
  String _userName = '';
  String? _filterMonth;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadEntries();
  }

  Future<void> _loadUserName() async {
    final name = await _storageService.getUserName();
    setState(() {
      _userName = name ?? 'User';
    });
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entries = await _apiService.getRawTableEntries();
      setState(() {
        _entries = entries;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading entries: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _storageService.clearUserCredentials();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  List<RawTableEntry> get _filteredEntries {
    if (_filterMonth == null) return _entries;
    return _entries.where((e) => e.month == _filterMonth).toList();
  }

  double get _totalAmount {
    return _filteredEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  @override
  Widget build(BuildContext context) {
    final uniqueMonths = _entries.map((e) => e.month).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FMT Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              );
            },
            tooltip: 'User Management',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntries,
            tooltip: 'Refresh',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // User Info Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $_userName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_filteredEntries.length} entries',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    DropdownButton<String?>(
                      value: _filterMonth,
                      hint: const Text('All Months'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Months'),
                        ),
                        ...uniqueMonths.map((month) {
                          return DropdownMenuItem<String?>(
                            value: month,
                            child: Text(month),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterMonth = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  NumberFormat.currency(symbol: '₹', locale: 'en_IN').format(_totalAmount),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Entries List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                    ? const Center(
                        child: Text('No entries found'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEntries,
                        child: ListView.builder(
                          itemCount: _filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _filteredEntries[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(entry.reffid.substring(0, 1)),
                                ),
                                title: Text(entry.rowDesc),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${entry.date} - ${entry.month}'),
                                    Text(
                                      entry.modeOfPayment,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  NumberFormat.currency(symbol: '₹', locale: 'en_IN')
                                      .format(entry.amount),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EntryFormScreen(entry: entry),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadEntries();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EntryFormScreen(),
            ),
          );
          if (result == true) {
            _loadEntries();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
    );
  }
}
