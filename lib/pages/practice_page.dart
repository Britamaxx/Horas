part of '../main.dart';

class _PracticeScreen extends StatefulWidget {
  const _PracticeScreen({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<_PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<_PracticeScreen> {
  late List<QuizItem> _questions;
  int _questionIndex = 0;
  int _finalCorrect = 0;
  late List<String?> _answers;
  _QuizPhase _quizPhase = _QuizPhase.intro;
  bool _quizGaveUp = false;
  bool _savingQuiz = false;
  String? _quizSaveError;

  @override
  void initState() {
    super.initState();
    _questions = buildQuizItems(
      index: widget.controller.index,
      bank: widget.controller.quizBank,
    );
    _answers = List<String?>.filled(_questions.length, null);
  }

  void _restartQuiz() {
    _questions = buildQuizItems(
      index: widget.controller.index,
      bank: widget.controller.quizBank,
    );
    _answers = List<String?>.filled(_questions.length, null);
    _questionIndex = 0;
    _finalCorrect = 0;
    _quizGaveUp = false;
    _quizPhase = _QuizPhase.intro;
    _quizSaveError = null;
  }

  int get _answeredCount => _answers.where((a) => a != null).length;

  void _startQuiz() {
    setState(() {
      _questionIndex = 0;
      _quizPhase = _QuizPhase.running;
    });
  }

  void _goToQuestion(int index) {
    if (index < 0 || index >= _questions.length || _savingQuiz) return;
    setState(() => _questionIndex = index);
  }

  void _selectAnswer(String option) {
    if (_savingQuiz) return;
    setState(() => _answers[_questionIndex] = option);
  }

  Future<void> _confirmEndQuiz({required bool giveUp}) async {
    final total = _questions.length;
    final answered = _answeredCount;
    final unanswered = total - answered;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(giveUp ? 'Menyerah?' : 'Akhiri kuis?'),
        content: Text(
          [
            'Kamu sudah menjawab $answered dari $total soal.',
            if (unanswered > 0)
              '$unanswered soal belum dijawab dan akan dihitung salah.',
            'Setelah kuis diakhiri, kamu tidak bisa melanjutkan lagi.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Lanjutkan kuis'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(giveUp ? 'Ya, menyerah' : 'Akhiri kuis'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finishQuiz(giveUp: giveUp);
  }

  Future<void> _finishQuiz({required bool giveUp}) async {
    if (_savingQuiz || _quizPhase != _QuizPhase.running) return;
    var correct = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].correctDefinition) correct++;
    }

    // Menyerah tanpa menjawab satu soal pun tidak dicatat sebagai kuis selesai.
    if (giveUp && _answeredCount == 0) {
      setState(_restartQuiz);
      return;
    }

    setState(() {
      _savingQuiz = true;
      _quizSaveError = null;
    });
    try {
      await widget.controller.recordQuiz(correct, _questions.length);
      if (!mounted) return;
      setState(() {
        _savingQuiz = false;
        _finalCorrect = correct;
        _quizGaveUp = giveUp;
        _quizPhase = _QuizPhase.finished;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingQuiz = false;
        _quizSaveError = 'Hasil kuis belum tersimpan: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Latihan', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Latih ingatan kosakata Batak Toba.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(child: _buildQuiz(theme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz(ThemeData theme) {
    if (_questions.isEmpty) {
      return const _EmptyState(
        icon: Icons.quiz_outlined,
        title: 'Kuis belum tersedia',
        message: 'Kamus belum memiliki cukup entri untuk membuat kuis.',
      );
    }
    switch (_quizPhase) {
      case _QuizPhase.intro:
        return _buildQuizIntro(theme);
      case _QuizPhase.running:
        return _buildQuizRunning(theme);
      case _QuizPhase.finished:
        return _buildQuizResult(theme);
    }
  }

  Widget _buildQuizIntro(ThemeData theme) {
    final instructions = [
      'Pilih padanan Indonesia yang tepat untuk setiap kata Batak.',
      'Kamu bebas pindah ke nomor soal mana pun, melewati soal sulit, lalu kembali lagi nanti.',
      'Jawaban bisa diubah kapan saja sebelum kuis diakhiri.',
      'Soal yang belum dijawab dihitung salah saat kuis diakhiri.',
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text('Kuis kosakata', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '${_questions.length} soal pilihan ganda · Batak Toba',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text('Petunjuk', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final line in instructions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startQuiz,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Mulai Kuis'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionNumber(ThemeData theme, int index) {
    final isCurrent = index == _questionIndex;
    final isAnswered = _answers[index] != null;
    final scheme = theme.colorScheme;
    final background = isCurrent
        ? scheme.primary
        : isAnswered
        ? scheme.secondaryContainer
        : scheme.surfaceContainerLow;
    final foreground = isCurrent
        ? scheme.onPrimary
        : isAnswered
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final borderColor = isCurrent || isAnswered
        ? scheme.primary
        : scheme.outlineVariant;
    final status = isCurrent
        ? 'sedang dibuka'
        : isAnswered
        ? 'sudah dijawab'
        : 'belum dijawab';
    return Semantics(
      button: true,
      selected: isCurrent,
      label: 'Soal ${index + 1}, $status',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _goToQuestion(index),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    ThemeData theme,
    Color fill,
    Color border,
    String text,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildQuizRunning(ThemeData theme) {
    final scheme = theme.colorScheme;
    final question = _questions[_questionIndex];
    final selected = _answers[_questionIndex];
    final total = _questions.length;
    final answered = _answeredCount;
    final isLast = _questionIndex == total - 1;

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pilih padanan Batak',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Text(
              'Soal ${_questionIndex + 1} / $total',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: answered / total,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$answered dari $total soal dijawab',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < total; i++) _buildQuestionNumber(theme, i),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _buildLegendItem(
              theme,
              scheme.primary,
              scheme.primary,
              'Sedang dibuka',
            ),
            _buildLegendItem(
              theme,
              scheme.secondaryContainer,
              scheme.primary,
              'Sudah dijawab',
            ),
            _buildLegendItem(
              theme,
              scheme.surfaceContainerLow,
              scheme.outlineVariant,
              'Belum dijawab',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.partOfSpeechLabel != null) ...[
                Text(
                  question.partOfSpeechLabel!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                question.word,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...question.options.map((option) {
          final isSelected = option == selected;
          final color = isSelected ? scheme.primary : scheme.outlineVariant;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: option,
              child: Material(
                color: isSelected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _selectAnswer(option),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: color,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(option)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        if (_quizSaveError != null) ...[
          const SizedBox(height: 4),
          Text(_quizSaveError!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _questionIndex == 0 || _savingQuiz
                    ? null
                    : () => _goToQuestion(_questionIndex - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Soal Sebelumnya'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isLast
                  ? FilledButton.icon(
                      onPressed: _savingQuiz
                          ? null
                          : () => _confirmEndQuiz(giveUp: false),
                      icon: _savingQuiz
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.flag_rounded),
                      label: const Text('Akhiri Kuis'),
                    )
                  : FilledButton.icon(
                      onPressed: _savingQuiz
                          ? null
                          : () => _goToQuestion(_questionIndex + 1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Soal Berikutnya'),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _savingQuiz ? null : () => _confirmEndQuiz(giveUp: true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            icon: const Icon(Icons.outlined_flag_rounded),
            label: const Text('Menyerah'),
          ),
        ),
      ],
    );
  }

  Widget _buildResultStat(
    ThemeData theme,
    String label,
    int value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizResult(ThemeData theme) {
    final scheme = theme.colorScheme;
    final total = _questions.length;
    final correct = _finalCorrect;
    final unanswered = _answers.where((a) => a == null).length;
    final wrong = total - correct - unanswered;
    final score = total == 0 ? 0 : (correct * 100 / total).round();

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        const SizedBox(height: 4),
        Center(
          child: Icon(
            _quizGaveUp ? Icons.flag_rounded : Icons.task_alt_rounded,
            size: 52,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _quizGaveUp ? 'Kuis diakhiri' : 'Kuis selesai',
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Skor $score · Jawaban tepat: $correct dari $total',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildResultStat(theme, 'Benar', correct, scheme.primary),
            const SizedBox(width: 10),
            _buildResultStat(theme, 'Salah', wrong, scheme.error),
            const SizedBox(width: 10),
            _buildResultStat(
              theme,
              'Belum dijawab',
              unanswered,
              scheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Tinjau jawaban', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        for (var i = 0; i < total; i++) _buildReviewTile(theme, i),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => setState(_restartQuiz),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba kuis lagi'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTile(ThemeData theme, int index) {
    final scheme = theme.colorScheme;
    final question = _questions[index];
    final chosen = _answers[index];
    final isCorrect = chosen == question.correctDefinition;
    final isUnanswered = chosen == null;
    final color = isCorrect
        ? scheme.primary
        : isUnanswered
        ? scheme.onSurfaceVariant
        : scheme.error;
    final icon = isCorrect
        ? Icons.check_circle_rounded
        : isUnanswered
        ? Icons.remove_circle_outline_rounded
        : Icons.cancel_rounded;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${question.word}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                if (isUnanswered)
                  Text('Belum dijawab', style: TextStyle(color: color))
                else if (!isCorrect)
                  Text('Jawabanmu: $chosen', style: TextStyle(color: color)),
                if (!isCorrect)
                  Text('Jawaban benar: ${question.correctDefinition}'),
                if (isCorrect)
                  Text(
                    question.correctDefinition,
                    style: TextStyle(color: color),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

