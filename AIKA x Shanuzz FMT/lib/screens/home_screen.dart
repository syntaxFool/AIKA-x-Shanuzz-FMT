import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
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

  String _formatDate(String dateString) {
    try {
      // Parse ISO date string (e.g., "2026-01-31T18:30:00.000Z")
      final dateTime = DateTime.parse(dateString);
      final format = DateFormat('dd MMM yyyy');
      return format.format(dateTime);
    } catch (e) {
      // If parsing fails, return just the date part
      return dateString.split('T')[0];
    }
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            offset: const Offset(0, 50),
            onSelected: (value) {
              switch (value) {
                case 'sheet':
                  html.window.open(
                    'https://docs.google.com/spreadsheets/d/1e2Zt5EsUvdAXzlHigNwsT8EmytJXV7mXwuP1vY-378Q/edit?usp=sharing',
                    '_blank',
                  );
                  break;
                case 'refresh':
                  html.window.location.reload();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'sheet',
                child: Row(
                  children: [
                    Icon(
                      Icons.table_chart,
                      size: 20,
                      color: Color(0xFF388E3C),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Sheet',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Hard Refresh',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      size: 20,
                      color: Color(0xFFD32F2F),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
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
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_filteredEntries.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    NumberFormat.currency(symbol: '₹', locale: 'en_IN').format(_totalAmount),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: DropdownButton<String?>(
                      value: _filterMonth,
                      hint: Row(
                        children: const [
                          Icon(Icons.calendar_month, size: 16),
                          SizedBox(width: 8),
                          Text('All Months'),
                        ],
                      ),
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 24),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month, size: 16),
                              SizedBox(width: 8),
                              Text('All Months'),
                            ],
                          ),
                        ),
                        ...uniqueMonths.map((month) {
                          return DropdownMenuItem<String?>(
                            value: month,
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(month),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterMonth = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
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
                                    Text(_formatDate(entry.date)),
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
