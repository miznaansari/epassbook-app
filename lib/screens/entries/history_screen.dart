import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/financial_entry.dart';
import 'entry_form_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedType = 'ALL';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'SPENDING':
        return AppTheme.primaryPurple;
      case 'LENDING':
        return AppTheme.blueLending;
      case 'LOAN':
        return AppTheme.orangeLoan;
      case 'ADVANCE':
        return AppTheme.cyanAdvance;
      case 'SAVINGS':
        return AppTheme.emeraldGreen;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(double amount, String currencyCode) {
    final format = NumberFormat.currency(
      symbol: currencyCode == 'INR' ? '₹' : '\$',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  void _editEntry(FinancialEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EntryFormSheet(entryToEdit: entry),
    );
  }

  void _receiveRepayment(FinancialEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EntryFormSheet(parentLending: entry),
    );
  }

  Future<void> _deleteEntry(BuildContext context, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Delete Transaction"),
        content: const Text("Are you sure you want to delete this transaction? This action is permanent."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: AppTheme.roseRed)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final entriesProvider = Provider.of<EntriesProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

      final success = await entriesProvider.deleteEntry(auth, id);
      if (success && mounted) {
        dashboardProvider.fetchDashboard(auth);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transaction deleted successfully.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final entriesProvider = Provider.of<EntriesProvider>(context);
    final currency = auth.user?.currency ?? 'USD';

    // Filter list
    final filteredEntries = entriesProvider.entries.where((entry) {
      final matchesType = _selectedType == 'ALL' || entry.type == _selectedType;
      final matchesSearch = entry.title.toLowerCase().contains(_searchQuery) ||
          entry.description.toLowerCase().contains(_searchQuery);
      return matchesType && matchesSearch;
    }).toList();

    final filterTypes = ['ALL', 'SPENDING', 'LENDING', 'LOAN', 'ADVANCE', 'SAVINGS'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Transaction Ledger", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => entriesProvider.fetchEntries(auth),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search transactions...",
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filters list
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: filterTypes.length,
              itemBuilder: (context, index) {
                final type = filterTypes[index];
                final isSelected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryPurple,
                    checkmarkColor: Colors.white,
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = type;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Transaction list
          Expanded(
            child: entriesProvider.loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
                : filteredEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade700),
                            const SizedBox(height: 16),
                            const Text("No transactions found", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => entriesProvider.fetchEntries(auth),
                        color: AppTheme.primaryPurple,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = filteredEntries[index];
                            final color = _getTypeColor(entry.type);
                            
                            return Card(
                              color: AppTheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(color: Colors.white.withOpacity(0.05)),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  leading: Container(
                                    width: 4,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  title: Text(
                                    entry.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    DateFormat('MMM dd, yyyy').format(entry.date),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatCurrency(entry.amount, currency),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: entry.type == 'SAVINGS' || entry.type == 'ADVANCE'
                                              ? AppTheme.emeraldGreen
                                              : Colors.white,
                                        ),
                                      ),
                                      if (entry.type == 'LENDING' && entry.unpaidAmount > 0)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.roseRed.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            "Unpaid: ${_formatCurrency(entry.unpaidAmount, currency)}",
                                            style: const TextStyle(fontSize: 8, color: AppTheme.roseRed, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (entry.description.isNotEmpty) ...[
                                            Text(
                                              entry.description,
                                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                          
                                          // Details
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Type: ${entry.type}",
                                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                              ),
                                              if (entry.useSalaryBalance && entry.salaryMonth != null)
                                                Text(
                                                  "Salary Month: ${entry.salaryMonth}/${entry.salaryYear}",
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),

                                          // Repayments history if lending
                                          if (entry.type == 'LENDING' && entry.repayments != null && entry.repayments!.isNotEmpty) ...[
                                            const Text(
                                              "REPAYMENT LOGS",
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
                                            ),
                                            const SizedBox(height: 4),
                                            ...entry.repayments!.map((rep) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(rep.title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                                    Text("+${_formatCurrency(rep.amount, currency)}", style: const TextStyle(fontSize: 11, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              );
                                            }),
                                            const SizedBox(height: 16),
                                          ],

                                          // Actions Bar
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (entry.type == 'LENDING' && entry.unpaidAmount > 0) ...[
                                                OutlinedButton.icon(
                                                  onPressed: () => _receiveRepayment(entry),
                                                  icon: const Icon(Icons.add_card_rounded, size: 16, color: AppTheme.emeraldGreen),
                                                  label: const Text("Repayment", style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 12)),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: AppTheme.emeraldGreen),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded, color: Colors.grey, size: 18),
                                                onPressed: () => _editEntry(entry),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.roseRed, size: 18),
                                                onPressed: () => _deleteEntry(context, entry.id),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
