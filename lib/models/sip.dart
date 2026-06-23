class Sip {
  final int id;
  final String userId;
  final double amount;
  final String title;
  final String frequency; // WEEKLY or MONTHLY
  final int? dayOfMonth;
  final int? dayOfWeek;
  final String reminderTime;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SipPeriod> periods;

  Sip({
    required this.id,
    required this.userId,
    required this.amount,
    required this.title,
    required this.frequency,
    this.dayOfMonth,
    this.dayOfWeek,
    required this.reminderTime,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.periods,
  });

  factory Sip.fromJson(Map<String, dynamic> json) {
    var periodsList = json['periods'] as List?;
    List<SipPeriod> parsedPeriods = periodsList != null
        ? periodsList.map((p) => SipPeriod.fromJson(p)).toList()
        : [];

    return Sip(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['userId'] ?? '',
      amount: double.parse(json['amount'].toString()),
      title: json['title'] ?? '',
      frequency: json['frequency'] ?? 'MONTHLY',
      dayOfMonth: json['dayOfMonth'] != null
          ? int.tryParse(json['dayOfMonth'].toString())
          : null,
      dayOfWeek: json['dayOfWeek'] != null
          ? int.tryParse(json['dayOfWeek'].toString())
          : null,
      reminderTime: json['reminderTime'] ?? '10:00',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      periods: parsedPeriods,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'title': title,
      'frequency': frequency,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
      'reminderTime': reminderTime,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'periods': periods.map((p) => p.toJson()).toList(),
    };
  }
}

class SipPeriod {
  final String label;
  final DateTime targetDate;
  final String status; // PAID, MISSED, PENDING
  final bool isPaid;

  SipPeriod({
    required this.label,
    required this.targetDate,
    required this.status,
    required this.isPaid,
  });

  factory SipPeriod.fromJson(Map<String, dynamic> json) {
    return SipPeriod(
      label: json['label'] ?? '',
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'])
          : DateTime.now(),
      status: json['status'] ?? 'PENDING',
      isPaid: json['isPaid'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'targetDate': targetDate.toIso8601String(),
      'status': status,
      'isPaid': isPaid,
    };
  }
}
