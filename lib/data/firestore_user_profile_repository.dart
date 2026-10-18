import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'user_profile_repository.dart';

/// Menyimpan profil di dokumen `users/{uid}` pada Cloud Firestore.
class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const collectionName = 'users';
  static const _timestampFields = ['createdAt', 'lastSignInAt', 'updatedAt'];

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection(collectionName).doc(uid);

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final snapshot = await _doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;

    // UserProfile.fromMap menerima DateTime/ISO string, bukan Timestamp Firestore.
    final normalized = Map<String, Object?>.from(data);
    for (final field in _timestampFields) {
      final value = normalized[field];
      if (value is Timestamp) normalized[field] = value.toDate();
    }
    return UserProfile.fromMap(normalized);
  }

  @override
  Future<void> saveProfile(UserProfile profile) {
    final map = Map<String, Object?>.from(profile.toMap());
    for (final field in _timestampFields) {
      final value = map[field];
      if (value is DateTime) map[field] = Timestamp.fromDate(value);
    }
    // merge: true agar field lain (mis. progres di masa depan) tidak terhapus.
    return _doc(profile.uid).set(map, SetOptions(merge: true));
  }
}
