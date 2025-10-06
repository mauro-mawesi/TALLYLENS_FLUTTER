double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class Budget {
  final String id;
  final String userId;
  final String name;
  final String? category;
  final double amount;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final String currency;
  final List<int> alertThresholds;
  final bool isActive;
  final bool isRecurring;
  final bool allowRollover;
  final double rolloverAmount;
  final NotificationChannels notificationChannels;
  final Map<String, dynamic>? metadata;
  final DateTime? lastAlertSentAt;
  final int? lastAlertThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  Budget({
    required this.id,
    required this.userId,
    required this.name,
    this.category,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.alertThresholds,
    required this.isActive,
    required this.isRecurring,
    required this.allowRollover,
    required this.rolloverAmount,
    required this.notificationChannels,
    this.metadata,
    this.lastAlertSentAt,
    this.lastAlertThreshold,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      amount: _toDouble(json['amount']) ?? 0.0,
      period: json['period'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      currency: json['currency'] as String? ?? 'USD',
      alertThresholds: (json['alertThresholds'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [50, 75, 90, 100],
      isActive: json['isActive'] as bool? ?? true,
      isRecurring: json['isRecurring'] as bool? ?? false,
      allowRollover: json['allowRollover'] as bool? ?? false,
      rolloverAmount: _toDouble(json['rolloverAmount']) ?? 0.0,
      notificationChannels: NotificationChannels.fromJson(json['notificationChannels'] as Map<String, dynamic>? ?? {}),
      metadata: json['metadata'] as Map<String, dynamic>?,
      lastAlertSentAt: json['lastAlertSentAt'] != null ? DateTime.tryParse(json['lastAlertSentAt'] as String) : null,
      lastAlertThreshold: json['lastAlertThreshold'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'category': category,
      'amount': amount,
      'period': period,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'currency': currency,
      'alertThresholds': alertThresholds,
      'isActive': isActive,
      'isRecurring': isRecurring,
      'allowRollover': allowRollover,
      'rolloverAmount': rolloverAmount,
      'notificationChannels': notificationChannels.toJson(),
      'metadata': metadata,
      'lastAlertSentAt': lastAlertSentAt?.toIso8601String(),
      'lastAlertThreshold': lastAlertThreshold,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Budget copyWith({
    String? id,
    String? userId,
    String? name,
    String? category,
    double? amount,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
    List<int>? alertThresholds,
    bool? isActive,
    bool? isRecurring,
    bool? allowRollover,
    double? rolloverAmount,
    NotificationChannels? notificationChannels,
    Map<String, dynamic>? metadata,
    DateTime? lastAlertSentAt,
    int? lastAlertThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currency: currency ?? this.currency,
      alertThresholds: alertThresholds ?? this.alertThresholds,
      isActive: isActive ?? this.isActive,
      isRecurring: isRecurring ?? this.isRecurring,
      allowRollover: allowRollover ?? this.allowRollover,
      rolloverAmount: rolloverAmount ?? this.rolloverAmount,
      notificationChannels: notificationChannels ?? this.notificationChannels,
      metadata: metadata ?? this.metadata,
      lastAlertSentAt: lastAlertSentAt ?? this.lastAlertSentAt,
      lastAlertThreshold: lastAlertThreshold ?? this.lastAlertThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays;
  }

  int get daysElapsed {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 0;
    return now.difference(startDate).inDays;
  }

  bool get isExpired {
    return DateTime.now().isAfter(endDate);
  }

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive &&
           !now.isBefore(startDate) &&
           !now.isAfter(endDate);
  }
}

class NotificationChannels {
  final bool push;
  final bool email;
  final bool inApp;

  NotificationChannels({
    required this.push,
    required this.email,
    required this.inApp,
  });

  factory NotificationChannels.fromJson(Map<String, dynamic> json) {
    return NotificationChannels(
      push: json['push'] as bool? ?? true,
      email: json['email'] as bool? ?? false,
      inApp: json['inApp'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push': push,
      'email': email,
      'inApp': inApp,
    };
  }

  NotificationChannels copyWith({
    bool? push,
    bool? email,
    bool? inApp,
  }) {
    return NotificationChannels(
      push: push ?? this.push,
      email: email ?? this.email,
      inApp: inApp ?? this.inApp,
    );
  }
}

class BudgetProgress {
  final String budgetId;
  final String budgetName;
  final double totalBudget;
  final double currentSpending;
  final double remainingBudget;
  final double percentage;
  final int daysRemaining;
  final int daysElapsed;
  final int receiptCount;
  final bool isActive;
  final String status;

  BudgetProgress({
    required this.budgetId,
    required this.budgetName,
    required this.totalBudget,
    required this.currentSpending,
    required this.remainingBudget,
    required this.percentage,
    required this.daysRemaining,
    required this.daysElapsed,
    required this.receiptCount,
    required this.isActive,
    required this.status,
  });

  factory BudgetProgress.fromJson(Map<String, dynamic> json) {
    return BudgetProgress(
      budgetId: json['budgetId'] as String,
      budgetName: json['budgetName'] as String,
      totalBudget: _toDouble(json['totalBudget']) ?? 0.0,
      currentSpending: _toDouble(json['currentSpending']) ?? 0.0,
      remainingBudget: _toDouble(json['remainingBudget']) ?? 0.0,
      percentage: _toDouble(json['percentage']) ?? 0.0,
      daysRemaining: json['daysRemaining'] as int? ?? 0,
      daysElapsed: json['daysElapsed'] as int? ?? 0,
      receiptCount: json['receiptCount'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
    );
  }

  bool get isOverBudget => percentage > 100;
  bool get isNearLimit => percentage >= 75 && percentage <= 100;
  bool get isOnTrack => percentage < 75;
}
