import 'dart:io';

import 'package:belajar_bahasa_batak/widgets/horas_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _assetShown(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget logo,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: logo)),
    ),
  );
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as AssetImage).assetName;
}

void main() {
  testWidgets('logo lengkap: versi terang di tema terang, versi gelap di tema gelap', (
    tester,
  ) async {
    expect(
      await _assetShown(
        tester,
        brightness: Brightness.light,
        logo: const HorasLogo.full(),
      ),
      HorasLogo.fullAsset,
    );
    expect(
      await _assetShown(
        tester,
        brightness: Brightness.dark,
        logo: const HorasLogo.full(),
      ),
      HorasLogo.fullDarkAsset,
    );
  });

  testWidgets('logo bubble memakai satu aset di kedua tema dan mengikuti ukuran', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      expect(
        await _assetShown(
          tester,
          brightness: brightness,
          logo: const HorasLogo.mark(size: 48),
        ),
        HorasLogo.markAsset,
      );
      expect(tester.widget<Image>(find.byType(Image)).width, 48);
    }
  });

  test('aset logo ada, berformat PNG, dan terdaftar di pubspec', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/images/'));

    const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (final asset in [
      HorasLogo.fullAsset,
      HorasLogo.fullDarkAsset,
      HorasLogo.markAsset,
    ]) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: '$asset tidak ditemukan');
      expect(file.readAsBytesSync().sublist(0, 8), pngSignature, reason: asset);
    }
  });

  test('ikon peluncur Android lengkap untuk semua kerapatan layar', () {
    const res = 'android/app/src/main/res';
    expect(File('$res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(), isTrue);
    expect(File('$res/values/ic_launcher_background.xml').existsSync(), isTrue);
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final name in [
        'ic_launcher.png',
        'ic_launcher_foreground.png',
        'ic_launcher_monochrome.png',
      ]) {
        final file = File('$res/mipmap-$density/$name');
        expect(file.existsSync(), isTrue, reason: '${file.path} tidak ada');
      }
    }
  });
}
