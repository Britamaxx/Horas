class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.providerIds = const [],
    this.preferredDialect,
    this.createdAt,
    this.lastSignInAt,
    this.updatedAt,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final List<String> providerIds;
  final String? preferredDialect;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'providerIds': providerIds,
    'preferredDialect': preferredDialect,
    'createdAt': createdAt,
    'lastSignInAt': lastSignInAt,
    'updatedAt': updatedAt,
  };

  factory UserProfile.fromMap(Map<String, Object?> data) {
    final uid = data['uid'];
    if (uid is! String || uid.trim().isEmpty) {
      throw const FormatException('Profil harus memiliki uid.');
    }

    final providerIds = data['providerIds'];
    if (providerIds != null &&
        (providerIds is! List || providerIds.any((value) => value is! String))) {
      throw const FormatException('providerIds harus berupa daftar teks.');
    }
    final parsedProviderIds = providerIds == null
        ? const <String>[]
        : List<String>.unmodifiable(List<String>.from(providerIds as List));

    return UserProfile(
      uid: uid,
      displayName: _optionalString(data, 'displayName'),
      email: _optionalString(data, 'email'),
      photoUrl: _optionalString(data, 'photoUrl'),
      providerIds: parsedProviderIds,
      preferredDialect: _optionalString(data, 'preferredDialect'),
      createdAt: _optionalDateTime(data, 'createdAt'),
      lastSignInAt: _optionalDateTime(data, 'lastSignInAt'),
      updatedAt: _optionalDateTime(data, 'updatedAt'),
    );
  }

  static String? _optionalString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$key harus berupa teks.');
    }
    return value;
  }

  static DateTime? _optionalDateTime(
    Map<String, Object?> data,
    String key,
  ) {
    final value = data[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is! String) {
      throw FormatException('$key harus berupa Timestamp atau tanggal ISO-8601.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$key bukan tanggal ISO-8601 yang valid.');
    }
    return parsed;
  }
}
