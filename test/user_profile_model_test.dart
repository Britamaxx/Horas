import 'package:belajar_bahasa_batak/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    test('round-trips Firestore-compatible profile fields', () {
      final createdAt = DateTime.utc(2026, 10, 18, 10);
      final profile = UserProfile(
        uid: 'firebase-uid',
        displayName: 'Horas',
        email: 'learner@example.test',
        photoUrl: 'https://example.test/photo.jpg',
        providerIds: const ['google.com'],
        preferredDialect: 'toba',
        createdAt: createdAt,
        lastSignInAt: createdAt.add(const Duration(hours: 1)),
        updatedAt: createdAt.add(const Duration(hours: 2)),
      );

      final restored = UserProfile.fromMap(profile.toMap());

      expect(restored.uid, profile.uid);
      expect(restored.email, profile.email);
      expect(restored.providerIds, ['google.com']);
      expect(restored.preferredDialect, 'toba');
      expect(restored.createdAt, createdAt);
      expect(restored.lastSignInAt, createdAt.add(const Duration(hours: 1)));
      expect(restored.updatedAt, createdAt.add(const Duration(hours: 2)));
    });

    test('rejects profiles without a Firebase uid', () {
      expect(
        () => UserProfile.fromMap({'uid': ''}),
        throwsFormatException,
      );
    });
  });
}
