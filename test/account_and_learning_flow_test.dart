import 'package:belajar_bahasa_batak/data/csv_dictionary_repository.dart';
import 'package:belajar_bahasa_batak/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci penanda "sesi tamu aktif" (lihat _GuestSessionStore di main.dart).
/// Jika true, aplikasi melewati layar sambutan dan langsung membuka Beranda.
const _guestSessionKey = 'horas.guest_session_active';

/// Isolate nyata tidak berjalan di fake async milik tes widget, jadi kamus
/// diurai langsung (di aplikasi sungguhan diurai di isolate latar belakang).
/// Firebase tidak diberikan, sehingga aplikasi berjalan dalam mode lokal.
const _testApp = HorasApp(
  dictionaryRepository: CsvDictionaryRepository(runInBackground: false),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tamu: beranda, tampilan responsif, profil, dan latihan hanya kuis', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _guestSessionKey: true,
      'completed_quizzes': 2,
      'correct_answers': 7,
      'answered_questions': 10,
    });
    await _preloadAssets(tester);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp);
    await _waitForApp(tester);
    await _pumpUntilVisible(tester, find.text('Senang belajar lagi?'));

    // Beranda memakai riwayat kuis lokal.
    expect(find.text('Kuis kosakata berikutnya'), findsOneWidget);
    expect(find.text('2 kuis selesai · 10 soal dijawab.'), findsOneWidget);
    expect(find.text('14.618 entri'), findsOneWidget);
    expect(find.text('Susun kalimat'), findsNothing);

    // Tampilan tetap utuh di layar sempit dan lebar.
    await tester.binding.setSurfaceSize(const Size(320, 844));
    await _settle(tester);
    expect(find.text('Cari kata Indonesia atau Batak'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(900, 900));
    await _settle(tester);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await _settle(tester);

    // Profil tamu. Tanpa Firebase, opsi "Masuk dengan Google" tidak ditawarkan.
    await tester.tap(find.text('Profil').last);
    await _settle(tester);
    expect(find.text('Tamu'), findsWidgets);
    expect(find.text('Kuis selesai'), findsOneWidget);
    expect(find.text('Akurasi'), findsOneWidget);
    // Muncul sebagai label statistik dan sebagai judul daftar di bawahnya.
    expect(find.text('Kata tersimpan'), findsWidgets);
    expect(find.text('Edit profil'), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsNothing);

    // Latihan hanya berisi kuis (susun kalimat sudah dihapus).
    await tester.tap(find.text('Latihan').last);
    await _settle(tester);
    expect(find.text('Susun kalimat'), findsNothing);
    expect(find.textContaining('soal pilihan ganda'), findsWidgets);
  });

  testWidgets('tanpa sesi tamu: layar sambutan tampil, lanjut sebagai tamu membuka beranda', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _preloadAssets(tester);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp);
    await _waitForApp(tester);
    await _pumpUntilVisible(tester, find.text('Selamat datang!'));

    // Tanpa Firebase, tombol login Google tidak aktif; tamu tetap bisa masuk.
    expect(find.text('Continue as Guest'), findsOneWidget);
    final googleButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Login with Google'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(googleButton.onPressed, isNull);

    await tester.tap(find.text('Continue as Guest'));
    await _pumpUntilVisible(tester, find.text('Mulai dari satu kata.'));
    expect(find.text('Selamat datang!'), findsNothing);
  });
}

/// Memuat aset dan SharedPreferences dengan waktu nyata, karena fake async
/// milik tes widget tidak menjalankan pekerjaan I/O sungguhan.
Future<void> _preloadAssets(WidgetTester tester) async {
  await tester.runAsync(() async {
    await rootBundle.loadString('assets/data/dict_entries.csv');
    await SharedPreferences.getInstance();
  });
}

Future<void> _waitForApp(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
}

/// Pengganti pumpAndSettle: slider kata di Beranda beranimasi terus-menerus,
/// sehingga pumpAndSettle tidak pernah dianggap selesai.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 100,
}) async {
  for (
    var attempt = 0;
    attempt < maxPumps && finder.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}
