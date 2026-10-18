import 'package:belajar_bahasa_batak/data/pending_sentence_exercise_repository.dart';
import 'package:belajar_bahasa_batak/models/sentence_exercise.dart';
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

  group('SentenceExercise', () {
    test('preserves ordered tokens and source attribution', () {
      final exercise = SentenceExercise.fromJson({
        'id': 'reviewed-fixture',
        'dialect': 'toba',
        'indonesianPrompt': 'fixture prompt',
        'batakSentence': 'token-satu token-dua',
        'tokens': ['token-satu', 'token-dua'],
        'sourceName': 'fixture source',
        'sourceReference': 'fixture reference',
      });

      expect(exercise.tokens, ['token-satu', 'token-dua']);
      expect(exercise.sourceReference, 'fixture reference');
      expect(
        SentenceExercise.fromJson(exercise.toJson()).batakSentence,
        exercise.batakSentence,
      );
    });

    test('rejects a sentence that differs from its ordered tokens', () {
      expect(
        () => SentenceExercise.fromJson({
          'id': 'reviewed-fixture',
          'dialect': 'toba',
          'indonesianPrompt': 'fixture prompt',
          'batakSentence': 'token-dua token-satu',
          'tokens': ['token-satu', 'token-dua'],
          'sourceName': 'fixture source',
          'sourceReference': 'fixture reference',
        }),
        throwsFormatException,
      );
    });
  });

  test('pending local sentence catalog is empty only for Batak Toba', () async {
    const repository = PendingSentenceExerciseRepository();

    expect(await repository.loadExercises(dialect: 'toba'), isEmpty);
    await expectLater(
      repository.loadExercises(dialect: 'karo'),
      throwsArgumentError,
    );
  });
}
