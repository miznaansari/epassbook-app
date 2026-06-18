class FinancialEntry {
  final int id;
  final String userId;
  final double amount;
  final String title;
  final String description;
  final String type; // SPENDING, LENDING, LOAN, ADVANCE, SAVINGS
  final bool useSalaryBalance;
  final int? salaryMonth;
  final int? salaryYear;
  final DateTime date;
  final double unpaidAmount; // For LENDING
  final int? parentEntryId; // For Repayments
  final List<Repayment>? repayments;

  FinancialEntry({
    required this.id,
    required this.userId,
    required this.amount,
    required this.title,
    required this.description,
    required this.type,
    required this.useSalaryBalance,
    this.salaryMonth,
    this.salaryYear,
    required this.date,
    this.unpaidAmount = 0.0,
    this.parentEntryId,
    this.repayments,
  });

  factory FinancialEntry.fromJson(Map<String, dynamic> json) {
    var repaymentsList = json['repayments'] as List?;
    List<Repayment>? parsedRepayments = repaymentsList != null
        ? repaymentsList.map((r) => Repayment.fromJson(r)).toList()
        : null;

    return FinancialEntry(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['userId'] ?? '',
      amount: double.parse(json['amount'].toString()),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'SPENDING',
      useSalaryBalance: json['useSalaryBalance'] ?? false,
      salaryMonth: json['salaryMonth'],
      salaryYear: json['salaryYear'],
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      unpaidAmount: json['unpaidAmount'] != null
          ? double.parse(json['unpaidAmount'].toString())
          : 0.0,
      parentEntryId: json['parentEntryId'],
      repayments: parsedRepayments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'title': title,
      'description': description,
      'type': type,
      'useSalaryBalance': useSalaryBalance,
      'salaryMonth': salaryMonth,
      'salaryYear': salaryYear,
      'date': date.toIso8601String(),
      'parentEntryId': parentEntryId,
    };
  }
}

class Repayment {
  final int id;
  final double amount;
  final String title;
  final DateTime date;
  final String description;

  Repayment({
    required this.id,
    required this.amount,
    required this.title,
    required this.date,
    required this.description,
  });

  factory Repayment.fromJson(Map<String, dynamic> json) {
    return Repayment(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      amount: double.parse(json['amount'].toString()),
      title: json['title'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      description: json['description'] ?? '',
    );
  }
}
