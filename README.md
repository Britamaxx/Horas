# Horas — Belajar Bahasa Batak

Horas adalah aplikasi Flutter untuk membantu pengguna berbahasa Indonesia mempelajari kosakata Bahasa Batak. Aplikasi menyediakan kamus, pencarian kata, kata tersimpan, latihan kuis, profil pengguna, serta penyimpanan progres belajar. Aplikasi dirancang agar sebagian fitur tetap dapat digunakan saat offline melalui data dan cache lokal.

## Daftar Isi

- [Fitur Utama](#fitur-utama)
- [Teknologi](#teknologi)
- [Cara Kerja Aplikasi](#cara-kerja-aplikasi)
- [Arsitektur dan Struktur Folder](#arsitektur-dan-struktur-folder)
- [Menghubungkan Firebase dan Firestore](#menghubungkan-firebase-dan-firestore)
- [Mengelola Data Kamus dan Kuis](#mengelola-data-kamus-dan-kuis)
- [Menjalankan Aplikasi](#menjalankan-aplikasi)
- [Pengujian dan Build](#pengujian-dan-build)
- [Catatan Keamanan](#catatan-keamanan)

## Fitur Utama

- **Kamus Indonesia–Batak:** mencari kata dan definisinya, termasuk pencarian berdasarkan kata maupun arti.
- **Kata tersimpan:** menandai kosakata untuk dipelajari kembali.
- **Latihan kuis:** mengerjakan 10 soal acak dalam satu putaran dari bank soal yang tersedia.
- **Profil dan autentikasi:** mendukung rancangan login Google melalui Firebase Authentication.
- **Progres belajar:** mencatat kata tersimpan, jumlah kuis selesai, jawaban benar, dan jumlah pertanyaan yang dijawab.
- **Dukungan offline:** memakai CSV bawaan sebagai cadangan kamus dan cache lokal untuk kamus, soal, serta progres.
- **Tema terang dan gelap:** mengikuti pengaturan tema sistem.

## Teknologi

- Flutter dan Dart
- Provider untuk mengelola state aplikasi
- Firebase Core untuk inisialisasi Firebase
- Firebase Authentication dan Google Sign-In untuk autentikasi
- Cloud Firestore untuk data kamus, bank soal, profil, dan progres
- SharedPreferences dan penyimpanan file lokal untuk cache
- CSV sebagai sumber data awal/cadangan

## Cara Kerja Aplikasi

### 1. Inisialisasi

`lib/main.dart` memulai aplikasi dan memanggil `initializeFirebaseBackend()`. Firebase dan pemuatan data kamus/kuis dimulai bersamaan. Jika Firebase tidak dapat diinisialisasi, aplikasi mencoba berjalan dengan sumber data lokal yang tersedia.

### 2. Kamus

Urutan pemuatan kamus:

1. Aplikasi mencoba memuat kamus dari paket Firestore melalui `dictionary_meta/current` dan dokumen di `dictionary_packs/`.
2. Hasil yang berhasil dimuat disimpan dalam cache lokal agar pembukaan berikutnya lebih cepat dan penggunaan offline memungkinkan.
3. Jika data remote tidak tersedia dan belum ada cache yang bisa dipakai, aplikasi menggunakan `assets/data/dict_entries.csv` sebagai cadangan.
4. CSV dibaca dan indeks pencarian dibangun di isolate agar pekerjaan pemrosesan tidak membebani UI.

Aplikasi memeriksa versi data remote. Paket kamus baru yang berhasil diunduh digunakan pada pembukaan berikutnya.

### 3. Latihan kuis

Aplikasi mencoba memuat bank soal dari `quiz_meta/current` dan `quiz_packs/`. Bank soal disimpan di cache lokal. Jika bank soal belum tersedia, tidak dapat diunduh, atau belum pernah dicache, aplikasi dapat membuat soal latihan dari data kamus yang tersedia.

### 4. Login dan progres

Jika Firebase berhasil diinisialisasi, repository Firebase digunakan untuk autentikasi, profil, dan progres. Progres akun disimpan pada `users/{uid}/progress/summary`, sedangkan profil berada di `users/{uid}`. Data lokal membantu aplikasi tetap responsif dan mendukung penggunaan offline. Mode tamu menggunakan penyimpanan lokal.

### 5. Pengelolaan state dan tampilan

`AppController` menjadi penghubung antara data dan tampilan. Berbagai halaman dan widget didefinisikan menggunakan direktif Dart `part` dari `lib/main.dart`; karena itu, beberapa file UI bukan library Dart yang berdiri sendiri dan merupakan bagian dari library yang sama.

## Arsitektur dan Struktur Folder

```text
belajar_bahasa_batak/
├── android/                    # Konfigurasi dan wrapper build Android
├── assets/
│   ├── data/
│   │   └── dict_entries.csv     # Data kamus cadangan yang disertakan di aplikasi
│   └── images/                  # Aset logo Horas
├── lib/
│   ├── main.dart                # Entry point, tema, dependency setup, dan deklarasi part
│   ├── firebase_options.dart    # Opsi konfigurasi Firebase per platform
│   ├── app/
│   │   └── bootstrap.dart       # Memuat data dan menyiapkan controller aplikasi
│   ├── controllers/
│   │   └── app_controller.dart  # State dan aksi utama aplikasi
│   ├── data/                    # Repository, sumber data, parser, dan cache
│   ├── models/                  # Model data aplikasi
│   ├── pages/                   # Halaman UI aplikasi
│   ├── services/                # Logika progres belajar dan pembentukan soal
│   └── widgets/                 # Widget bersama dan logo
├── test/                        # Unit test dan widget test
├── tools/
│   ├── database_bahasa_batak.csv # Sumber CSV bank soal kuis
│   ├── publish_dictionary.py    # Mengunggah paket kamus ke Firestore
│   ├── publish_quiz.py          # Mengunggah paket soal ke Firestore
│   └── make_brand_assets.py     # Membuat aset logo dari gambar master
├── firebase.json                # Konfigurasi FlutterFire CLI
├── firestore.rules              # Aturan keamanan Cloud Firestore
├── pubspec.yaml                 # Dependensi dan aset Flutter
├── pubspec.lock                 # Versi dependensi yang terkunci
├── analysis_options.yaml        # Aturan analisis Dart
└── README.md                    # Dokumentasi proyek
```

### File di `lib/`

#### Entry point dan pengelolaan aplikasi

| File | Kegunaan |
|---|---|
| `lib/main.dart` | Entry point. Menyiapkan tema, dependency, repository kamus/kuis, dan memuat file UI melalui `part`. |
| `lib/app/bootstrap.dart` | Menginisialisasi data awal, memuat progres lokal, membuat `AppController`, dan menampilkan layar pemuatan/error atau aplikasi. |
| `lib/controllers/app_controller.dart` | Mengelola state serta aksi yang dipakai halaman: kata tersimpan, kuis, akun, profil, dan progres. |

#### Halaman dan widget

| File | Kegunaan |
|---|---|
| `lib/pages/auth_pages.dart` | Tampilan dan alur terkait autentikasi. |
| `lib/pages/login_page.dart` | Halaman login. |
| `lib/pages/home_page.dart` | Beranda dan ringkasan/saran belajar. |
| `lib/pages/dictionary_page.dart` | Antarmuka kamus dan pencarian kata. |
| `lib/pages/practice_page.dart` | Antarmuka latihan kuis dan hasil jawaban. |
| `lib/pages/profile_page.dart` | Tampilan profil dan pengaturan terkait pengguna. |
| `lib/widgets/common_widgets.dart` | Widget UI yang dipakai bersama oleh beberapa halaman. |
| `lib/widgets/home_widgets.dart` | Widget khusus untuk beranda. |
| `lib/widgets/horas_logo.dart` | Widget logo Horas, termasuk penyesuaian untuk tema terang/gelap. |

> Catatan: file halaman/widget di atas memakai `part of '../main.dart';`. File-file tersebut adalah bagian dari library yang didefinisikan oleh `main.dart`, bukan modul Dart mandiri.

#### Data, repository, dan cache

| File | Kegunaan |
|---|---|
| `lib/data/auth_repository.dart` | Kontrak/interface untuk operasi autentikasi. |
| `lib/data/firebase_auth_repository.dart` | Implementasi autentikasi menggunakan Firebase Authentication dan Google Sign-In. |
| `lib/data/firebase_bootstrap.dart` | Menginisialisasi Firebase dan menyediakan repository Firebase untuk aplikasi. |
| `lib/data/user_profile_repository.dart` | Kontrak untuk membaca/menyimpan profil pengguna. |
| `lib/data/firestore_user_profile_repository.dart` | Implementasi profil pengguna di Cloud Firestore. |
| `lib/data/progress_repository.dart` | Kontrak penyimpanan progres di server. |
| `lib/data/firestore_progress_repository.dart` | Implementasi sinkronisasi progres belajar di Firestore. |
| `lib/data/dictionary_repository.dart` | Kontrak untuk memuat indeks kamus. |
| `lib/data/dictionary_source.dart` | Kontrak sumber data kamus remote. |
| `lib/data/csv_dictionary_repository.dart` | Memuat kamus dari CSV aset aplikasi. |
| `lib/data/csv_dictionary_parser.dart` | Mengurai baris CSV menjadi entri kamus. |
| `lib/data/dictionary_index.dart` | Membangun indeks pencarian dan bahan soal dari entri kamus. |
| `lib/data/dictionary_pack.dart` | Model paket kamus yang diterima dari Firestore. |
| `lib/data/firestore_dictionary_source.dart` | Membaca metadata dan paket kamus dari Firestore. |
| `lib/data/synced_dictionary_repository.dart` | Mengatur sumber kamus remote, cache, dan fallback CSV. |
| `lib/data/dictionary_cache.dart` | Kontrak serta model data cache kamus. |
| `lib/data/dictionary_cache_factory.dart` | Memilih implementasi cache sesuai platform. |
| `lib/data/dictionary_cache_io.dart` | Menyimpan/membaca cache kamus sebagai berkas lokal pada platform yang mendukungnya. |
| `lib/data/dictionary_cache_stub.dart` | Implementasi pengganti untuk platform yang tidak mendukung cache berbasis file. |
| `lib/data/quiz_repository.dart` | Kontrak dan implementasi dasar untuk memuat soal kuis. |
| `lib/data/quiz_source.dart` | Kontrak sumber bank soal remote. |
| `lib/data/firestore_quiz_source.dart` | Membaca metadata dan paket soal dari Firestore. |
| `lib/data/quiz_pack.dart` | Model paket bank soal. |
| `lib/data/quiz_cache.dart` | Cache bank soal di perangkat menggunakan SharedPreferences. |
| `lib/models/app_user.dart` | Model pengguna yang telah terautentikasi. |
| `lib/models/dictionary_entry.dart` | Model satu entri kamus. |
| `lib/models/quiz_bank_question.dart` | Model soal dari bank soal kuis. |
| `lib/models/user_profile.dart` | Model profil pengguna dan konversi data profil. |
| `lib/services/learning_progress_store.dart` | Menyimpan dan membaca kata tersimpan serta statistik kuis secara lokal. |
| `lib/services/quiz_builder.dart` | Membentuk soal kuis dari data kamus untuk mode fallback. |

### File aset, tools, dan konfigurasi

| File/folder | Kegunaan |
|---|---|
| `assets/data/dict_entries.csv` | Kamus lokal cadangan dan sumber untuk publikasi kamus ke Firestore. |
| `assets/images/` | Aset logo dalam format PNG/WebP, termasuk varian tema. |
| `tools/database_bahasa_batak.csv` | Data sumber bank soal untuk proses publikasi. |
| `tools/publish_dictionary.py` | Memvalidasi dan mengunggah CSV kamus ke koleksi paket Firestore. |
| `tools/publish_quiz.py` | Memvalidasi dan mengunggah CSV soal ke koleksi paket Firestore. |
| `tools/make_brand_assets.py` | Membuat aset logo aplikasi dari gambar master; memerlukan dependensi Python yang disebutkan pada skrip. |
| `test/` | Pengujian parser, indeks, repository, progres, kuis, profil, dan alur aplikasi. |
| `pubspec.yaml` | Nama aplikasi, versi, dependensi Dart/Flutter, dan daftar aset. |
| `pubspec.lock` | Mengunci versi dependensi untuk instalasi yang konsisten. |
| `firebase.json` | Konfigurasi platform yang dikelola FlutterFire CLI. |
| `lib/firebase_options.dart` | Opsi Firebase untuk platform yang didukung dan dihasilkan FlutterFire CLI. |
| `firestore.rules` | Aturan akses Firestore untuk kamus, kuis, profil, dan progres. |
| `analysis_options.yaml` | Aturan lint/analisis kode Dart. |
| `.gitignore` | Menentukan file dan folder yang tidak perlu dilacak Git. |
| `android/` | Berkas Gradle dan konfigurasi khusus build Android. |
| `web/` | Berkas awal aplikasi Flutter Web, manifest, dan favicon. |

## Menghubungkan Firebase dan Firestore

Proyek ini sudah memiliki integrasi kode Firebase. Agar backend berfungsi, konfigurasi aplikasi harus menunjuk ke proyek Firebase yang benar, layanan harus diaktifkan, data kamus/kuis harus dipublikasikan, dan aturan Firestore harus dipasang. Bila inisialisasi Firebase gagal, kode mencoba memakai mode lokal yang tersedia.

### 1. Siapkan proyek Firebase

1. Buat atau pilih proyek di [Firebase Console](https://console.firebase.google.com/).
2. Daftarkan aplikasi Android menggunakan **application ID/package name** yang sesuai dengan konfigurasi proyek.
3. Jika menggunakan web, daftarkan juga aplikasi web.
4. Aktifkan **Authentication** dan penyedia **Google** jika fitur login Google digunakan. Lengkapi konfigurasi OAuth dan SHA-1/SHA-256 Android sesuai panduan Firebase.
5. Buat database **Cloud Firestore**.

### 2. Buat konfigurasi FlutterFire

Pastikan Flutter dan Dart sudah terpasang, lalu jalankan FlutterFire CLI jika perlu membuat ulang konfigurasi:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Pilih proyek dan platform yang benar. Perintah tersebut akan menghasilkan/memperbarui `lib/firebase_options.dart` serta konfigurasi platform terkait. Pada proyek ini, `lib/data/firebase_bootstrap.dart` menggunakan `DefaultFirebaseOptions.currentPlatform` untuk inisialisasi.

> Jika memakai proyek Firebase yang sudah disetel, jangan menimpa konfigurasi secara sembarang. Periksa terlebih dahulu apakah `firebase.json`, `lib/firebase_options.dart`, dan konfigurasi Android/Web menunjuk ke proyek yang dimaksud.

### 3. Pasang Firestore Security Rules

Tinjau `firestore.rules`, lalu publikasikan aturan tersebut melalui Firebase Console atau Firebase CLI. Aturan dalam repository membolehkan pembacaan kamus dan bank soal untuk pengguna/tamu, tetapi menolak penulisan klien ke data publik tersebut. Profil dan progres dibatasi berdasarkan UID pengguna yang login.

Jangan mengganti aturan dengan akses terbuka seperti `allow read, write: if true;` pada aplikasi produksi.

### 4. Publikasikan kamus dan bank soal

Instal dependensi Python untuk skrip publikasi sesuai kebutuhan:

```bash
python -m pip install firebase-admin
```

Unduh **service account key** dari Firebase Console untuk proses administrasi server, lalu simpan di luar repository. Jalankan dari direktori utama proyek:

```bash
# Validasi/hitung paket tanpa menulis ke Firestore
python tools/publish_dictionary.py --csv assets/data/dict_entries.csv --dry-run
python tools/publish_quiz.py --csv tools/database_bahasa_batak.csv --dry-run

# Publikasikan setelah dry-run berhasil
python tools/publish_dictionary.py --csv assets/data/dict_entries.csv --key /path/aman/serviceAccountKey.json
python tools/publish_quiz.py --csv tools/database_bahasa_batak.csv --key /path/aman/serviceAccountKey.json
```

Ganti path key dengan lokasi file service account di komputermu. Skrip publikasi membuat koleksi metadata dan paket yang digunakan aplikasi. Jangan pernah mengunggah file service account key ke GitHub.

### 5. Uji koneksi

```bash
flutter pub get
flutter run
```

Uji login, pembacaan kamus, latihan kuis, kata tersimpan, dan progres akun. Jika Firebase tidak aktif, periksa log debug, opsi platform, status layanan Firebase, aturan Firestore, serta apakah data `dictionary_meta/current` dan `quiz_meta/current` sudah tersedia.

### Struktur koleksi Firestore

| Koleksi/dokumen | Isi dan tujuan |
|---|---|
| `dictionary_meta/current` | Versi aktif, jumlah paket, dan jumlah entri kamus. |
| `dictionary_packs/{packId}` | Paket entri kamus yang dibaca aplikasi. |
| `quiz_meta/current` | Versi aktif dan jumlah paket soal. |
| `quiz_packs/{packId}` | Paket soal pilihan ganda. |
| `users/{uid}` | Profil pengguna; akses dibatasi ke pemilik akun. |
| `users/{uid}/progress/summary` | Kata tersimpan dan statistik belajar pengguna tersebut. |

Koleksi `dict_entries` yang mungkin ada dari impor awal tidak digunakan oleh alur aplikasi saat ini.

## Mengelola Data Kamus dan Kuis

## Menjalankan Aplikasi

Prasyarat: Flutter SDK yang sesuai dengan batas versi Dart pada `pubspec.yaml`, serta Android Studio/Android SDK atau perangkat target yang sesuai.

```bash
git clone <URL_REPOSITORY>
cd belajar_bahasa_batak
flutter pub get
flutter run
```

Ganti `<URL_REPOSITORY>` dengan URL repository GitHub proyek. Untuk menjalankan di perangkat Android, aktifkan USB debugging atau gunakan emulator. Untuk menjalankan di web jika platform telah disiapkan:

```bash
flutter run -d chrome
```

## Pengujian dan Build

Jalankan pemeriksaan kode dan tes:

```bash
flutter analyze
flutter test
```

### APK Android untuk dibagikan

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

Hasil APK berada di `build/app/outputs/flutter-apk/`. Pilih APK sesuai arsitektur perangkat target.
