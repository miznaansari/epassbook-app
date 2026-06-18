class StockHolding {
  final int id;
  final String symbol;
  final String name;
  final int quantity;
  final double buyPrice;
  final double currentPrice;
  final double investedValue;
  final double currentValue;
  final double totalReturns;
  final double returnsPercentage;

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
  });

  factory StockHolding.fromJson(Map<String, dynamic> json) {
    return StockHolding(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      buyPrice: double.parse(json['buyPrice'].toString()),
      currentPrice: double.parse(json['currentPrice'].toString()),
      investedValue: double.parse(json['investedValue'].toString()),
      currentValue: double.parse(json['currentValue'].toString()),
      totalReturns: double.parse(json['totalReturns'].toString()),
      returnsPercentage: double.parse(json['returnsPercentage'].toString()),
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
