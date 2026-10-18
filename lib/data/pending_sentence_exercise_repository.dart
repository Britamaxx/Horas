import '../models/sentence_exercise.dart';
import 'sentence_exercise_repository.dart';

class PendingSentenceExerciseRepository implements SentenceExerciseRepository {
  const PendingSentenceExerciseRepository();

  @override
  Future<List<SentenceExercise>> loadExercises({
    required String dialect,
  }) async {
    if (dialect != 'toba') {
      throw ArgumentError.value(dialect, 'dialect', 'Dialek tidak didukung.');
    }
    return const [];
  }
}
