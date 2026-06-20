class StockPurchase {
  final int id;
  final int quantity;
  final double buyPrice;
  final DateTime createdAt;

  StockPurchase({
    required this.id,
    required this.quantity,
    required this.buyPrice,
    required this.createdAt,
  });

  factory StockPurchase.fromJson(Map<String, dynamic> json) {
    return StockPurchase(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      quantity: json['quantity'] is int ? json['quantity'] : int.parse(json['quantity'].toString()),
      buyPrice: double.parse(json['buyPrice'].toString()),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }
}

class StockHolding {
  final String id;
  final String symbol;
  final String name;
  final int quantity;
  final double buyPrice;
  final double currentPrice;
  final double investedValue;
  final double currentValue;
  final double totalReturns;
  final double returnsPercentage;
  final List<StockPurchase> purchases;

  StockHolding({
    required this.id,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.buyPrice,
    required this.currentPrice,
    required this.investedValue,
    required this.currentValue,
    required this.totalReturns,
    required this.returnsPercentage,
    required this.purchases,
  });

  factory StockHolding.fromJson(Map<String, dynamic> json) {
    var purchasesList = <StockPurchase>[];
    if (json['purchases'] != null) {
      purchasesList = (json['purchases'] as List)
          .map((p) => StockPurchase.fromJson(p))
          .toList();
    }

    return StockHolding(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      buyPrice: double.parse(json['buyPrice'].toString()),
      currentPrice: double.parse(json['currentPrice'].toString()),
      investedValue: double.parse(json['investedValue'].toString()),
      currentValue: double.parse(json['currentValue'].toString()),
      totalReturns: double.parse(json['totalReturns'].toString()),
      returnsPercentage: double.parse(json['returnsPercentage'].toString()),
      purchases: purchasesList,
    );
  }
}

class PortfolioSummary {
  final double totalInvested;
  final double totalCurrentValue;
  final double totalReturns;
  final double totalReturnsPercentage;

  PortfolioSummary({
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalReturns,
    required this.totalReturnsPercentage,
  });

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    return PortfolioSummary(
      totalInvested: double.parse(json['totalInvested'].toString()),
      totalCurrentValue: double.parse(json['totalCurrentValue'].toString()),
      totalReturns: double.parse(json['totalReturns'].toString()),
      totalReturnsPercentage: double.parse(json['totalReturnsPercentage'].toString()),
    );
  }
}
