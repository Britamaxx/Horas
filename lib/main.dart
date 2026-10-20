import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/auth_repository.dart';
import 'data/csv_dictionary_repository.dart';
import 'data/dictionary_cache_factory.dart';
import 'data/dictionary_index.dart';
import 'data/dictionary_repository.dart';
import 'data/firebase_bootstrap.dart';
import 'data/pending_sentence_exercise_repository.dart';
import 'data/progress_repository.dart';
import 'data/quiz_cache.dart';
import 'data/quiz_repository.dart';
import 'data/sentence_exercise_repository.dart';
import 'data/synced_dictionary_repository.dart';
import 'models/app_user.dart';
import 'models/dictionary_entry.dart';
import 'models/quiz_bank_question.dart';
import 'models/sentence_exercise.dart';
import 'models/user_profile.dart';
import 'data/user_profile_repository.dart';
import 'services/learning_progress_store.dart';
import 'services/quiz_builder.dart';

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
      // Bank soal kuis dari Firebase; kosong -> soal otomatis dari kamus.
      quizRepository: SyncedQuizRepository(
        source: backend.then((value) => value?.quiz),
        cache: const PrefsQuizCache(),
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
    this.quizRepository = const NoQuizRepository(),
    this.sentenceExerciseRepository = const PendingSentenceExerciseRepository(),
  });

  final AuthRepository? authRepository;
  final UserProfileRepository? userProfileRepository;
  final ProgressRepository? progressRepository;

  /// Hasil `initializeFirebaseBackend()`; diabaikan jika repository di atas
  /// diberikan langsung (mis. di tes).
  final Future<FirebaseBackend?>? firebaseBackend;
  final DictionaryRepository dictionaryRepository;
  final QuizRepository quizRepository;
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
        quizRepository: quizRepository,
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
    required this.quizRepository,
    required this.sentenceExerciseRepository,
  });

  final AuthRepository? authRepository;
  final UserProfileRepository? userProfileRepository;
  final ProgressRepository? progressRepository;
  final Future<FirebaseBackend?>? firebaseBackend;
  final DictionaryRepository dictionaryRepository;
  final QuizRepository quizRepository;
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
    final sentenceExercises = await widget.sentenceExerciseRepository
        .loadExercises(dialect: 'toba');
    return AppController(
      index: index,
      savedEntryIds: savedIds,
      quizStats: quizStats,
      guestSession: guestSession,
      sentenceExercises: sentenceExercises,
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
    this.quizBank = const [],
    bool guestSession = false,
  }) : _activeStore = progressStore,
       isGuestSession = guestSession,
       authResolved = authRepository == null {
    final authRepository = this.authRepository;
    if (authRepository != null) {
      _authSubscription = authRepository.authStateChanges.listen(
        (user) => unawaited(_handleAuthState(user)),
        onError: (Object error) {
          authError = error;
          authResolved = true;
          if (!_disposed) notifyListeners();
        },
      );
    }
    unawaited(_loadLocalProfile());
  }

  final DictionaryIndex index;
  final List<SentenceExercise> sentenceExercises;
  final AuthRepository? authRepository;
  final UserProfileRepository? userProfileRepository;
  final ProgressRepository? progressRepository;

  /// Bank soal kuis dari Firebase. Kosong = kuis memakai soal otomatis dari kamus.
  final List<QuizBankQuestion> quizBank;

  /// Cache lokal mode TAMU (kunci lama). Akun memakai cache sendiri per uid.
  final LearningProgressStore progressStore;
  LearningProgressStore _activeStore;
  String? _progressUid;

  Set<String> savedEntryIds;
  QuizStats quizStats;
  AppUser? currentUser;

  /// True setelah status login awal (akun tersimpan atau belum) diketahui.
  bool authResolved;

  /// True selama sesi tamu aktif (tersimpan sampai pengguna keluar).
  bool isGuestSession;
  UserProfile? userProfile;

  /// Foto dan nama yang diubah pengguna (tersimpan lokal per akun).
  Uint8List? profilePhoto;
  String? profileNameOverride;
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
    _pushToCloud(
      (repository, uid) => repository.recordQuiz(uid, correct, total),
    );
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
      repository.mergeGuestProgress(uid, guest).catchError((
        Object error,
      ) async {
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

  String get _profileStoreId => currentUser?.uid ?? 'guest';

  String get displayName =>
      profileNameOverride ??
      userProfile?.displayName ??
      currentUser?.displayName ??
      'Tamu';

  Future<void> _loadLocalProfile() async {
    final id = _profileStoreId;
    final stored = await _LocalProfileStore.load(id);
    if (_disposed || id != _profileStoreId) return;
    profilePhoto = stored.photo;
    profileNameOverride = stored.name;
    notifyListeners();
  }

  Future<void> setProfilePhoto(Uint8List? bytes) async {
    final id = _profileStoreId;
    await _LocalProfileStore.savePhoto(id, bytes);
    if (_disposed || id != _profileStoreId) return;
    profilePhoto = bytes;
    notifyListeners();
  }

  Future<void> setProfileName(String? name) async {
    final id = _profileStoreId;
    final clean = name?.trim();
    await _LocalProfileStore.saveName(id, clean);
    if (_disposed || id != _profileStoreId) return;
    profileNameOverride = (clean == null || clean.isEmpty) ? null : clean;
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    isGuestSession = true;
    notifyListeners();
    await _GuestSessionStore.save(true);
  }

  Future<void> leaveGuestSession() async {
    isGuestSession = false;
    notifyListeners();
    await _GuestSessionStore.save(false);
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
    authResolved = true;
    profilePhoto = null;
    profileNameOverride = null;
    unawaited(_loadLocalProfile());
    if (user != null && isGuestSession) {
      isGuestSession = false;
      unawaited(_GuestSessionStore.save(false));
    }
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

enum _QuizPhase { intro, running, finished }

/// Menyimpan status "sesi tamu aktif" agar halaman login tidak muncul lagi
/// setiap aplikasi dibuka, sampai pengguna keluar dari mode tamu.
class _GuestSessionStore {
  const _GuestSessionStore._();

  static const _key = 'horas.guest_session_active';

  static Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> save(bool active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, active);
    } catch (_) {
      // Gagal menyimpan hanya berarti halaman login muncul lagi di sesi berikut.
    }
  }
}

/// Logo resmi Google "G" (SVG inline, tanpa file asset tambahan).
const String _googleLogoSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z"/>'
    '<path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z"/>'
    '<path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24c0 3.55.85 6.91 2.34 9.88l7.35-5.7z"/>'
    '<path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z"/>'
    '</svg>';

/// Penentu halaman awal: login (belum masuk) atau aplikasi (akun Google /
/// sesi tamu). Pemilik [AppController], jadi dialah yang membuangnya.
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.controller});

  final AppController controller;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final Widget child;
        if (!controller.authResolved) {
          child = const Scaffold(
            key: ValueKey('auth-loading'),
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (controller.currentUser != null ||
            controller.isGuestSession) {
          child = _AppShell(
            key: const ValueKey('app-shell'),
            controller: controller,
          );
        } else {
          child = _WelcomeScreen(
            key: const ValueKey('welcome'),
            controller: controller,
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: child,
        );
      },
    );
  }
}

class _WelcomeScreen extends StatefulWidget {
  const _WelcomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen> {
  bool _isSigningIn = false;
  String? _message;
  String? _messageDetail;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _message = null;
      _messageDetail = null;
    });
    try {
      await widget.controller.signInWithGoogle();
      // Beri waktu event status login tiba; kalau berhasil, gerbang akan
      // otomatis memindahkan pengguna ke beranda dan layar ini dilepas.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      if (widget.controller.currentUser == null) {
        setState(() {
          _message =
              'Login dibatalkan. Coba lagi, atau lanjutkan sebagai tamu.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message =
            'Login Google gagal. Periksa koneksi internet lalu coba lagi.';
        _messageDetail = '$error';
      });
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _continueAsGuest() => widget.controller.continueAsGuest();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final authConfigured = widget.controller.authRepository != null;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.45),
              scheme.surface,
            ],
            stops: const [0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 44,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Horas',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selamat datang!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Cari arti kata, simpan pilihanmu, lalu latih '
                        'ingatan lewat kuis Bahasa Batak Toba.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton(
                        onPressed: authConfigured && !_isSigningIn
                            ? _signInWithGoogle
                            : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: scheme.surface,
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(color: scheme.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSigningIn)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              SvgPicture.string(
                                _googleLogoSvg,
                                width: 20,
                                height: 20,
                              ),
                            const SizedBox(width: 12),
                            const Text('Login with Google'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSigningIn ? null : _continueAsGuest,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.person_outline_rounded),
                        label: const Text('Continue as Guest'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _message!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                              if (_messageDetail != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _messageDetail!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _isSigningIn
                                    ? null
                                    : _signInWithGoogle,
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onErrorContainer,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 36),
                                ),
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        authConfigured
                            ? 'Sebagai tamu, progresmu tersimpan di perangkat '
                                  'ini. Masuk dengan Google untuk menyimpannya '
                                  'di akunmu.'
                            : 'Login Google belum tersedia di versi ini. Kamu '
                                  'tetap bisa belajar sebagai tamu.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({super.key, required this.controller});

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
  List<DictionaryEntry> _runSearch() =>
      widget.controller.index.search(_query, partOfSpeech: _partOfSpeech);

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
  late List<QuizItem> _questions;
  SentenceExercise? _activeSentenceExercise;
  List<int> _availableSentenceTokenIndices = [];
  final List<int> _arrangedSentenceTokenIndices = [];
  bool? _sentenceIsCorrect;
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
    _mode = widget.initialMode;
    _questions = buildQuizItems(
      index: widget.controller.index,
      bank: widget.controller.quizBank,
    );
    _answers = List<String?>.filled(_questions.length, null);
    _startSentenceExercise();
  }

  void _selectMode(_PracticeMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      if (mode == _PracticeMode.quiz && _quizPhase == _QuizPhase.finished) {
        _restartQuiz();
      }
      if (mode == _PracticeMode.sentences) _startSentenceExercise();
    });
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
            borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _selectAnswer(option),
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
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(12),
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

class _LocalProfile {
  const _LocalProfile({this.name, this.photo});

  final String? name;
  final Uint8List? photo;
}

/// Nama tampilan dan foto profil yang diubah pengguna, disimpan di perangkat
/// (SharedPreferences) per akun: kunci `guest` untuk tamu, uid untuk akun.
class _LocalProfileStore {
  const _LocalProfileStore._();

  static String _nameKey(String id) => 'horas.profile.$id.name';
  static String _photoKey(String id) => 'horas.profile.$id.photo';

  static Future<_LocalProfile> load(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_photoKey(id));
      return _LocalProfile(
        name: prefs.getString(_nameKey(id)),
        photo: encoded == null ? null : base64Decode(encoded),
      );
    } catch (_) {
      return const _LocalProfile();
    }
  }

  static Future<void> saveName(String id, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.isEmpty) {
      await prefs.remove(_nameKey(id));
    } else {
      await prefs.setString(_nameKey(id), name);
    }
  }

  static Future<void> savePhoto(String id, Uint8List? bytes) async {
    final prefs = await SharedPreferences.getInstance();
    if (bytes == null) {
      await prefs.remove(_photoKey(id));
    } else {
      final saved = await prefs.setString(_photoKey(id), base64Encode(bytes));
      if (!saved) throw StateError('Penyimpanan perangkat menolak foto ini.');
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.size,
    required this.photo,
    required this.photoUrl,
  });

  final double size;
  final Uint8List? photo;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.55,
        color: scheme.onPrimaryContainer,
      ),
    );
    final Widget image;
    if (photo != null) {
      image = Image.memory(
        photo!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      image = Image.network(
        photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }
    return ClipOval(child: image);
  }
}

/// Dialog edit nama. Memegang [TextEditingController] sendiri agar dibuang
/// dengan aman. Mengembalikan teks nama ('' berarti pakai nama bawaan),
/// atau null kalau dibatalkan.
class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initialName, this.email});

  final String initialName;
  final String? email;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_nameController.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Edit profil'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Nama tampilan',
                helperText: 'Kosongkan untuk memakai nama bawaan.',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.email != null) ...[
              const SizedBox(height: 12),
              Text(
                'Email: ${widget.email} (dari akun Google, tidak bisa diubah)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen({
    required this.controller,
    required this.onOpenDictionary,
  });

  final AppController controller;
  final ValueChanged<String> onOpenDictionary;

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  bool _photoBusy = false;

  AppController get controller => widget.controller;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPhotoOptions() async {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = controller.profilePhoto != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Ganti Foto'),
              subtitle: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil Foto'),
              subtitle: const Text('Buka kamera'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                ),
                title: Text(
                  'Hapus Foto',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'remove':
        await _removePhoto();
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    Uint8List? bytes;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) bytes = await picked.readAsBytes();
    } on PlatformException catch (error) {
      final fromCamera = source == ImageSource.camera;
      if (error.code == 'camera_access_denied') {
        _toast(
          'Izin kamera ditolak. Aktifkan izin kamera di pengaturan perangkat.',
        );
      } else if (error.code == 'photo_access_denied') {
        _toast(
          'Izin galeri ditolak. Aktifkan izin foto di pengaturan perangkat.',
        );
      } else {
        _toast(
          fromCamera
              ? 'Kamera tidak dapat dibuka di perangkat ini.'
              : 'Galeri tidak dapat dibuka. Coba lagi.',
        );
      }
    } catch (_) {
      _toast(
        source == ImageSource.camera
            ? 'Kamera tidak dapat dibuka di perangkat ini.'
            : 'Galeri tidak dapat dibuka. Coba lagi.',
      );
    }
    if (!mounted) return;
    setState(() => _photoBusy = false);
    if (bytes == null) return; // dibatalkan atau gagal (pesan sudah tampil)

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pratinjau foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.memory(
                bytes!,
                width: 180,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Pakai foto ini sebagai foto profilmu?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _photoBusy = true);
    try {
      await controller.setProfilePhoto(bytes);
      _toast('Foto profil diperbarui.');
    } catch (error) {
      _toast('Foto belum tersimpan: $error');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto profil?'),
        content: const Text('Foto akan diganti dengan foto bawaan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      await controller.setProfilePhoto(null);
      _toast('Foto profil dihapus.');
    } catch (error) {
      _toast('Foto belum terhapus: $error');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _editProfile() async {
    final user = controller.currentUser;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditProfileDialog(
        initialName: controller.profileNameOverride ?? '',
        email: controller.userProfile?.email ?? user?.email,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await controller.setProfileName(result);
      _toast('Profil diperbarui.');
    } catch (error) {
      _toast('Profil belum tersimpan: $error');
    }
  }

  Future<void> _confirmLogout() async {
    final isGuest = controller.currentUser == null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isGuest ? 'Keluar dari mode tamu?' : 'Keluar dari akun?'),
        content: Text(
          isGuest
              ? 'Progres tamu tetap tersimpan di perangkat ini. Kamu akan '
                    'kembali ke halaman login.'
              : 'Kamu bisa masuk lagi kapan saja dengan akun Google yang sama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (isGuest) {
        await controller.leaveGuestSession();
      } else {
        await controller.signOut();
      }
    } catch (error) {
      _toast('Tidak dapat keluar: $error');
    }
  }

  Widget _buildStat(ThemeData theme, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGroup(ThemeData theme, String title, List<Widget> tiles) {
    final scheme = theme.colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0)
        children.add(
          Divider(height: 1, indent: 56, color: scheme.outlineVariant),
        );
      children.add(tiles[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded, color: color),
      onTap: onTap,
    );
  }

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
    final email = controller.userProfile?.email ?? user?.email;
    final photoUrl = controller.userProfile?.photoUrl ?? user?.photoUrl;
    final errors = <String>[
      if (controller.authError != null)
        'Status autentikasi tidak dapat dimuat: ${controller.authError}',
      if (controller.profileError != null)
        'Profil Firebase belum tersimpan: ${controller.profileError}',
      if (controller.progressError != null)
        'Progres belum tersinkronisasi: ${controller.progressError}',
    ];

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              Center(
                child: Semantics(
                  button: true,
                  label: 'Ubah foto profil',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _photoBusy ? null : _showPhotoOptions,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ProfileAvatar(
                          size: 96,
                          photo: controller.profilePhoto,
                          photoUrl: photoUrl,
                        ),
                        if (_photoBusy)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.surface.withValues(alpha: 0.6),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.photo_camera_rounded,
                              size: 16,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                controller.displayName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (email != null) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: user == null
                        ? scheme.surfaceContainerHighest
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    user == null ? 'Tamu' : 'Akun Google',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: user == null
                          ? scheme.onSurfaceVariant
                          : scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    errors.join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  _buildStat(
                    theme,
                    '${stats.completedQuizzes}',
                    'Kuis selesai',
                  ),
                  const SizedBox(width: 10),
                  _buildStat(theme, accuracy, 'Akurasi'),
                  const SizedBox(width: 10),
                  _buildStat(theme, '${savedEntries.length}', 'Kata tersimpan'),
                ],
              ),
              const SizedBox(height: 24),
              _buildMenuGroup(theme, 'Akun', [
                _buildMenuTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit profil',
                  subtitle: 'Ubah nama tampilan',
                  onTap: _editProfile,
                ),
                if (user == null && authConfigured)
                  _buildMenuTile(
                    icon: Icons.login_rounded,
                    title: 'Masuk dengan Google',
                    subtitle: 'Simpan progres di akunmu',
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => _LoginScreen(controller: controller),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 18),
              _buildMenuGroup(theme, 'Lainnya', [
                _buildMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang Horas',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Horas',
                    applicationIcon: Icon(
                      Icons.menu_book_rounded,
                      size: 36,
                      color: scheme.primary,
                    ),
                    children: const [
                      Text(
                        'Aplikasi belajar Bahasa Batak Toba: kamus, kuis '
                        'kosakata, dan latihan susun kalimat.',
                      ),
                    ],
                  ),
                ),
                _buildMenuTile(
                  icon: Icons.logout_rounded,
                  title: user == null ? 'Keluar dari mode tamu' : 'Keluar',
                  color: scheme.error,
                  onTap: _confirmLogout,
                ),
              ]),
              const SizedBox(height: 26),
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
                  onAction: () => widget.onOpenDictionary(''),
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
