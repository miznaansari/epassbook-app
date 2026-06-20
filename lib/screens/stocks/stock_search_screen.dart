import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stock_provider.dart';
import '../../providers/dashboard_provider.dart';

class StockSearchScreen extends StatefulWidget {
  const StockSearchScreen({super.key});

  @override
  State<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends State<StockSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _buyQuantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  bool _createExpense = true;
  String _searchQuery = '';
  String? _expandedSymbol;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<StockProvider>(context, listen: false).searchStocks(auth, _searchQuery);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _buyQuantityController.dispose();
    _buyPriceController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount, String currencyCode) {
    final format = NumberFormat.currency(
      symbol: currencyCode == 'INR' ? '₹' : '\$',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  void _showBuyDialog(dynamic stock) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentPrice = double.tryParse((stock['price'] ?? 0.0).toString()) ?? 0.0;
    _buyPriceController.text = currentPrice.toString();
    _buyQuantityController.text = "1";
    _createExpense = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Buy ${stock['symbol']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(stock['name'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _buyQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'QUANTITY', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _buyPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'BUY PRICE',
                        prefixText: auth.user?.currency == 'INR' ? '₹ ' : '\$ ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _createExpense,
                          activeColor: AppTheme.primaryPurple,
                          onChanged: (val) {
                            setDialogState(() {
                              _createExpense = val ?? true;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text("Log spent amount to ledger as Expense?", style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final int qty = int.tryParse(_buyQuantityController.text) ?? 0;
                    final double price = double.tryParse(_buyPriceController.text) ?? 0.0;
                    if (qty <= 0 || price <= 0.0) return;

                    final stockProvider = Provider.of<StockProvider>(context, listen: false);
                    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

                    final success = await stockProvider.addStockHolding(
                      auth,
                      symbol: stock['symbol'],
                      name: stock['name'] ?? '',
                      quantity: qty,
                      buyPrice: price,
                      createExpense: _createExpense,
                    );

                    if (success && mounted) {
                      await dashboard.fetchDashboard(auth);
                      if (mounted) Navigator.pop(context);
                      _searchController.clear();
                      _tabController.animateTo(0); // switch to portfolio tab
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                  child: const Text("Buy Stock", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final stockProvider = Provider.of<StockProvider>(context);
    final currency = auth.user?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Stock Market & Assets", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPurple,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "My Portfolio"),
            Tab(text: "Search Tickers"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: My Portfolio
          _buildPortfolioTab(stockProvider, auth, currency),

          // Tab 2: Search Tickers
          _buildSearchTab(stockProvider, auth),
        ],
      ),
    );
  }

  Widget _buildPortfolioTab(StockProvider stockProvider, AuthProvider auth, String currency) {
    final summary = stockProvider.summary;
    final holdings = stockProvider.holdings;

    return RefreshIndicator(
      onRefresh: () => stockProvider.refreshPrices(auth),
      color: AppTheme.primaryPurple,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Portfolio statistics summary card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  const Text("PORTFOLIO NET VALUE", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrency(summary?.totalCurrentValue ?? 0.0, currency),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("INVESTED", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_formatCurrency(summary?.totalInvested ?? 0.0, currency), style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("TOTAL RETURNS", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            "${(summary?.totalReturns ?? 0.0) >= 0 ? '+' : ''}${_formatCurrency(summary?.totalReturns ?? 0.0, currency)} (${(summary?.totalReturnsPercentage ?? 0.0).toStringAsFixed(2)}%)",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: (summary?.totalReturns ?? 0.0) >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("MY HOLDINGS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
                TextButton.icon(
                  onPressed: () => stockProvider.refreshPrices(auth),
                  icon: const Icon(Icons.sync_rounded, size: 16, color: AppTheme.primaryPurple),
                  label: const Text("Sync Prices", style: TextStyle(color: AppTheme.primaryPurple, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (stockProvider.loading && holdings.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.primaryPurple)))
            else if (holdings.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      Icon(Icons.show_chart_rounded, size: 48, color: Colors.grey.shade800),
                      const SizedBox(height: 16),
                      const Text("No stock holdings logged yet.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: holdings.length,
                itemBuilder: (context, index) {
                  final h = holdings[index];
                  final returnsColor = h.totalReturns >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed;
                  final isExpanded = _expandedSymbol == h.symbol;
                  
                  return Card(
                    color: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isExpanded ? AppTheme.primaryPurple.withOpacity(0.4) : Colors.white.withOpacity(0.05),
                        width: isExpanded ? 1.5 : 1.0,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _expandedSymbol = isExpanded ? null : h.symbol;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      color: isExpanded ? AppTheme.primaryPurple : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(h.symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                        if (h.name.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.35,
                                            child: Text(
                                              h.name,
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_formatCurrency(h.currentValue, currency), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${h.totalReturns >= 0 ? '+' : ''}${_formatCurrency(h.totalReturns, currency)} (${h.returnsPercentage.toStringAsFixed(2)}%)",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: returnsColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${h.quantity} Shares • Avg ${_formatCurrency(h.buyPrice, currency)}",
                                  style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  "Invested: ${_formatCurrency(h.investedValue, currency)}",
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),

                            if (isExpanded) ...[
                              const SizedBox(height: 12),
                              const Divider(color: AppTheme.border, height: 1),
                              const SizedBox(height: 12),
                              const Text(
                                "PURCHASE HISTORY",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryPurple,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...h.purchases.map((p) {
                                final pInvested = p.quantity * p.buyPrice;
                                final pCurrentValue = p.quantity * h.currentPrice;
                                final pReturns = pCurrentValue - pInvested;
                                final pReturnsPercentage = p.buyPrice > 0 ? ((h.currentPrice - p.buyPrice) / p.buyPrice) * 100 : 0.0;
                                final pProfit = pReturns >= 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.02)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat('MMM dd, yyyy • hh:mm a').format(p.createdAt.toLocal()),
                                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${p.quantity} shares @ ${_formatCurrency(p.buyPrice, currency)}",
                                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Invested: ${_formatCurrency(pInvested, currency)}",
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                "${pProfit ? '+' : ''}${_formatCurrency(pReturns, currency)}",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: pProfit ? AppTheme.emeraldGreen : AppTheme.roseRed,
                                                ),
                                              ),
                                              Text(
                                                "${pProfit ? '+' : ''}${pReturnsPercentage.toStringAsFixed(2)}%",
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: pProfit ? AppTheme.emeraldGreen.withOpacity(0.8) : AppTheme.roseRed.withOpacity(0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.roseRed, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  backgroundColor: AppTheme.surface,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: const Text("Delete Purchase", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  content: Text("Are you sure you want to delete this purchase transaction of ${p.quantity} shares of ${h.symbol}?", style: const TextStyle(color: Colors.white70)),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.roseRed),
                                                      child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                final success = await stockProvider.deleteStockHolding(auth, p.id);
                                                if (success) {
                                                  // Refresh dashboard
                                                  if (context.mounted) {
                                                    Provider.of<DashboardProvider>(context, listen: false).fetchDashboard(auth);
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab(StockProvider stockProvider, AuthProvider auth) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search symbol or company...",
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        
        Expanded(
          child: stockProvider.loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
              : _searchQuery.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 54, color: Colors.grey.shade800),
                          const SizedBox(height: 12),
                          const Text("Enter a ticker symbol like AAPL or INFY", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: stockProvider.searchResults.length,
                      itemBuilder: (context, index) {
                        final res = stockProvider.searchResults[index];
                        return Card(
                          color: AppTheme.surface,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(res['symbol'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: Text(res['name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  res['type'] ?? 'Stock',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                const Text("Click to Buy", style: TextStyle(color: AppTheme.primaryPurple, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            onTap: () => _showBuyDialog(res),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
