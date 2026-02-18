import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/raw_table_entry.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class EntryFormScreen extends StatefulWidget {
  final RawTableEntry? entry;

  const EntryFormScreen({super.key, this.entry});

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  late TextEditingController _reffidController;
  late TextEditingController _dateController;
  late TextEditingController _monthController;
  late TextEditingController _amountController;
  late TextEditingController _modeOfPaymentController;
  late TextEditingController _rowDescController;
  late TextEditingController _rowNoteController;
  
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  List<String> _descriptionSuggestions = [];

  @override
  void initState() {
    super.initState();
    _reffidController = TextEditingController(text: widget.entry?.reffid ?? _generateReffid());
    _dateController = TextEditingController(text: widget.entry?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    _monthController = TextEditingController(text: widget.entry?.month ?? DateFormat('MMMM yyyy').format(DateTime.now()));
    _amountController = TextEditingController(text: widget.entry?.amount.toString() ?? '');
    _modeOfPaymentController = TextEditingController(text: widget.entry?.modeOfPayment ?? '');
    _rowDescController = TextEditingController(text: widget.entry?.rowDesc ?? '');
    _rowNoteController = TextEditingController(text: widget.entry?.rowNote ?? '');
    _loadDescriptionSuggestions();
  }

  Future<void> _loadDescriptionSuggestions() async {
    try {
      final entries = await _apiService.getRawTableEntries();
      final descriptions = entries
          .map((e) => e.rowDesc)
          .where((desc) => desc.isNotEmpty)
          .toSet()
          .toList();
      setState(() {
        _descriptionSuggestions = descriptions;
      });
    } catch (e) {
      // Silently fail - suggestions are optional
      print('Failed to load description suggestions: $e');
    }
  }

  String _generateReffid() {
    return 'REF${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _reffidController.dispose();
    _dateController.dispose();
    _monthController.dispose();
    _amountController.dispose();
    _modeOfPaymentController.dispose();
    _rowDescController.dispose();
    _rowNoteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        _monthController.text = DateFormat('MMMM yyyy').format(picked);
      });
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userName = await _storageService.getUserName() ?? 'Unknown';
      final timestamp = DateTime.now().toIso8601String();

      final entry = RawTableEntry(
        reffid: _reffidController.text,
        date: _dateController.text,
        month: _monthController.text,
        amount: double.parse(_amountController.text),
        modeOfPayment: _modeOfPaymentController.text,
        rowDesc: _rowDescController.text,
        rowNote: _rowNoteController.text,
        entryTimestamp: widget.entry?.entryTimestamp ?? timestamp,
        entryUser: widget.entry?.entryUser ?? userName,
        editTimestamp: timestamp,
        editUser: userName,
      );

      bool success;
      if (widget.entry == null) {
        success = await _apiService.addRawTableEntry(entry);
      } else {
        success = await _apiService.updateRawTableEntry(widget.entry!.reffid, entry);
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.entry == null ? 'Entry added successfully' : 'Entry updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save entry'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteEntry() async {
    if (widget.entry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _apiService.deleteRawTableEntry(widget.entry!.reffid);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete entry'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Entry' : 'Add Entry'),
        actions: isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _isLoading ? null : _deleteEntry,
                  tooltip: 'Delete',
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _selectDate,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _modeOfPaymentController.text.isEmpty ? null : _modeOfPaymentController.text,
                decoration: const InputDecoration(
                  labelText: 'Mode of Payment',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _modeOfPaymentController.text = value;
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select mode of payment';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _rowDescController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _descriptionSuggestions.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _rowDescController.text = selection;
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  return TextFormField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      hintText: 'Start typing for suggestions...',
                    ),
                    maxLines: 2,
                    onChanged: (value) {
                      _rowDescController.text = value;
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter description';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rowNoteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveEntry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'Update Entry' : 'Add Entry',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
