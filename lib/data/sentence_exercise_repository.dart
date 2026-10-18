import '../models/sentence_exercise.dart';

abstract interface class SentenceExerciseRepository {
  Future<List<SentenceExercise>> loadExercises({
    required String dialect,
  });
}
