part of '../main.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.index,
    required this.savedEntryIds,
    required this.quizStats,
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
