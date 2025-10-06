double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class BudgetAlert {
  final String id;
  final String budgetId;
  final String userId;
  final String alertType;
  final int? threshold;
  final double currentSpending;
  final double budgetAmount;
  final double percentage;
  final String message;
  final List<String> sentVia;
  final DateTime sentAt;
  final bool wasRead;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetAlert({
    required this.id,
    required this.budgetId,
    required this.userId,
    required this.alertType,
    this.threshold,
    required this.currentSpending,
    required this.budgetAmount,
    required this.percentage,
    required this.message,
    required this.sentVia,
    required this.sentAt,
    required this.wasRead,
    this.readAt,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BudgetAlert.fromJson(Map<String, dynamic> json) {
    return BudgetAlert(
      id: json['id'] as String,
      budgetId: json['budgetId'] as String,
      userId: json['userId'] as String,
      alertType: json['alertType'] as String,
      threshold: json['threshold'] as int?,
      currentSpending: _toDouble(json['currentSpending']) ?? 0.0,
      budgetAmount: _toDouble(json['budgetAmount']) ?? 0.0,
      percentage: _toDouble(json['percentage']) ?? 0.0,
      message: json['message'] as String,
      sentVia: (json['sentVia'] as List<dynamic>?)?.map((e) => e as String).toList() ?? ['inApp'],
      sentAt: DateTime.parse(json['sentAt'] as String),
      wasRead: json['wasRead'] as bool? ?? false,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'] as String) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'budgetId': budgetId,
      'userId': userId,
      'alertType': alertType,
      'threshold': threshold,
      'currentSpending': currentSpending,
      'budgetAmount': budgetAmount,
      'percentage': percentage,
      'message': message,
      'sentVia': sentVia,
      'sentAt': sentAt.toIso8601String(),
      'wasRead': wasRead,
      'readAt': readAt?.toIso8601String(),
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  BudgetAlert copyWith({
    String? id,
    String? budgetId,
    String? userId,
    String? alertType,
    int? threshold,
    double? currentSpending,
    double? budgetAmount,
    double? percentage,
    String? message,
    List<String>? sentVia,
    DateTime? sentAt,
    bool? wasRead,
    DateTime? readAt,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetAlert(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      userId: userId ?? this.userId,
      alertType: alertType ?? this.alertType,
      threshold: threshold ?? this.threshold,
      currentSpending: currentSpending ?? this.currentSpending,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      percentage: percentage ?? this.percentage,
      message: message ?? this.message,
      sentVia: sentVia ?? this.sentVia,
      sentAt: sentAt ?? this.sentAt,
      wasRead: wasRead ?? this.wasRead,
      readAt: readAt ?? this.readAt,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isRecent {
    final hoursSinceSent = DateTime.now().difference(sentAt).inHours;
    return hoursSinceSent < 24;
  }

  int get ageInHours {
    return DateTime.now().difference(sentAt).inHours;
  }

  bool get isThresholdAlert => alertType == 'threshold';
  bool get isPredictiveAlert => alertType == 'predictive';
  bool get isComparativeAlert => alertType == 'comparative';
  bool get isExceededAlert => alertType == 'exceeded';
  bool get isDigestAlert => alertType == 'digest';

  String get severityLevel {
    if (percentage >= 100) return 'critical';
    if (percentage >= 90) return 'warning';
    if (percentage >= 75) return 'info';
    return 'low';
  }
}

class AlertStats {
  final int total;
  final int unread;
  final Map<String, int> byType;
  final int last7Days;
  final int last30Days;

  AlertStats({
    required this.total,
    required this.unread,
    required this.byType,
    required this.last7Days,
    required this.last30Days,
  });

  factory AlertStats.fromJson(Map<String, dynamic> json) {
    return AlertStats(
      total: json['total'] as int? ?? 0,
      unread: json['unread'] as int? ?? 0,
      byType: Map<String, int>.from(json['byType'] as Map? ?? {}),
      last7Days: json['last7Days'] as int? ?? 0,
      last30Days: json['last30Days'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'unread': unread,
      'byType': byType,
      'last7Days': last7Days,
      'last30Days': last30Days,
    };
  }
}
