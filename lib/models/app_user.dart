class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.providerIds = const [],
    this.createdAt,
    this.lastSignInAt,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final List<String> providerIds;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
}
