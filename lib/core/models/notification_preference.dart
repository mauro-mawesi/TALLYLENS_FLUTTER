class NotificationPreference {
  final String id;
  final String userId;
  final bool budgetAlerts;
  final bool receiptProcessing;
  final bool weeklyDigest;
  final bool monthlyDigest;
  final bool priceAlerts;
  final bool productRecommendations;
  final String digestFrequency;
  final int? digestDay;
  final int digestHour;
  final NotificationChannelsPreference channels;
  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;
  final Map<String, dynamic>? deviceInfo;
  final String timezone;
  final bool quietHoursEnabled;
  final int? quietHoursStart;
  final int? quietHoursEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationPreference({
    required this.id,
    required this.userId,
    required this.budgetAlerts,
    required this.receiptProcessing,
    required this.weeklyDigest,
    required this.monthlyDigest,
    required this.priceAlerts,
    required this.productRecommendations,
    required this.digestFrequency,
    this.digestDay,
    required this.digestHour,
    required this.channels,
    this.fcmToken,
    this.fcmTokenUpdatedAt,
    this.deviceInfo,
    required this.timezone,
    required this.quietHoursEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      id: json['id'] as String,
      userId: json['userId'] as String,
      budgetAlerts: json['budgetAlerts'] as bool? ?? true,
      receiptProcessing: json['receiptProcessing'] as bool? ?? true,
      weeklyDigest: json['weeklyDigest'] as bool? ?? true,
      monthlyDigest: json['monthlyDigest'] as bool? ?? true,
      priceAlerts: json['priceAlerts'] as bool? ?? true,
      productRecommendations: json['productRecommendations'] as bool? ?? false,
      digestFrequency: json['digestFrequency'] as String? ?? 'weekly',
      digestDay: json['digestDay'] as int?,
      digestHour: json['digestHour'] as int? ?? 18,
      channels: NotificationChannelsPreference.fromJson(json['channels'] as Map<String, dynamic>? ?? {}),
      fcmToken: json['fcmToken'] as String?,
      fcmTokenUpdatedAt: json['fcmTokenUpdatedAt'] != null ? DateTime.tryParse(json['fcmTokenUpdatedAt'] as String) : null,
      deviceInfo: json['deviceInfo'] as Map<String, dynamic>?,
      timezone: json['timezone'] as String? ?? 'UTC',
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as int?,
      quietHoursEnd: json['quietHoursEnd'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'budgetAlerts': budgetAlerts,
      'receiptProcessing': receiptProcessing,
      'weeklyDigest': weeklyDigest,
      'monthlyDigest': monthlyDigest,
      'priceAlerts': priceAlerts,
      'productRecommendations': productRecommendations,
      'digestFrequency': digestFrequency,
      'digestDay': digestDay,
      'digestHour': digestHour,
      'channels': channels.toJson(),
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt?.toIso8601String(),
      'deviceInfo': deviceInfo,
      'timezone': timezone,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  NotificationPreference copyWith({
    String? id,
    String? userId,
    bool? budgetAlerts,
    bool? receiptProcessing,
    bool? weeklyDigest,
    bool? monthlyDigest,
    bool? priceAlerts,
    bool? productRecommendations,
    String? digestFrequency,
    int? digestDay,
    int? digestHour,
    NotificationChannelsPreference? channels,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    Map<String, dynamic>? deviceInfo,
    String? timezone,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreference(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      receiptProcessing: receiptProcessing ?? this.receiptProcessing,
      weeklyDigest: weeklyDigest ?? this.weeklyDigest,
      monthlyDigest: monthlyDigest ?? this.monthlyDigest,
      priceAlerts: priceAlerts ?? this.priceAlerts,
      productRecommendations: productRecommendations ?? this.productRecommendations,
      digestFrequency: digestFrequency ?? this.digestFrequency,
      digestDay: digestDay ?? this.digestDay,
      digestHour: digestHour ?? this.digestHour,
      channels: channels ?? this.channels,
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt ?? this.fcmTokenUpdatedAt,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      timezone: timezone ?? this.timezone,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPushEnabled => channels.push && fcmToken != null && fcmToken!.isNotEmpty;
  bool get isEmailEnabled => channels.email;
  bool get isInAppEnabled => channels.inApp;

  bool isInQuietHours(DateTime time) {
    if (!quietHoursEnabled || quietHoursStart == null || quietHoursEnd == null) {
      return false;
    }

    final hour = time.hour;

    // Handle case where quiet hours span midnight
    if (quietHoursStart! > quietHoursEnd!) {
      return hour >= quietHoursStart! || hour < quietHoursEnd!;
    } else {
      return hour >= quietHoursStart! && hour < quietHoursEnd!;
    }
  }

  bool shouldSendDigestToday(DateTime date) {
    if (digestFrequency == 'none') return false;
    if (digestFrequency == 'daily') return true;

    if (digestFrequency == 'weekly' && digestDay != null) {
      return date.weekday % 7 == digestDay; // 0 = Sunday, 6 = Saturday
    }

    if (digestFrequency == 'monthly') {
      return date.day == 1; // First day of month
    }

    return false;
  }
}

class NotificationChannelsPreference {
  final bool push;
  final bool email;
  final bool inApp;

  NotificationChannelsPreference({
    required this.push,
    required this.email,
    required this.inApp,
  });

  factory NotificationChannelsPreference.fromJson(Map<String, dynamic> json) {
    return NotificationChannelsPreference(
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

  NotificationChannelsPreference copyWith({
    bool? push,
    bool? email,
    bool? inApp,
  }) {
    return NotificationChannelsPreference(
      push: push ?? this.push,
      email: email ?? this.email,
      inApp: inApp ?? this.inApp,
    );
  }

  bool get hasAnyEnabled => push || email || inApp;
  bool get allDisabled => !hasAnyEnabled;
}
