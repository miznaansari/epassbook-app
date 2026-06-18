class UserModel {
  final String id;
  final String email;
  final String name;
  final int salaryCycleDate;
  final String currency;
  final String dailyReminderTime;
  final String dailySpendReminderTime;
  final bool notifSalary;
  final bool notifDaily;
  final bool notifCycle;
  final bool notifDailySpend;
  final String timezone;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.salaryCycleDate,
    required this.currency,
    required this.dailyReminderTime,
    required this.dailySpendReminderTime,
    required this.notifSalary,
    required this.notifDaily,
    required this.notifCycle,
    required this.notifDailySpend,
    required this.timezone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      salaryCycleDate: json['salaryCycleDate'] ?? 1,
      currency: json['currency'] ?? 'USD',
      dailyReminderTime: json['dailyReminderTime'] ?? '23:00',
      dailySpendReminderTime: json['dailySpendReminderTime'] ?? '22:00',
      notifSalary: json['notifSalary'] ?? true,
      notifDaily: json['notifDaily'] ?? true,
      notifCycle: json['notifCycle'] ?? true,
      notifDailySpend: json['notifDailySpend'] ?? true,
      timezone: json['timezone'] ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'salaryCycleDate': salaryCycleDate,
      'currency': currency,
      'dailyReminderTime': dailyReminderTime,
      'dailySpendReminderTime': dailySpendReminderTime,
      'notifSalary': notifSalary,
      'notifDaily': notifDaily,
      'notifCycle': notifCycle,
      'notifDailySpend': notifDailySpend,
      'timezone': timezone,
    };
  }
}
