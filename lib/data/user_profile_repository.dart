import '../models/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<UserProfile?> getProfile(String uid);

  Future<void> saveProfile(UserProfile profile);
}
