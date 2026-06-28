class SubscriptionInfo {
  final bool isActive;
  final bool isTrial;
  final DateTime? trialEnd;
  final DateTime? paidUntil;

  SubscriptionInfo({
    this.isActive = false,
    this.isTrial = false,
    this.trialEnd,
    this.paidUntil,
  });

  int get daysRemaining {
    if (isActive && !isTrial && paidUntil != null) {
      return paidUntil!.difference(DateTime.now()).inDays.clamp(0, 999);
    }
    if (isTrial && trialEnd != null) {
      return trialEnd!.difference(DateTime.now()).inDays.clamp(0, 999);
    }
    return 0;
  }

  bool get isExpired {
    if (!isActive) return true;
    if (isTrial && trialEnd != null && DateTime.now().isAfter(trialEnd!)) return true;
    if (!isTrial && paidUntil != null && DateTime.now().isAfter(paidUntil!)) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'isActive': isActive,
        'isTrial': isTrial,
        'trialEnd': trialEnd?.toIso8601String(),
        'paidUntil': paidUntil?.toIso8601String(),
      };

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) => SubscriptionInfo(
        isActive: json['isActive'] as bool? ?? false,
        isTrial: json['isTrial'] as bool? ?? false,
        trialEnd: json['trialEnd'] != null ? DateTime.parse(json['trialEnd'] as String) : null,
        paidUntil: json['paidUntil'] != null ? DateTime.parse(json['paidUntil'] as String) : null,
      );
}
