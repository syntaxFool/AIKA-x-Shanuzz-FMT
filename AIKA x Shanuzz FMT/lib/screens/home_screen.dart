import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/raw_table_entry.dart';
import '../services/pocketbase_service.dart';
import 'entry_form_screen.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final PocketBaseService pbService;

  const HomeScreen({super.key, required this.pbService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CsvService _csvService = CsvService();

  List<RawTableEntry> _entries = [];
  bool _isLoading = false;
  String _userName = '';
  String? _filterMonth;

  @override
  void initState() {
    super.initState();
    _userName = widget.pbService.userName ?? 'User';
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);

    try {
      final records = await widget.pbService.getEntries(month: _filterMonth);
      if (!mounted) return;
      setState(() {
        _entries = records.map((r) => RawTableEntry.fromRecord(r)).toList();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    widget.pbService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LoginScreen(pbService: widget.pbService),
      ),
    );
  }

  Future<void> _exportCsv() async {
    try {
      final csv = _csvService.entriesToCsv(_entries);
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _csvService.downloadCsv(csv, 'fmt-export-$dateStr.csv');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importCsv() async {
    try {
      final entries = await _csvService.pickAndParseCsv();
      if (entries == null || entries.isEmpty || !mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import CSV'),
          content: Text(
            'Found ${entries.length} entries. Import them now?\n\n'
            'Duplicates will be added as new entries.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      var successCount = 0;
      var failCount = 0;
      final userName = widget.pbService.userName ?? 'Import';
      final timestamp = DateTime.now().toIso8601String();

      for (final entry in entries) {
        try {
          await widget.pbService.createEntry({
            ...entry.toRecordBody(),
            'entryUser': userName,
            'entryTimestamp': timestamp,
            'editUser': userName,
            'editTimestamp': timestamp,
          });
          successCount++;
        } catch (_) {
          failCount++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $successCount entries' +
                (failCount > 0 ? ' ($failCount failed)' : ''),
          ),
          backgroundColor:
              failCount > 0 ? Colors.orange : Colors.green,
        ),
      );

      _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      final dateTime = DateTime.parse(dateString);
      final format = DateFormat('dd MMM yyyy');
      return format.format(dateTime);
    } catch (e) {
      return dateString.split('T')[0];
    }
  }

  String _formatMonth(String monthString) {
    try {
      if (monthString.contains('T') || monthString.contains('-')) {
        final dateTime = DateTime.parse(monthString);
        final format = DateFormat('MMMM yyyy');
        return format.format(dateTime);
      }
      return monthString;
    } catch (e) {
      return monthString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uniqueMonths = _entries.map((e) => e.month).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FMT Dashboard'),
        actions: [
          if (widget.pbService.isAdmin)
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        UserManagementScreen(pbService: widget.pbService),
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
                  launchUrl(
                    Uri.parse(
                        'https://docs.google.com/spreadsheets/d/1e2Zt5EsUvdAXzlHigNwsT8EmytJXV7mXwuP1vY-378Q/edit?usp=sharing'),
                    webOnlyWindowName: '_blank',
                  );
                  break;
                case 'refresh':
                  launchUrl(Uri.base, webOnlyWindowName: '_self');
                  break;
                case 'logout':
                  _logout();
                  break;
                case 'export_csv':
                  _exportCsv();
                  break;
                case 'import_csv':
                  _importCsv();
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
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(
                      Icons.file_download,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Export CSV',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'import_csv',
                child: Row(
                  children: [
                    Icon(
                      Icons.file_upload,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Import CSV',
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
                      const Row(
                        children: [
                          Text(
                            '💰',
                            style: TextStyle(fontSize: 24),
                          ),
                          SizedBox(width: 12),
                          Text(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '📋',
                              style: TextStyle(fontSize: 12),
                            ),
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
                    NumberFormat.currency(symbol: '₹', locale: 'en_IN')
                        .format(_totalAmount),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
                      hint: const Row(
                        children: [
                          Text('📅', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 8),
                          Text('All Months'),
                        ],
                      ),
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Text('▼', style: TextStyle(fontSize: 12)),
                      selectedItemBuilder: (context) {
                        return [
                          const Row(
                            children: [
                              Text('📅', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 8),
                              Text('All Months'),
                            ],
                          ),
                          ...uniqueMonths.map((month) {
                            return Row(
                              children: [
                                const Text('📆', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Text(_formatMonth(month)),
                              ],
                            );
                          }),
                        ];
                      },
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              Text('📅', style: TextStyle(fontSize: 14)),
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
                                Text('📆', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Text(_formatMonth(month)),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterMonth = value;
                        });
                        _loadEntries();
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
                                  NumberFormat.currency(
                                    symbol: '₹',
                                    locale: 'en_IN',
                                  ).format(entry.amount),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: widget.pbService.isAdmin
                                    ? () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EntryFormScreen(
                                              pbService: widget.pbService,
                                              entry: entry,
                                            ),
                                          ),
                                        );
                                        if (result == true) {
                                          _loadEntries();
                                        }
                                      }
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.pbService.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EntryFormScreen(
                        pbService: widget.pbService),
                  ),
                );
                if (result == true) {
                  _loadEntries();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            )
          : null,
    );
  }
}
