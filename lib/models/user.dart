/// User Model for AllDebrid
class User {
  final String username;
  final String email;
  final bool isPremium;
  final bool isSubscribed;
  final bool isTrial;
  final int premiumUntil;
  final String lang;
  final String preferedDomain;
  final int fidelityPoints;
  final Map<String, int> limitedHostersQuotas;
  final int remainingTrialQuota;
  final List<String> notifications;

  User({
    required this.username,
    required this.email,
    required this.isPremium,
    required this.isSubscribed,
    required this.isTrial,
    required this.premiumUntil,
    required this.lang,
    required this.preferedDomain,
    required this.fidelityPoints,
    required this.limitedHostersQuotas,
    required this.remainingTrialQuota,
    required this.notifications,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] ?? json;
    return User(
      username: userData['username'] ?? '',
      email: userData['email'] ?? '',
      isPremium: userData['isPremium'] ?? false,
      isSubscribed: userData['isSubscribed'] ?? false,
      isTrial: userData['isTrial'] ?? false,
      premiumUntil: userData['premiumUntil'] ?? 0,
      lang: userData['lang'] ?? 'en',
      preferedDomain: userData['preferedDomain'] ?? '',
      fidelityPoints: userData['fidelityPoints'] ?? 0,
      limitedHostersQuotas:
          Map<String, int>.from(userData['limitedHostersQuotas'] ?? {}),
      remainingTrialQuota: userData['remainingTrialQuota'] ?? 0,
      notifications: List<String>.from(userData['notifications'] ?? []),
    );
  }

  DateTime get premiumUntilDate =>
      DateTime.fromMillisecondsSinceEpoch(premiumUntil * 1000);

  int get daysRemaining {
    final now = DateTime.now();
    return premiumUntilDate.difference(now).inDays;
  }
}
