import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/auth_repository.dart';
import 'data/csv_dictionary_repository.dart';
import 'data/dictionary_cache_factory.dart';
import 'data/dictionary_index.dart';
import 'data/dictionary_repository.dart';
import 'data/firebase_bootstrap.dart';
import 'data/progress_repository.dart';
import 'data/quiz_cache.dart';
import 'data/quiz_repository.dart';
import 'data/synced_dictionary_repository.dart';
import 'models/app_user.dart';
import 'models/dictionary_entry.dart';
import 'models/quiz_bank_question.dart';
import 'models/user_profile.dart';
import 'data/user_profile_repository.dart';
import 'services/learning_progress_store.dart';
import 'services/quiz_builder.dart';
import 'widgets/horas_logo.dart';

// Palet ulos: merah, hitam, putih, dengan emas sebagai aksen langka.
// Semua netral diberi sedikit rona merah supaya tidak terasa abu-abu mati.

part 'app/bootstrap.dart';
part 'controllers/app_controller.dart';
part 'pages/auth_pages.dart';
part 'pages/home_page.dart';
part 'pages/dictionary_page.dart';
part 'pages/practice_page.dart';
part 'pages/profile_page.dart';
part 'pages/login_page.dart';
part 'widgets/common_widgets.dart';
part 'widgets/home_widgets.dart';

const _paper = Color(0xFFF4F0EE);
const _ink = Color(0xFF211A19);
const _ulosRed = Color(0xFF8F2723);
const _ulosBlack = Color(0xFF2A2121);
const _gold = Color(0xFFD4A63A);
const _goldDeep = Color(0xFF7A5C14);

// Font web dimatikan di tes widget agar tes tidak mengunduh font.
bool get _webFonts =>
    !WidgetsBinding.instance.runtimeType.toString().contains('Test');

TextStyle _display(TextStyle style) =>
    _webFonts ? GoogleFonts.bricolageGrotesque(textStyle: style) : style;

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
  });

  final AuthRepository? authRepository;
  final UserProfileRepository? userProfileRepository;
  final ProgressRepository? progressRepository;

  /// Hasil `initializeFirebaseBackend()`; diabaikan jika repository di atas
  /// diberikan langsung (mis. di tes).
  final Future<FirebaseBackend?>? firebaseBackend;
  final DictionaryRepository dictionaryRepository;
  final QuizRepository quizRepository;

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
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _ulosRed,
        brightness: brightness,
      ).copyWith(
        primary: isDark ? const Color(0xFFE8A59C) : _ulosRed,
        onPrimary: isDark ? const Color(0xFF4A110E) : Colors.white,
        secondary: isDark ? const Color(0xFFE2BF6A) : _goldDeep,
        onSecondary: isDark ? const Color(0xFF3A2A00) : Colors.white,
        primaryContainer: isDark
            ? const Color(0xFF4A2522)
            : const Color(0xFFF1D9D5),
        onPrimaryContainer: isDark
            ? const Color(0xFFFADCD7)
            : const Color(0xFF4A110E),
        surface: isDark ? const Color(0xFF181312) : _paper,
        onSurface: isDark ? const Color(0xFFEDE6E3) : _ink,
        onSurfaceVariant: isDark
            ? const Color(0xFFC9BDB9)
            : const Color(0xFF5E5250),
        surfaceContainerLow: isDark
            ? const Color(0xFF211B1A)
            : const Color(0xFFFBF9F8),
        surfaceContainerHighest: isDark
            ? const Color(0xFF362E2C)
            : const Color(0xFFE8E1DE),
        outline: isDark ? const Color(0xFF8F8481) : const Color(0xFF7E7370),
        outlineVariant: isDark
            ? const Color(0xFF4A4140)
            : const Color(0xFFD9D0CD),
      );
  final surface = scheme.surface;

  const baseText = TextTheme(
    headlineMedium: TextStyle(fontSize: 32, height: 1.1, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontSize: 25, height: 1.15, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
  );
  final body = _webFonts ? GoogleFonts.figtreeTextTheme(baseText) : baseText;
  final textTheme = body.copyWith(
    headlineMedium: _display(body.headlineMedium!),
    headlineSmall: _display(body.headlineSmall!),
    titleLarge: _display(body.titleLarge!),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    textTheme: textTheme,
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
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : null,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
  );
}

