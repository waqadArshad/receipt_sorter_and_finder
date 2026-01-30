import 'package:flutter/material.dart';
import '../models/filter_criteria.dart';
import '../db/database_helper.dart';

class FilterScreen extends StatefulWidget {
  final FilterCriteria initialFilters;

  const FilterScreen({super.key, required this.initialFilters});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late List<String> _selectedTypes;
  late List<String> _selectedMerchants;
  DateTime? _startDate;
  DateTime? _endDate;
  
  List<String> _availableMerchants = [];
  final List<String> _availableTypes = [
    'pos_receipt',
    'transfer_receipt', // Added missing type!
    'digital_receipt',
    'invoice',
    'bank_statement',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _selectedTypes = List.from(widget.initialFilters.documentTypes ?? []);
    _selectedMerchants = List.from(widget.initialFilters.merchants ?? []);
    _startDate = widget.initialFilters.startDate;
    _endDate = widget.initialFilters.endDate;
    
    _loadMerchants();
  }

  Future<void> _loadMerchants() async {
    final merchants = await DatabaseHelper.instance.getDistinctMerchants();
    setState(() {
      _availableMerchants = merchants;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        actions: [
          TextButton(
            onPressed: () {
              // Reset
              setState(() {
                _selectedTypes = [];
                _selectedMerchants = [];
                _startDate = null;
                _endDate = null;
              });
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Date Range'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text(_startDate == null 
                      ? 'Start Date' 
                      : '${_startDate!.year}-${_startDate!.month}-${_startDate!.day}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text(_endDate == null 
                      ? 'End Date' 
                      : '${_endDate!.year}-${_endDate!.month}-${_endDate!.day}'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Document Type'),
            Wrap(
              spacing: 8.0,
              children: _availableTypes.map((type) {
                final isSelected = _selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type.replaceAll('_', ' ').toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTypes.add(type);
                      } else {
                        _selectedTypes.remove(type);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('Merchant'),
            if (_availableMerchants.isEmpty)
              const Text('No merchants found yet.', style: TextStyle(color: Colors.grey)),
            Wrap(
              spacing: 8.0,
              children: _availableMerchants.map((merchant) {
                final isSelected = _selectedMerchants.contains(merchant);
                return FilterChip(
                  label: Text(merchant),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedMerchants.add(merchant);
                      } else {
                        _selectedMerchants.remove(merchant);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            final criteria = FilterCriteria(
              documentTypes: _selectedTypes.isEmpty ? null : _selectedTypes,
              merchants: _selectedMerchants.isEmpty ? null : _selectedMerchants,
              startDate: _startDate,
              endDate: _endDate,
            );
            Navigator.pop(context, criteria);
          },
          style: ElevatedButton.styleFrom(
             padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Apply Filters'),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }
}
