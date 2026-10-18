import 'package:belajar_bahasa_batak/data/csv_dictionary_repository.dart';
import 'package:belajar_bahasa_batak/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile explains pending Google login and Toba sentences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'completed_quizzes': 2,
      'correct_answers': 7,
      'answered_questions': 10,
    });
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/data/dict_entries.csv');
      await SharedPreferences.getInstance();
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Isolate nyata tidak berjalan di fake async milik tes widget, jadi kamus
    // diurai langsung (di aplikasi sungguhan diurai di isolate latar belakang).
    await tester.pumpWidget(
      const HorasApp(
        dictionaryRepository: CsvDictionaryRepository(runInBackground: false),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('Senang belajar lagi?'));

    expect(find.text('Kuis kosakata berikutnya'), findsOneWidget);
    expect(find.text('2 kuis selesai · 10 soal dijawab.'), findsOneWidget);
    expect(find.text('14.618 entri'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(320, 844));
    await tester.pumpAndSettle();
    expect(find.text('Cari kata Indonesia atau Batak'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(900, 900));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Profil belajar'), findsOneWidget);
    expect(find.text('AKUN BELUM AKTIF'), findsOneWidget);
    expect(find.text('Belajar di perangkat ini'), findsOneWidget);

    await tester.tap(find.text('Lihat opsi masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke Horas'), findsOneWidget);
    expect(find.textContaining('Login belum aktif.'), findsOneWidget);
    final googleButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Lanjutkan dengan Google'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(googleButton.onPressed, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latihan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Susun kalimat').last);
    await tester.pumpAndSettle();

    expect(find.text('Materi kalimat belum tersedia'), findsOneWidget);
    expect(find.textContaining('Batak Toba'), findsWidgets);
    expect(
      find.textContaining('belum membuat atau menilai kalimat sendiri.'),
      findsOneWidget,
    );
  });
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
