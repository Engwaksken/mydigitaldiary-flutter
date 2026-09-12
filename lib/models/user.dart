/// Matches AuthController::userPayload() on the Laravel side exactly —
/// keep these two in sync whenever one changes.
class AppUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String themeColor;
  final String subscriptionStatus;
  final bool hasActiveAccess;
  final bool emailVerified;
  final bool alarmsMuted;
  final String themeColorSecondary;
  final String fontFamily;
  final int fontSize;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarUrl,
    required this.themeColor,
    required this.subscriptionStatus,
    required this.hasActiveAccess,
    required this.emailVerified,
    required this.alarmsMuted,
    required this.themeColorSecondary,
    required this.fontFamily,
    required this.fontSize,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatar_url'] as String?,
      themeColor: json['theme_color'] as String? ?? '#00897B',
      subscriptionStatus: json['subscription_status'] as String? ?? 'trialing',
      hasActiveAccess: json['has_active_access'] as bool? ?? false,
      emailVerified: json['email_verified'] as bool? ?? false,
      alarmsMuted: json['alarms_muted'] as bool? ?? false,
      themeColorSecondary:
          json['theme_color_secondary'] as String? ?? '#73BEB6',
      fontFamily: json['font_family'] as String? ?? 'Lato',
      fontSize: json['font_size'] as int? ?? 100,
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    bool? alarmsMuted,
    String? themeColor,
    String? themeColorSecondary,
    String? fontFamily,
    int? fontSize,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      themeColor: themeColor ?? this.themeColor,
      subscriptionStatus: subscriptionStatus,
      hasActiveAccess: hasActiveAccess,
      emailVerified: emailVerified,
      alarmsMuted: alarmsMuted ?? this.alarmsMuted,
      themeColorSecondary: themeColorSecondary ?? this.themeColorSecondary,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}
