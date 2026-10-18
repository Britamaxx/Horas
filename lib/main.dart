import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'data/auth_repository.dart';
import 'data/csv_dictionary_repository.dart';
import 'data/dictionary_cache_factory.dart';
import 'data/dictionary_index.dart';
import 'data/dictionary_repository.dart';
import 'data/firebase_bootstrap.dart';
import 'data/pending_sentence_exercise_repository.dart';
import 'data/progress_repository.dart';
import 'data/sentence_exercise_repository.dart';
import 'data/synced_dictionary_repository.dart';
import 'models/app_user.dart';
import 'models/dictionary_entry.dart';
import 'models/sentence_exercise.dart';
import 'models/user_profile.dart';
import 'data/user_profile_repository.dart';
import 'services/learning_progress_store.dart';

const _paper = Color(0xFFF6F0E4);
const _ink = Color(0xFF25231F);
const _studyGreen = Color(0xFF315A53);
const _marginRed = Color(0xFFA83D32);
const _gold = Color(0xFFE5C76B);

String _formatCount(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Layar pemuatan langsung tampil; Firebase dan kamus dimuat bersamaan di
  // _AppBootstrap. Hasil null = Firebase belum dikonfigurasi -> mode lokal.
  final backend = initializeFirebaseBackend();
  runApp(
    HorasApp(
      firebaseBackend: backend,
      // Kamus dari Firebase + salinan lokal; kamus CSV bawaan hanya cadangan
      // untuk pembukaan pertama tanpa internet.
      dictionaryRepository: SyncedDictionaryRepository(
        source: backend.then((value) => value?.dictionary),
        cache: createDictionaryCache(),
        fallback: const CsvDictionaryRepository(),
      ),
    ),
  );
}

class HorasApp extends StatelessWidget {
  const HorasApp({
    super.key,
    this.authRepository,
    this.userProfileRepository,
    this.progressRepository,
    this.firebaseBackend,
    this.dictionaryRepository = const CsvDictionaryRepository(),
    this.sentenceExerciseRepository = const PendingSentenceExerciseRepository(),
  });

  final AuthRepository? authRepository;
  final UserProfileRepository? userProfileRepository;
  final ProgressRepository? progressRepository;

  /// Hasil `initializeFirebaseBackend()`; diabaikan jika repository di atas
  /// diberikan langsung (mis. di tes).
  final Future<FirebaseBackend?>? firebaseBackend;
  final DictionaryRepository dictionaryRepository;
  final SentenceExerciseRepository sentenceExerciseRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horas - Belajar Bahasa Batak',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: _AppBootstrap(
        authRepository: authRepository,
        userProfileRepository: userProfileRepository,
        progressRepository: progressRepository,
        firebaseBackend: firebaseBackend,
        dictionaryRepository: dictionaryRepository,
        sentenceExerciseRepository: sentenceExerciseRepository,
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _studyGreen,
        brightness: brightness,
      ).copyWith(
        primary: isDark ? const Color(0xFFA6C9BE) : _studyGreen,
        onPrimary: isDark ? const Color(0xFF153B34) : Colors.white,
        secondary: isDark ? const Color(0xFFE6A093) : _marginRed,
        onSecondary: isDark ? const Color(0xFF4C150F) : Colors.white,
        primaryContainer: isDark
            ? const Color(0xFF34463F)
            : const Color(0xFFDCE8E1),
        onPrimaryContainer: isDark
            ? const Color(0xFFE5F1EB)
            : const Color(0xFF153B34),
        surface: isDark ? const Color(0xFF1D211F) : _paper,
        onSurface: isDark ? const Color(0xFFEAE5DB) : _ink,
        surfaceContainerLow: isDark
            ? const Color(0xFF252A27)
            : const Color(0xFFFFFCF6),
        surfaceContainerHighest: isDark
            ? const Color(0xFF343A36)
            : const Color(0xFFECE5D9),
        outline: isDark ? const Color(0xFF858B84) : const Color(0xFF817D73),
      );
  final surface = scheme.surface;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.65)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      height: 76,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : null,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 31, height: 1.12),
      headlineSmall: TextStyle(fontSize: 26, height: 1.15),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    ),
  );
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({
    required this.authRepository,
    required this.userProfileRepository,
    required this.progressRepository,
    required this.firebaseBackend,
    required this.dictionaryRepository,
    required this.sentenceExerciseRepository,
  });

  final AuthRepository? authRepository;
  final UserProfileRepository? userProfileRepository;
  final ProgressRepository? progressRepository;
  final Future<FirebaseBackend?>? firebaseBackend;
  final DictionaryRepository dictionaryRepository;
  final SentenceExerciseRepository sentenceExerciseRepository;

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
    final backendFuture =
        widget.firebaseBackend ?? Future<FirebaseBackend?>.value();
    final index = await indexFuture;
    final backend = await backendFuture;
    final savedIds = await _progressStore.loadSavedEntryIds();
    final quizStats = await _progressStore.loadQuizStats();
    final sentenceExercises = await widget.sentenceExerciseRepository
        .loadExercises(dialect: 'toba');
    return AppController(
      index: index,
      savedEntryIds: savedIds,
      quizStats: quizStats,
      sentenceExercises: sentenceExercises,
      authRepository: widget.authRepository ?? backend?.auth,
      userProfileRepository:
          widget.userProfileRepository ?? backend?.profiles,
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
        return _AppShell(controller: snapshot.data!);
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

class AppController extends ChangeNotifier {
  AppController({
    required this.index,
    required this.savedEntryIds,
    required this.quizStats,
    required this.sentenceExercises,
    required this.authRepository,
    required this.userProfileRepository,
    required this.progressStore,
    this.progressRepository,
  }) : _activeStore = progressStore {
    final authRepository = this.authRepository;
    if (authRepository != null) {
      _authSubscription = authRepository.authStateChanges.listen(
        (user) => unawaited(_handleAuthState(user)),
        onError: (Object error) {
          authError = error;
          if (!_disposed) notifyListeners();
        },
      );
    }
  }

  final DictionaryIndex index;
  final List<SentenceExercise> sentenceExercises;
  final AuthRepository? authRepository;
  final UserProfileRepository? userProfileRepository;
  final ProgressRepository? progressRepository;

  /// Cache lokal mode TAMU (kunci lama). Akun memakai cache sendiri per uid.
  final LearningProgressStore progressStore;
  LearningProgressStore _activeStore;
  String? _progressUid;

  Set<String> savedEntryIds;
  QuizStats quizStats;
  AppUser? currentUser;
  UserProfile? userProfile;
  Object? authError;
  Object? profileError;
  Object? progressError;
  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<ProgressSnapshot>? _progressSubscription;
  bool _disposed = false;

  List<DictionaryEntry> get entries => index.entries;

  bool isSaved(DictionaryEntry entry) => savedEntryIds.contains(entry.id);

  /// Kata tersimpan dalam urutan kamus, tanpa memindai seluruh kamus.
  List<DictionaryEntry> savedEntries({int? limit}) =>
      index.entriesForIds(savedEntryIds, limit: limit);

  // --- Progres: perbarui lokal dulu (UI instan, jalan offline), lalu kirim ke
  // --- Firestore di latar belakang tanpa menunggu balasan server.

  Future<void> toggleSaved(DictionaryEntry entry) async {
    final next = Set<String>.from(savedEntryIds);
    final nowSaved = next.add(entry.id);
    if (!nowSaved) next.remove(entry.id);
    await _activeStore.saveEntryIds(next);
    savedEntryIds = next;
    notifyListeners();
    _pushToCloud(
      (repository, uid) =>
          repository.setEntrySaved(uid, entry.id, saved: nowSaved),
    );
  }

  Future<void> recordQuiz(int correct, int total) async {
    await _activeStore.recordQuiz(correct, total);
    quizStats = quizStats.recordQuiz(correct, total);
    notifyListeners();
    _pushToCloud((repository, uid) => repository.recordQuiz(uid, correct, total));
  }

  void _pushToCloud(
    Future<void> Function(ProgressRepository repository, String uid) action,
  ) {
    final repository = progressRepository;
    final uid = _progressUid;
    if (repository == null || uid == null) return;
    unawaited(
      action(repository, uid).catchError((Object error) {
        progressError = error;
        if (!_disposed) notifyListeners();
      }),
    );
  }

  /// Dipanggil setiap status login berubah (termasuk sesi yang dipulihkan saat
  /// aplikasi dibuka): beralih ke progres akun tersebut, atau kembali ke tamu.
  Future<void> _switchProgressAccount(AppUser? user) async {
    final uid = user?.uid;
    _progressUid = uid;
    final previous = _progressSubscription;
    _progressSubscription = null;
    await previous?.cancel();
    progressError = null;

    // Tampilkan dulu cache lokal milik akun ini (instan, bisa offline).
    final store = uid == null
        ? progressStore
        : LearningProgressStore.forUser(uid);
    final saved = await store.loadSavedEntryIds();
    final stats = await store.loadQuizStats();
    if (_disposed || _progressUid != uid) return;
    _activeStore = store;
    savedEntryIds = saved;
    quizStats = stats;
    notifyListeners();
    if (uid == null) return;

    await _moveGuestProgressToAccount(uid, store);
    if (_disposed || _progressUid != uid) return;

    final repository = progressRepository;
    if (repository == null) return;
    _progressSubscription = repository
        .watchProgress(uid)
        .listen(
          (snapshot) => unawaited(_applyCloudProgress(uid, snapshot)),
          onError: (Object error) {
            progressError = error;
            if (!_disposed) notifyListeners();
          },
        );
  }

  /// Progres yang dikumpulkan sebelum login (mode tamu) digabung ke akun
  /// pertama yang masuk di perangkat ini, lalu data tamu dikosongkan agar
  /// tidak ikut terhitung lagi ke akun lain.
  Future<void> _moveGuestProgressToAccount(
    String uid,
    LearningProgressStore accountStore,
  ) async {
    final repository = progressRepository;
    if (repository == null) return;

    final guestIds = await progressStore.loadSavedEntryIds();
    final guestStats = await progressStore.loadQuizStats();
    if (guestIds.isEmpty && guestStats.isEmpty) return;
    if (_disposed || _progressUid != uid) return;

    final guest = ProgressSnapshot(
      savedEntryIds: guestIds,
      quizStats: guestStats,
    );
    final mergedIds = <String>{...savedEntryIds, ...guestIds};
    final mergedStats = quizStats + guestStats;
    await accountStore.saveEntryIds(mergedIds);
    await accountStore.saveQuizStats(mergedStats);
    await progressStore.clear();
    if (_disposed || _progressUid != uid) return;
    savedEntryIds = mergedIds;
    quizStats = mergedStats;
    notifyListeners();

    unawaited(
      repository.mergeGuestProgress(uid, guest).catchError((Object error) async {
        progressError = error;
        // Gagal terkirim: kembalikan ke penyimpanan tamu agar tidak hilang.
        await _restoreGuestProgress(guest);
        if (!_disposed) notifyListeners();
      }),
    );
  }

  Future<void> _restoreGuestProgress(ProgressSnapshot guest) async {
    final ids = await progressStore.loadSavedEntryIds();
    final stats = await progressStore.loadQuizStats();
    await progressStore.saveEntryIds(<String>{...ids, ...guest.savedEntryIds});
    await progressStore.saveQuizStats(stats + guest.quizStats);
  }

  /// Data terkonfirmasi server (mis. perubahan dari perangkat lain).
  Future<void> _applyCloudProgress(
    String uid,
    ProgressSnapshot snapshot,
  ) async {
    if (_disposed || _progressUid != uid) return;
    savedEntryIds = snapshot.savedEntryIds;
    quizStats = snapshot.quizStats;
    notifyListeners();
    try {
      await _activeStore.saveEntryIds(snapshot.savedEntryIds);
      await _activeStore.saveQuizStats(snapshot.quizStats);
    } catch (error) {
      progressError = error;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    final repository = authRepository;
    if (repository == null) {
      throw StateError('Firebase Authentication belum dikonfigurasi.');
    }
    await repository.signInWithGoogle();
  }

  Future<void> signOut() async {
    final repository = authRepository;
    if (repository == null) {
      throw StateError('Firebase Authentication belum dikonfigurasi.');
    }
    await repository.signOut();
  }

  Future<void> _handleAuthState(AppUser? user) async {
    currentUser = user;
    userProfile = null;
    authError = null;
    profileError = null;
    if (!_disposed) notifyListeners();

    unawaited(_switchProgressAccount(user));

    final profileRepository = userProfileRepository;
    if (user == null || profileRepository == null) return;

    try {
      final existingProfile = await profileRepository.getProfile(user.uid);
      if (_disposed || currentUser?.uid != user.uid) return;
      final now = DateTime.now().toUtc();
      final profile = UserProfile(
        uid: user.uid,
        displayName: user.displayName ?? existingProfile?.displayName,
        email: user.email ?? existingProfile?.email,
        photoUrl: user.photoUrl ?? existingProfile?.photoUrl,
        providerIds: user.providerIds,
        preferredDialect: existingProfile?.preferredDialect,
        createdAt: existingProfile?.createdAt ?? user.createdAt ?? now,
        lastSignInAt: user.lastSignInAt ?? existingProfile?.lastSignInAt,
        updatedAt: now,
      );
      await profileRepository.saveProfile(profile);
      if (_disposed || currentUser?.uid != user.uid) return;
      userProfile = profile;
    } catch (error) {
      if (_disposed || currentUser?.uid != user.uid) return;
      profileError = error;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_authSubscription?.cancel());
    unawaited(_progressSubscription?.cancel());
    super.dispose();
  }
}

enum _PracticeMode { quiz, sentences }

class _AppShell extends StatefulWidget {
  const _AppShell({required this.controller});

  final AppController controller;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  String _dictionaryQuery = '';
  int _dictionaryEpoch = 0;
  _PracticeMode _initialPracticeMode = _PracticeMode.quiz;
  int _practiceEpoch = 0;

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _openDictionary([String query = '']) {
    setState(() {
      _selectedIndex = 1;
      _dictionaryQuery = query;
      _dictionaryEpoch++;
    });
  }

  void _openPractice(_PracticeMode mode) {
    setState(() {
      _selectedIndex = 2;
      _initialPracticeMode = mode;
      _practiceEpoch++;
    });
  }

  List<Widget> get _pages => [
    _HomeScreen(
      controller: widget.controller,
      onOpenDictionary: _openDictionary,
      onOpenPractice: _openPractice,
    ),
    _DictionaryScreen(
      key: ValueKey(_dictionaryEpoch),
      controller: widget.controller,
      initialQuery: _dictionaryQuery,
    ),
    _PracticeScreen(
      key: ValueKey(_practiceEpoch),
      controller: widget.controller,
      initialMode: _initialPracticeMode,
    ),
    _ProfileScreen(
      controller: widget.controller,
      onOpenDictionary: _openDictionary,
    ),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Beranda',
    ),
    NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Kamus'),
    NavigationDestination(
      icon: Icon(Icons.edit_note_rounded),
      selectedIcon: Icon(Icons.edit_note_rounded),
      label: 'Latihan',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        labelType: constraints.maxWidth >= 900
                            ? NavigationRailLabelType.all
                            : NavigationRailLabelType.selected,
                        destinations: _destinations
                            .map(
                              (destination) => NavigationRailDestination(
                                icon: destination.icon,
                                selectedIcon: destination.selectedIcon,
                                label: Text(destination.label),
                              ),
                            )
                            .toList(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: _pages,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              body: IndexedStack(index: _selectedIndex, children: _pages),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                destinations: _destinations,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen({
    required this.controller,
    required this.onOpenDictionary,
    required this.onOpenPractice,
  });

  final AppController controller;
  final ValueChanged<String> onOpenDictionary;
  final ValueChanged<_PracticeMode> onOpenPractice;

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    widget.onOpenDictionary(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final savedEntries = widget.controller.savedEntries(limit: 3);
    final quizStats = widget.controller.quizStats;
    final hasStudied =
        quizStats.completedQuizzes > 0 || savedEntries.isNotEmpty;
    final reviewEntry = savedEntries.isEmpty ? null : savedEntries.first;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final practicePanel = _TodayPracticePanel(
            title: reviewEntry == null
                ? quizStats.completedQuizzes > 0
                      ? 'Kuis kosakata berikutnya'
                      : 'Kuis kosakata'
                : 'Kata tersimpanmu',
            description: reviewEntry == null
                ? quizStats.completedQuizzes > 0
                      ? '${quizStats.completedQuizzes} kuis selesai · ${quizStats.answeredQuestions} soal dijawab.'
                      : 'Pilih padanan Batak untuk kata-kata dari kamus.'
                : 'Kata tersimpan pilihanmu: “${reviewEntry.headword}” dan lainnya.',
            actionLabel: reviewEntry == null ? 'Mulai kuis' : 'Buka kata',
            onStart: reviewEntry == null
                ? () => widget.onOpenPractice(_PracticeMode.quiz)
                : () => widget.onOpenDictionary(reviewEntry.headword),
          );

          final quickActions = Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.search_rounded,
                  label: 'Jelajahi kamus',
                  onTap: () => widget.onOpenDictionary(''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.format_list_bulleted_rounded,
                  label: 'Susun kalimat',
                  onTap: () => widget.onOpenPractice(_PracticeMode.sentences),
                ),
              ),
            ],
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 20,
                  isWide ? 28 : 20,
                  isWide ? 32 : 20,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: scheme.onPrimary,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Horas',
                                style: theme.textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Belajar bahasa Batak',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_formatCount(widget.controller.entries.length)} entri',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isWide ? 48 : 34),
                    Text(
                      hasStudied
                          ? 'Senang belajar lagi?'
                          : 'Mulai dari satu kata.',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        hasStudied
                            ? 'Kata pilihan dan latihanmu tersimpan di perangkat ini.'
                            : 'Cari arti kata, simpan pilihanmu, lalu latih ingatan lewat kuis.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                _buildSearchField(),
                                const SizedBox(height: 20),
                                practicePanel,
                                const SizedBox(height: 16),
                                quickActions,
                              ],
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            flex: 5,
                            child: _buildSavedWordsSection(
                              context,
                              savedEntries,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildSearchField(),
                      const SizedBox(height: 22),
                      practicePanel,
                      const SizedBox(height: 16),
                      quickActions,
                      const SizedBox(height: 30),
                      _buildSavedWordsSection(context, savedEntries),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        hintText: 'Cari kata Indonesia atau Batak',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Cari di kamus',
          onPressed: _search,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
  }

  Widget _buildSavedWordsSection(
    BuildContext context,
    List<DictionaryEntry> savedEntries,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                savedEntries.isEmpty ? 'Mulai dari kamus' : 'Kata pilihanmu',
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (savedEntries.isNotEmpty)
              TextButton(
                onPressed: () => widget.onOpenDictionary(''),
                child: const Text('Semua'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          savedEntries.isEmpty
              ? 'Simpan kata yang ingin kamu ingat; kata itu akan muncul di sini.'
              : 'Lanjutkan dari kosakata yang sudah kamu simpan.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (savedEntries.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bookmark_add_outlined, color: scheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belum ada kata tersimpan',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih ikon penanda di kamus untuk menyimpan kata.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => widget.onOpenDictionary(''),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Buka kamus'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...savedEntries.map(
            (entry) => _DictionaryEntryTile(
              entry: entry,
              saved: widget.controller.isSaved(entry),
              onOpen: () =>
                  _showEntryDetails(context, entry, widget.controller),
              onToggleSaved: () => widget.controller.toggleSaved(entry),
            ),
          ),
      ],
    );
  }
}

class _TodayPracticePanel extends StatelessWidget {
  const _TodayPracticePanel({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onStart,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _studyGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showBookMark = constraints.maxWidth >= 400;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE3ECE6),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _paper,
                  foregroundColor: _ink,
                ),
                onPressed: onStart,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel),
              ),
            ],
          );

          if (!showBookMark) return content;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: _gold,
                  size: 32,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _DictionaryScreen extends StatefulWidget {
  const _DictionaryScreen({
    super.key,
    required this.controller,
    required this.initialQuery,
  });

  final AppController controller;
  final String initialQuery;

  @override
  State<_DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<_DictionaryScreen> {
  late final TextEditingController _searchController;
  String _query = '';
  String _partOfSpeech = 'ALL';
  int _visibleLimit = 60;
  Timer? _searchDebounce;
  late List<DictionaryEntry> _results;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController = TextEditingController(text: _query);
    _results = _runSearch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Pencarian hanya dijalankan saat kata kunci/filter berubah, bukan setiap
  // build, sehingga menyimpan kata atau berpindah tab tidak menyaring ulang.
  List<DictionaryEntry> _runSearch() => widget.controller.index.search(
    _query,
    partOfSpeech: _partOfSpeech,
  );

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _visibleLimit = 60;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _results = _runSearch());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final normalizedQuery = _query.trim();
    final results = _results;
    final shownCount = min(results.length, _visibleLimit);
    final dictionaryIndex = widget.controller.index;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kamus Batak', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Cari dalam kata Indonesia atau padanan Batak.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Contoh: abang',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              _searchDebounce?.cancel();
                              setState(() {
                                _query = '';
                                _visibleLimit = 60;
                                _results = _runSearch();
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _partOfSpeech,
                  decoration: const InputDecoration(
                    labelText: 'Kelas kata',
                    prefixIcon: Icon(Icons.tune_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ALL',
                      child: Text('Semua kelas kata'),
                    ),
                    ...dictionaryIndex.partsOfSpeech.map(
                      (part) => DropdownMenuItem(
                        value: part,
                        child: Text(dictionaryIndex.partLabels[part] ?? part),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _partOfSpeech = value ?? 'ALL';
                    _visibleLimit = 60;
                    _results = _runSearch();
                  }),
                ),
                const SizedBox(height: 14),
                Text(
                  normalizedQuery.isEmpty && _partOfSpeech == 'ALL'
                      ? '${results.length} entri kamus'
                      : '${results.length} hasil',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: results.isEmpty
                      ? _EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Kata belum ditemukan',
                          message:
                              'Coba kata lain atau pilih semua kelas kata.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24, top: 4),
                          itemCount:
                              shownCount +
                              (results.length > shownCount ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, indent: 48),
                          itemBuilder: (context, index) {
                            if (index == shownCount) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _visibleLimit += 60),
                                  child: Text(
                                    'Tampilkan ${min(60, results.length - shownCount)} kata lagi',
                                  ),
                                ),
                              );
                            }
                            final entry = results[index];
                            return _DictionaryEntryTile(
                              entry: entry,
                              saved: widget.controller.isSaved(entry),
                              onOpen: () => _showEntryDetails(
                                context,
                                entry,
                                widget.controller,
                              ),
                              onToggleSaved: () =>
                                  widget.controller.toggleSaved(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DictionaryEntryTile extends StatelessWidget {
  const _DictionaryEntryTile({
    required this.entry,
    required this.saved,
    required this.onOpen,
    required this.onToggleSaved,
  });

  final DictionaryEntry entry;
  final bool saved;
  final VoidCallback onOpen;
  final Future<void> Function() onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  saved ? Icons.bookmark_rounded : Icons.menu_book_outlined,
                  color: saved ? scheme.secondary : scheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.headword, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      entry.definitions,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.partOfSpeechLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved ? 'Hapus dari kata tersimpan' : 'Simpan kata',
                onPressed: () => _performSavedAction(context, onToggleSaved),
                icon: Icon(
                  saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  color: saved ? scheme.secondary : scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showEntryDetails(
  BuildContext context,
  DictionaryEntry entry,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.headword,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.partOfSpeechLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(entry.definitions, style: theme.textTheme.bodyLarge),
              if (entry.semanticCategories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Kategori: ${entry.semanticCategories}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (entry.sourceDialect.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Dialek sumber: ${entry.sourceDialect}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await controller.toggleSaved(entry);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kata tidak dapat disimpan: $error'),
                      ),
                    );
                    return;
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                icon: Icon(
                  controller.isSaved(entry)
                      ? Icons.bookmark_remove_outlined
                      : Icons.bookmark_add_outlined,
                ),
                label: Text(
                  controller.isSaved(entry)
                      ? 'Hapus dari kata tersimpan'
                      : 'Simpan kata',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _performSavedAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kata tidak dapat disimpan: $error')),
    );
  }
}

class _PracticeScreen extends StatefulWidget {
  const _PracticeScreen({
    super.key,
    required this.controller,
    required this.initialMode,
  });

  final AppController controller;
  final _PracticeMode initialMode;

  @override
  State<_PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<_PracticeScreen> {
  late _PracticeMode _mode;
  late List<_QuizQuestion> _questions;
  SentenceExercise? _activeSentenceExercise;
  List<int> _availableSentenceTokenIndices = [];
  final List<int> _arrangedSentenceTokenIndices = [];
  bool? _sentenceIsCorrect;
  int _questionIndex = 0;
  int _correctAnswers = 0;
  String? _selectedAnswer;
  bool _quizFinished = false;
  bool _savingQuiz = false;
  String? _quizSaveError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _questions = _createQuizQuestions(widget.controller.index);
    _startSentenceExercise();
  }

  void _selectMode(_PracticeMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      if (mode == _PracticeMode.quiz) _restartQuiz();
      if (mode == _PracticeMode.sentences) _startSentenceExercise();
    });
  }

  void _restartQuiz() {
    _questions = _createQuizQuestions(widget.controller.index);
    _questionIndex = 0;
    _correctAnswers = 0;
    _selectedAnswer = null;
    _quizFinished = false;
    _quizSaveError = null;
  }

  void _startSentenceExercise() {
    final exercises = widget.controller.sentenceExercises;
    _activeSentenceExercise = exercises.isEmpty
        ? null
        : exercises[Random().nextInt(exercises.length)];
    _availableSentenceTokenIndices = List<int>.generate(
      _activeSentenceExercise?.tokens.length ?? 0,
      (index) => index,
    )..shuffle();
    _arrangedSentenceTokenIndices.clear();
    _sentenceIsCorrect = null;
  }

  Future<void> _continueQuiz() async {
    final selected = _selectedAnswer;
    if (selected == null || _savingQuiz || _quizFinished) return;

    final question = _questions[_questionIndex];
    final nextCorrect =
        _correctAnswers + (selected == question.correctDefinition ? 1 : 0);
    if (_questionIndex < _questions.length - 1) {
      setState(() {
        _correctAnswers = nextCorrect;
        _questionIndex++;
        _selectedAnswer = null;
      });
      return;
    }

    setState(() {
      _correctAnswers = nextCorrect;
      _savingQuiz = true;
      _quizSaveError = null;
    });
    try {
      await widget.controller.recordQuiz(nextCorrect, _questions.length);
      if (!mounted) return;
      setState(() {
        _savingQuiz = false;
        _quizFinished = true;
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
                  'Latih ingatan dan susun kalimat Batak Toba.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<_PracticeMode>(
                  segments: const [
                    ButtonSegment(
                      value: _PracticeMode.quiz,
                      icon: Icon(Icons.quiz_outlined),
                      label: Text('Kuis'),
                    ),
                    ButtonSegment(
                      value: _PracticeMode.sentences,
                      icon: Icon(Icons.format_list_bulleted_rounded),
                      label: Text('Susun kalimat'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (values) => _selectMode(values.first),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: _mode == _PracticeMode.quiz
                      ? _buildQuiz(theme)
                      : _buildSentencePractice(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz(ThemeData theme) {
    if (_quizFinished) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 52,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('Kuis selesai', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Jawaban tepat: $_correctAnswers dari ${_questions.length}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => setState(_restartQuiz),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba kuis lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const _EmptyState(
        icon: Icons.quiz_outlined,
        title: 'Kuis belum tersedia',
        message: 'Kamus belum memiliki cukup entri untuk membuat kuis.',
      );
    }

    final question = _questions[_questionIndex];
    final selected = _selectedAnswer;
    final hasAnswered = selected != null;

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
              '${_questionIndex + 1} / ${_questions.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.answer.partOfSpeechLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question.answer.headword,
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
          final isCorrect = option == question.correctDefinition;
          final showCorrect = hasAnswered && isCorrect;
          final showIncorrect = hasAnswered && isSelected && !isCorrect;
          final color = showCorrect
              ? theme.colorScheme.primary
              : showIncorrect
              ? theme.colorScheme.error
              : theme.colorScheme.outlineVariant;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: option,
              child: Material(
                color: isSelected
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: hasAnswered
                      ? null
                      : () => setState(() => _selectedAnswer = option),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color,
                        width: isSelected || showCorrect ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          showCorrect
                              ? Icons.check_circle_rounded
                              : showIncorrect
                              ? Icons.cancel_rounded
                              : isSelected
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
        if (hasAnswered) ...[
          const SizedBox(height: 4),
          Text(
            selected == question.correctDefinition
                ? 'Benar. Padanan mengikuti data kamus.'
                : 'Padanan dalam kamus: ${question.correctDefinition}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected == question.correctDefinition
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
          if (_quizSaveError != null) ...[
            const SizedBox(height: 8),
            Text(
              _quizSaveError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _savingQuiz ? null : _continueQuiz,
            child: _savingQuiz
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _questionIndex == _questions.length - 1
                        ? 'Selesaikan kuis'
                        : 'Soal berikutnya',
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildSentencePractice(ThemeData theme) {
    final exercises = widget.controller.sentenceExercises;
    if (exercises.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 40),
          const _EmptyState(
            icon: Icons.format_list_bulleted_rounded,
            title: 'Materi kalimat belum tersedia',
            message: 'Latihan susun kalimat Batak Toba akan dibuka setelah sumber kalimat tervalidasi disiapkan.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Kamus kosakata tidak memuat contoh kalimat atau aturan tata bahasa. Karena itu, aplikasi belum membuat atau menilai kalimat sendiri.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final exercise = _activeSentenceExercise ?? exercises.first;
    final tokens = exercise.tokens;
    final hasUsedAllTokens =
        _arrangedSentenceTokenIndices.length == tokens.length;
    final sentenceMatches =
        hasUsedAllTokens &&
        List<int>.generate(
          tokens.length,
          (index) => index,
        ).every((index) => _arrangedSentenceTokenIndices[index] == index);
    final hasCheckedAnswer = _sentenceIsCorrect != null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text('Susun padanan kalimat', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Urutkan kata dari materi Batak Toba yang sudah diperiksa.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bahasa Indonesia · ${exercise.dialect}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                exercise.indonesianPrompt,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Susunanmu', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 66),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _arrangedSentenceTokenIndices.isEmpty
              ? Text(
                  'Pilih kata di bawah untuk mulai menyusun.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tokenIndex in _arrangedSentenceTokenIndices)
                      InputChip(
                        label: Text(tokens[tokenIndex]),
                        onDeleted: hasCheckedAnswer
                            ? null
                            : () => setState(() {
                                _arrangedSentenceTokenIndices.remove(
                                  tokenIndex,
                                );
                                _availableSentenceTokenIndices.add(tokenIndex);
                              }),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Text('Kata yang tersedia', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tokenIndex in _availableSentenceTokenIndices)
              ActionChip(
                label: Text(tokens[tokenIndex]),
                onPressed: hasCheckedAnswer
                    ? null
                    : () => setState(() {
                        _availableSentenceTokenIndices.remove(tokenIndex);
                        _arrangedSentenceTokenIndices.add(tokenIndex);
                      }),
              ),
          ],
        ),
        if (hasCheckedAnswer) ...[
          const SizedBox(height: 18),
          Text(
            _sentenceIsCorrect!
                ? 'Susunan cocok dengan urutan pada sumber.'
                : 'Bandingkan lagi urutan kata dengan materi sumber.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: _sentenceIsCorrect!
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!_sentenceIsCorrect!) ...[
            const SizedBox(height: 6),
            Text(
              'Urutan pada sumber: ${exercise.batakSentence}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Sumber: ${exercise.sourceName} · ${exercise.sourceReference}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: hasCheckedAnswer
              ? () => setState(_startSentenceExercise)
              : hasUsedAllTokens
              ? () => setState(() => _sentenceIsCorrect = sentenceMatches)
              : null,
          child: Text(
            hasCheckedAnswer ? 'Kalimat berikutnya' : 'Periksa susunan',
          ),
        ),
      ],
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.answer,
    required this.correctDefinition,
    required this.options,
  });

  final DictionaryEntry answer;
  final String correctDefinition;
  final List<String> options;
}

/// Soal diambil acak dari data yang sudah disiapkan di [DictionaryIndex],
/// jadi membuka tab Latihan atau mengulang kuis tidak lagi memindai kamus.
List<_QuizQuestion> _createQuizQuestions(DictionaryIndex index) {
  final seeds = index.quizSeeds;
  final pool = index.distractorPool;
  if (seeds.isEmpty || pool.length < 2) return const [];

  final random = Random();
  final questionCount = min(10, seeds.length);
  final picked = <int>{};
  while (picked.length < questionCount) {
    picked.add(random.nextInt(seeds.length));
  }

  return picked
      .map((seedIndex) {
        final seed = seeds[seedIndex];
        final wanted = min(3, pool.length - 1);
        final distractors = <String>{};
        var attempts = 0;
        while (distractors.length < wanted && attempts < 200) {
          attempts++;
          final candidate = pool[random.nextInt(pool.length)];
          if (candidate != seed.definition) distractors.add(candidate);
        }
        final options = <String>[seed.definition, ...distractors]
          ..shuffle(random);
        return _QuizQuestion(
          answer: seed.entry,
          correctDefinition: seed.definition,
          options: List.unmodifiable(options),
        );
      })
      .toList(growable: false);
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen({
    required this.controller,
    required this.onOpenDictionary,
  });

  final AppController controller;
  final ValueChanged<String> onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final savedEntries = controller.savedEntries();
    final stats = controller.quizStats;
    final accuracy = stats.answeredQuestions == 0
        ? '—'
        : '${(stats.accuracy * 100).round()}%';
    final user = controller.currentUser;
    final authConfigured = controller.authRepository != null;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Text('Profil belajar', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Kelola akun dan lihat perjalanan belajarmu.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user == null ? 'AKUN BELUM AKTIF' : 'AKUN TERSAMBUNG',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: user == null ? scheme.secondary : scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.userProfile?.displayName ??
                          user?.displayName ??
                          'Belajar di perangkat ini',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.userProfile?.email ??
                          user?.email ??
                          'Masuk untuk menyiapkan sinkronisasi progres.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (user == null)
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                _LoginScreen(controller: controller),
                          ),
                        ),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Lihat opsi masuk'),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Akun masuk melalui ${user.providerIds.join(', ')}.',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (authConfigured) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  await controller.signOut();
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Tidak dapat keluar dari akun: $error',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Keluar dari akun'),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              if (controller.authError != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Status autentikasi tidak dapat dimuat: '
                  '${controller.authError}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              if (controller.profileError != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Profil Firebase belum tersimpan: '
                  '${controller.profileError}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              if (controller.progressError != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Progres belum tersinkronisasi: '
                  '${controller.progressError}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Ringkasan belajar', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              _ProgressLine(
                label: 'Kuis selesai',
                value: '${stats.completedQuizzes}',
              ),
              _ProgressLine(
                label: 'Jawaban benar',
                value: '${stats.correctAnswers} / ${stats.answeredQuestions}',
              ),
              _ProgressLine(label: 'Akurasi latihan', value: accuracy),
              _ProgressLine(
                label: 'Kata tersimpan',
                value: '${savedEntries.length}',
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kata tersimpan',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${savedEntries.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (savedEntries.isEmpty)
                _EmptyState(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Belum ada kata tersimpan',
                  message: 'Simpan kata dari kamus, lalu kembali ke sini untuk mengulanginya.',
                  actionLabel: 'Buka kamus',
                  onAction: () => onOpenDictionary(''),
                )
              else
                ...savedEntries.map(
                  (entry) => _DictionaryEntryTile(
                    entry: entry,
                    saved: true,
                    onOpen: () => _showEntryDetails(context, entry, controller),
                    onToggleSaved: () => controller.toggleSaved(entry),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                user != null && controller.progressRepository != null
                    ? 'Kata tersimpan dan hasil kuis tersinkronisasi ke akunmu, dan tetap bisa dibuka tanpa internet.'
                    : authConfigured
                    ? 'Masuk dengan Google agar kata tersimpan dan hasil kuis tersimpan di akunmu. Sementara ini progres hanya ada di perangkat ini.'
                    : 'Progres tersimpan di perangkat ini. Login Google dan sinkronisasi Firebase belum diaktifkan.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cloudflare Turnstile dapat membantu verifikasi anti-bot; '
                'fitur itu bukan metode login.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({required this.controller});

  final AppController controller;

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  bool _isSigningIn = false;
  String? _signInError;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _signInError = null;
    });
    try {
      await widget.controller.signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _signInError = 'Login Google gagal: $error');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final authConfigured = widget.controller.authRepository != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Masuk ke Horas')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
              children: [
                Icon(Icons.menu_book_rounded, size: 48, color: scheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Satu akun untuk progresmu.',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk dengan Google agar profil dan kemajuan belajar '
                  'dapat disiapkan untuk sinkronisasi Firebase.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: authConfigured && !_isSigningIn
                      ? _signInWithGoogle
                      : null,
                  icon: _isSigningIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_circle_outlined),
                  label: const Text('Lanjutkan dengan Google'),
                ),
                if (_signInError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _signInError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    authConfigured
                        ? 'Firebase Authentication sudah tersedia. '
                              'Profil pengguna akan tersimpan melalui '
                              'repository akun.'
                        : 'Login belum aktif. Firebase project, konfigurasi '
                              'FlutterFire, dan penyedia Google perlu disiapkan '
                              'terlebih dahulu. Tidak ada data login yang '
                              'dikirim dari layar ini.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cloudflare Turnstile bersifat opsional untuk verifikasi '
                  'anti-bot melalui endpoint server; rahasia Turnstile tidak '
                  'boleh ditanam di aplikasi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
