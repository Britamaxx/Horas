# Audit Penerapan Modul Flutter 1–6

Audit dilakukan terhadap kode aplikasi **Belajar Bahasa Batak** dan enam PDF modul yang diberikan.

| Modul | Status | Temuan |
|---|---|---|
| 1. Pengenalan Dart & Flutter | Diterapkan | Kode menggunakan tipe data Dart, fungsi, class, constructor, collection, null safety, async/await, dan widget Flutter. |
| 2. Widget Dasar | Diterapkan | Menggunakan `MaterialApp`, `Scaffold`, `SafeArea`, `SingleChildScrollView`, `Padding`, `Row`, `Column`, `Container`, `SizedBox`, `Text`, `Icon`, `TextField`, dan `Expanded`. |
| 3. Widget Lanjutan & Navigation | Diterapkan | Menggunakan navigasi tab (`NavigationBar`/`NavigationRail`), `IndexedStack`, `Navigator.push/pop`, dialog, serta widget gambar/dekorasi sesuai kebutuhan aplikasi. Navigasi utama memang tab-based, bukan seluruhnya `MaterialPageRoute`. |
| 4. Stateful Widget | Diterapkan | Halaman interaktif menggunakan `StatefulWidget`, `setState`, controller input, lifecycle widget, serta state untuk pencarian, latihan, profil, dan alur autentikasi. |
| 5. Provider | Diperkuat pada revisi ini | Sebelumnya state utama dikelola oleh `ChangeNotifier` dan `ListenableBuilder`/`AnimatedBuilder`, tetapi dependency Provider belum ada. Ditambahkan `provider`, `ChangeNotifierProvider.value`, dan `Consumer<AppController>` pada gerbang autentikasi. State lokal tetap menggunakan `setState` jika sesuai. |
| 6. Firebase | Diterapkan dengan penyesuaian aplikasi | Firebase Core diinisialisasi melalui `firebase_bootstrap.dart`; Firebase Authentication digunakan untuk login Google dan pemantauan sesi; Cloud Firestore digunakan untuk sumber kamus, bank soal, profil, dan sinkronisasi progres. Aplikasi memiliki cache/fallback lokal. |

## Perubahan struktur kode

- `lib/main.dart`: entry point, konfigurasi tema, dan root aplikasi.
- `lib/app/bootstrap.dart`: pemuatan awal aplikasi dan penanganan error pemuatan.
- `lib/controllers/app_controller.dart`: state dan logika aplikasi.
- `lib/pages/auth_pages.dart`: gerbang autentikasi dan layar sambutan/login.
- `lib/pages/home_page.dart`: shell navigasi dan logika halaman beranda.
- `lib/widgets/home_widgets.dart`: widget visual yang dipakai halaman beranda.
- `lib/pages/dictionary_page.dart`: halaman kamus dan detail entri.
- `lib/pages/practice_page.dart`: alur latihan/kuis.
- `lib/pages/profile_page.dart`: profil dan pengaturan profil.
- `lib/pages/login_page.dart`: layar login tambahan yang sudah ada di aplikasi.
- `lib/widgets/common_widgets.dart`: widget umum.
- Kode data, model, dan service yang sudah terpisah tetap dipertahankan di folder masing-masing.

## Catatan konfigurasi dan batas audit

1. Contoh Modul 6 menggunakan Email/Password, sedangkan aplikasi ini menggunakan **Google Sign-In melalui Firebase Authentication**. Firebase Auth sudah dipakai, tetapi metode login tidak identik dengan contoh modul.
2. Koleksi Firestore aplikasi disesuaikan dengan kamus, kuis, profil, dan progres belajar; bukan koleksi `products` dari contoh modul.
3. Pastikan Firebase Console, metode Google Sign-In, konfigurasi platform, dan Firestore Rules sesuai dengan project Firebase milik Anda.
4. Lingkungan pengerjaan ini tidak menyediakan Flutter/Dart SDK, jadi `flutter pub get`, `dart format`, `flutter analyze`, dan tes Flutter tidak dapat dijalankan di sini. Setelah menimpa project, jalankan perintah di bagian berikut.

## Setelah menimpa project

```bash
flutter pub get
dart format lib
flutter analyze
flutter test
```
