import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/financial_entry.dart';

class EntryFormSheet extends StatefulWidget {
  final FinancialEntry? entryToEdit;
  final FinancialEntry? parentLending;
  final String? prefilledTitle;
  final String? prefilledType;

  const EntryFormSheet({
    super.key,
    this.entryToEdit,
    this.parentLending,
    this.prefilledTitle,
    this.prefilledType,
  });

  @override
  State<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<EntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _type = 'SPENDING';
  bool _useSalaryBalance = false;
  int _salaryMonth = DateTime.now().month;
  int _salaryYear = DateTime.now().year;
  DateTime _selectedDate = DateTime.now();

  bool _isSubmitting = false;
  String _errorMessage = '';

  // Split view state
  bool _splitViewOpen = false;
  Map<String, dynamic>? _insufficientInfo;
  final List<String> _checkedMonths = []; // keys formatted as "year-month"

  // Title autocomplete/autofill state
  final _titleFocusNode = FocusNode();
  List<FinancialEntry> _filteredSuggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _titleController.addListener(_onTitleChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPastEntries();
    });
  }

  void _onTitleFocusChanged() {
    setState(() {
      _showSuggestions = _titleFocusNode.hasFocus;
    });
  }

  void _onTitleChanged() {
    if (!_showSuggestions) return;

    final query = _titleController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredSuggestions = [];
      });
      return;
    }

    final entriesProvider = Provider.of<EntriesProvider>(context, listen: false);
    final entries = entriesProvider.entries;
    final Map<String, FinancialEntry> suggestionsMap = {};

    for (final entry in entries) {
      final etitle = entry.title.trim();
      final key = etitle.toLowerCase();

      // Filter out exact matches to avoid suggesting what's already typed
      if (key.contains(query) && etitle != _titleController.text) {
        final existing = suggestionsMap[key];
        if (existing == null || entry.date.isAfter(existing.date)) {
          suggestionsMap[key] = entry;
        }
      }
    }

    final sortedList = suggestionsMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _filteredSuggestions = sortedList.take(3).toList();
    });
  }

  Future<void> _loadPastEntries() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final entries = Provider.of<EntriesProvider>(context, listen: false);
      await entries.fetchEntries(auth);
    } catch (e) {
      debugPrint("Error loading past entries for autocomplete: $e");
    }
  }

  void _handleSelectSuggestion(FinancialEntry suggestion) {
    setState(() {
      _titleController.text = suggestion.title;
      _amountController.text = suggestion.amount.toString();
      _type = suggestion.type;
      _useSalaryBalance = suggestion.useSalaryBalance;
      _salaryMonth = DateTime.now().month;
      _salaryYear = DateTime.now().year;
      _filteredSuggestions = [];
      _showSuggestions = false;
      _titleFocusNode.unfocus();
    });
  }

  void _initializeForm() {
    if (widget.parentLending != null) {
      _titleController.text = "Repayment: ${widget.parentLending!.title}";
      _descriptionController.text = "Repayment of lending transaction";
      _type = 'ADVANCE';
      _useSalaryBalance = widget.parentLending!.useSalaryBalance;
      _salaryMonth = widget.parentLending!.salaryMonth ?? DateTime.now().month;
      _salaryYear = widget.parentLending!.salaryYear ?? DateTime.now().year;
    } else if (widget.entryToEdit != null) {
      _amountController.text = widget.entryToEdit!.amount.toString();
      _titleController.text = widget.entryToEdit!.title;
      _descriptionController.text = widget.entryToEdit!.description;
      _type = widget.entryToEdit!.type;
      _useSalaryBalance = widget.entryToEdit!.useSalaryBalance;
      _salaryMonth = widget.entryToEdit!.salaryMonth ?? DateTime.now().month;
      _salaryYear = widget.entryToEdit!.salaryYear ?? DateTime.now().year;
      _selectedDate = widget.entryToEdit!.date;
    } else {
      _titleController.text = widget.prefilledTitle ?? '';
      _type = widget.prefilledType ?? 'SPENDING';
      _useSalaryBalance = false;
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _titleFocusNode.dispose();
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Split deduction helper allocations
  Map<String, dynamic> _calculateAllocations() {
    if (_insufficientInfo == null) return {'allocations': [], 'remaining': 0.0};

    final double targetAmount = double.tryParse(_amountController.text) ?? 0.0;
    
    // Find primary balance info
    final List<dynamic> balances = _insufficientInfo!['availableBalances'] ?? [];
    var primaryBalInfo = balances.firstWhere(
      (b) => b['month'] == _salaryMonth && b['year'] == _salaryYear,
      orElse: () => null,
    );

    final double primarySalaryRem = primaryBalInfo != null 
        ? double.parse(primaryBalInfo['salary']['remaining'].toString()) 
        : 0.0;
    final double primaryBonusRem = primaryBalInfo != null 
        ? double.parse(primaryBalInfo['bonus']['remaining'].toString()) 
        : 0.0;
    final double primaryTotalAvailable = primarySalaryRem + primaryBonusRem;

    // Deduct from primary month first
    final double primaryAllocated = targetAmount < primaryTotalAvailable ? targetAmount : primaryTotalAvailable;
    double remainingToAllocate = targetAmount - primaryAllocated;

    final List<Map<String, dynamic>> allocations = [
      {
        'month': _salaryMonth,
        'year': _salaryYear,
        'amount': primaryAllocated,
        'isPrimary': true
      }
    ];

    // Distribute among checked other months
    for (final key in _checkedMonths) {
      if (remainingToAllocate <= 0) break;

      final parts = key.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);

      if (m == _salaryMonth && y == _salaryYear) continue; // Skip primary

      var mBal = balances.firstWhere(
        (b) => b['month'] == m && b['year'] == y,
        orElse: () => null,
      );
      if (mBal == null) continue;

      final double avail = double.parse(mBal['salary']['remaining'].toString()) + 
                          double.parse(mBal['bonus']['remaining'].toString());
      if (avail <= 0) continue;

      final double allocAmt = remainingToAllocate < avail ? remainingToAllocate : avail;
      allocations.add({
        'month': m,
        'year': y,
        'amount': allocAmt,
        'isPrimary': false
      });
      remainingToAllocate -= allocAmt;
    }

    return {'allocations': allocations, 'remaining': remainingToAllocate};
  }

  void _toggleCheckedMonth(String key) {
    setState(() {
      if (_checkedMonths.contains(key)) {
        _checkedMonths.remove(key);
      } else {
        _checkedMonths.add(key);
      }
    });
  }

  Future<void> _handleSubmit({List<Map<String, dynamic>>? explicitDeductions}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = '';
      _isSubmitting = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final entries = Provider.of<EntriesProvider>(context, listen: false);
      final dashboard = Provider.of<DashboardProvider>(context, listen: false);

      final double amt = double.parse(_amountController.text);

      final res = await entries.saveEntry(
        auth,
        id: (widget.entryToEdit?.id == -1) ? null : widget.entryToEdit?.id,
        amount: amt,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _type,
        useSalaryBalance: _useSalaryBalance,
        salaryMonth: _useSalaryBalance ? _salaryMonth : null,
        salaryYear: _useSalaryBalance ? _salaryYear : null,
        date: _selectedDate,
        parentEntryId: widget.parentLending?.id,
        deductions: explicitDeductions,
      );

      if (res['success'] == true) {
        // Refresh feeds
        await dashboard.fetchDashboard(auth);
        if (mounted) Navigator.pop(context);
      } else if (res['insufficient'] == true) {
        setState(() {
          _insufficientInfo = entries.insufficientBalanceDetails;
          _splitViewOpen = true;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to save entry';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.user?.currency ?? 'USD';
    final currencySymbol = currency == 'INR' ? '₹' : '\$';
    
    final splitResults = _calculateAllocations();
    final List<dynamic> computedAllocations = splitResults['allocations'];
    final double remainingToAllocate = splitResults['remaining'];

    final months = List.generate(12, (index) => index + 1);
    final years = List.generate(5, (index) => DateTime.now().year - 2 + index);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _splitViewOpen
                    ? _buildSplitDeductionView(currencySymbol, computedAllocations, remainingToAllocate)
                    : _buildMainFormView(currencySymbol, months, years),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainFormView(String currencySymbol, List<int> months, List<int> years) {
    return Column(
      key: const ValueKey('form_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.parentLending != null 
                  ? 'Receive Repayment' 
                  : widget.entryToEdit != null 
                      ? 'Edit Transaction' 
                      : 'Log Financial Entry',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_errorMessage.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.roseRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.roseRed.withOpacity(0.2)),
            ),
            child: Text(_errorMessage, style: const TextStyle(color: AppTheme.roseRed, fontSize: 13)),
          ),
          const SizedBox(height: 12),
        ],

        // Amount & Date
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'AMOUNT',
                  prefixText: '$currencySymbol ',
                  prefixStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: AppTheme.background.withOpacity(0.4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter amount';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Invalid amount';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.background.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                      ),
                      const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Type Selector
        if (widget.parentLending == null) ...[
          const Text(
            "ENTRY TYPE",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['SPENDING', 'LENDING', 'LOAN', 'ADVANCE', 'SAVINGS'].map((t) {
                final isSelected = _type == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryPurple,
                    checkmarkColor: Colors.white,
                    backgroundColor: AppTheme.background,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _type = t;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Title
        TextFormField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          decoration: InputDecoration(
            labelText: 'TITLE',
            hintText: 'e.g. Rent, Grocery bills',
            filled: true,
            fillColor: AppTheme.background.withOpacity(0.4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Enter title';
            return null;
          },
        ),
        
        if (_filteredSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredSuggestions.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withOpacity(0.04),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final suggestion = _filteredSuggestions[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    suggestion.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    suggestion.type,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Autofill ",
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "$currencySymbol${suggestion.amount.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryPurple, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  onTap: () => _handleSelectSuggestion(suggestion),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'DESCRIPTION',
            hintText: 'Add notes...',
            filled: true,
            fillColor: AppTheme.background.withOpacity(0.4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),

        // Salary Balance options
        if (widget.parentLending == null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _useSalaryBalance,
                      activeColor: AppTheme.primaryPurple,
                      onChanged: (val) {
                        setState(() {
                          _useSalaryBalance = val ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text(
                        "Deduct from Salary Balance",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                if (_useSalaryBalance) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _salaryMonth,
                          decoration: const InputDecoration(labelText: 'MONTH', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                          items: months.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(DateFormat('MMMM').format(DateTime(2026, m)), style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _salaryMonth = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _salaryYear,
                          decoration: const InputDecoration(labelText: 'YEAR', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                          items: years.map((y) {
                            return DropdownMenuItem(value: y, child: Text(y.toString(), style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _salaryYear = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Submit Button
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _handleSubmit(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  widget.parentLending != null 
                      ? 'Log Repayment' 
                      : widget.entryToEdit != null 
                          ? 'Save Changes' 
                          : 'Log Transaction',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
        ),
      ],
    );
  }

  Widget _buildSplitDeductionView(String currencySymbol, List<dynamic> computedAllocations, double remainingToAllocate) {
    final List<dynamic> balances = _insufficientInfo?['availableBalances'] ?? [];
    
    return Column(
      key: const ValueKey('split_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Insufficient Balance",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            TextButton(
              onPressed: () => setState(() => _splitViewOpen = false),
              child: const Text("Back", style: TextStyle(color: AppTheme.primaryPurple)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: Text(
            "Selected month has insufficient balance. Choose other months to deduct the remaining $currencySymbol${remainingToAllocate.toStringAsFixed(2)}:",
            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),

        // List of other months
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: balances.length,
            itemBuilder: (context, index) {
              final b = balances[index];
              final m = b['month'] as int;
              final y = b['year'] as int;
              if (m == _salaryMonth && y == _salaryYear) return const SizedBox.shrink(); // skip primary

              final key = "$y-$m";
              final isChecked = _checkedMonths.contains(key);
              final double salRem = double.parse(b['salary']['remaining'].toString());
              final double bonRem = double.parse(b['bonus']['remaining'].toString());
              final double totalAvail = salRem + bonRem;

              final monthName = DateFormat('MMMM').format(DateTime(2026, m));

              return Card(
                color: isChecked ? AppTheme.primaryPurple.withOpacity(0.05) : AppTheme.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isChecked ? AppTheme.primaryPurple : AppTheme.border),
                ),
                child: ListTile(
                  dense: true,
                  leading: Checkbox(
                    value: isChecked,
                    activeColor: AppTheme.primaryPurple,
                    onChanged: (_) => _toggleCheckedMonth(key),
                  ),
                  title: Text("$monthName $y", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text("Salary: $currencySymbol${salRem.toStringAsFixed(0)} | Bonus: $currencySymbol${bonRem.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  trailing: Text("$currencySymbol${totalAvail.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                  onTap: () => _toggleCheckedMonth(key),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Allocation details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("ALLOCATION SUMMARY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              ...computedAllocations.map((a) {
                final mName = DateFormat('MMMM').format(DateTime(2026, a['month']));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$mName ${a['year']} ${a['isPrimary'] ? '(Selected)' : ''}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      Text("$currencySymbol${double.parse(a['amount'].toString()).toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                );
              }),
              const Divider(color: AppTheme.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Remaining", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(
                    "$currencySymbol${remainingToAllocate.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: remainingToAllocate > 0.01 ? AppTheme.roseRed : AppTheme.emeraldGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isSubmitting || remainingToAllocate > 0.01 
              ? null 
              : () => _handleSubmit(explicitDeductions: computedAllocations.cast<Map<String, dynamic>>()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Confirm & Log Transaction", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}
