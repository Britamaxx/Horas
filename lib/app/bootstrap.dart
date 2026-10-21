part of '../main.dart';

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({
    required this.authRepository,
    required this.userProfileRepository,
    required this.progressRepository,
    required this.firebaseBackend,
    required this.dictionaryRepository,
    required this.quizRepository,
  });

  final AuthRepository? authRepository;
  final UserProfileRepository? userProfileRepository;
  final ProgressRepository? progressRepository;
  final Future<FirebaseBackend?>? firebaseBackend;
  final DictionaryRepository dictionaryRepository;
  final QuizRepository quizRepository;

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  final LearningProgressStore _progressStore = const LearningProgressStore();
  late Future<AppController> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadApp();
  }

  Future<AppController> _loadApp() async {
    // Mulai keduanya sekaligus: kamus diurai di isolate, Firebase init jalan
    // di sampingnya. (Sengaja bukan `.wait`, agar pesan error asli tetap utuh.)
    final indexFuture = widget.dictionaryRepository.loadIndex();
    // Bank soal dimuat bersamaan; gagal -> kosong -> soal otomatis dari kamus.
    final quizFuture = widget.quizRepository.loadQuestions().catchError(
      (Object _) => const <QuizBankQuestion>[],
    );
    final backendFuture =
        widget.firebaseBackend ?? Future<FirebaseBackend?>.value();
    final index = await indexFuture;
    final backend = await backendFuture;
    final quizBank = await quizFuture;
    final savedIds = await _progressStore.loadSavedEntryIds();
    final quizStats = await _progressStore.loadQuizStats();
    final guestSession = await _GuestSessionStore.load();
    return AppController(
      index: index,
      savedEntryIds: savedIds,
      quizStats: quizStats,
      guestSession: guestSession,
      quizBank: quizBank,
      authRepository: widget.authRepository ?? backend?.auth,
      userProfileRepository: widget.userProfileRepository ?? backend?.profiles,
      progressStore: _progressStore,
      progressRepository: widget.progressRepository ?? backend?.progress,
    );
  }

  void _retry() {
    setState(() => _loadFuture = _loadApp());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppController>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadErrorScreen(error: snapshot.error!, onRetry: _retry);
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _AuthGate(controller: snapshot.data!);
      },
    );
  }
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 44,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Kamus belum dapat dibuka',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Periksa file data kamus dan penyimpanan perangkat, lalu coba lagi.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

