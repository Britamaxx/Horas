# Horas - Belajar Bahasa Batak

Aplikasi Flutter untuk pemula berbahasa Indonesia yang ingin mencari terjemahan, menghafal kosakata, berlatih kuis, dan nantinya menyusun kalimat Batak Toba dari materi yang tervalidasi.

## Menjalankan aplikasi

```sh
flutter pub get
flutter run
```

Kamus awal dimuat secara offline dari `assets/data/dict_entries.csv`. File tersebut berisi 14.618 entri; pencarian mencakup kata Indonesia dan definisi Batak. Kata tersimpan dan hasil kuis disimpan lokal di perangkat. Beranda menggunakan kata tersimpan dan riwayat kuis lokal untuk menentukan saran belajar, bukan streak yang belum direkam.

## Profil, login, dan penyimpanan akun

Layar Profil/login, `AuthRepository`, `UserProfileRepository`, dan model `UserProfile` sudah menyiapkan batas integrasi, tetapi login belum aktif dan belum ada data akun yang dikirim ke server. Progres tetap tersimpan lokal sampai Firebase dikonfigurasi.

Rencana integrasi:

1. Buat project Firebase dan jalankan FlutterFire CLI untuk menghasilkan konfigurasi platform. Jangan commit file konfigurasi yang berisi rahasia atau memasukkan secret server ke aplikasi.
2. Tambahkan FlutterFire Authentication dan aktifkan Google sebagai provider di Firebase Console. Konfigurasikan OAuth client, SHA-1/SHA-256 Android, serta file konfigurasi platform yang diperlukan.
3. Implementasikan `AuthRepository` dengan Firebase Auth dan `UserProfileRepository` dengan Firestore; injeksikan implementasi tersebut saat bootstrap menggantikan nilai yang saat ini belum dikonfigurasi.
4. Gunakan dokumen `users/{uid}` dengan skema profil di bawah. Batasi akses profil ke `request.auth.uid == uid` menggunakan Firestore Security Rules. Simpan progress pengguna dalam subkoleksi, bukan mencampurnya dengan kredensial autentikasi.

| Field | Tipe Firestore | Keterangan |
|---|---|---|
| `uid` | string | Harus sama dengan ID dokumen dan Firebase Auth UID |
| `displayName` | string/null | Nama tampilan dari provider |
| `email` | string/null | Email dari provider, bukan kunci otorisasi |
| `photoUrl` | string/null | URL foto profil |
| `providerIds` | array string | Contoh ID provider Firebase `google.com` |
| `preferredDialect` | string/null | Preferensi pengguna; metadata kamus tetap per entri |
| `createdAt` | timestamp | Waktu pembuatan profil |
| `lastSignInAt` | timestamp | Waktu login terakhir |
| `updatedAt` | timestamp | Waktu perubahan profil terakhir |

Jangan simpan password, Google OAuth token, atau kredensial Firebase di dokumen profil. Pertimbangkan `users/{uid}/savedWords/{entryId}` dan `users/{uid}/learningStats/summary` untuk progres tersinkronisasi setelah aturan akses dan kebutuhan retensi ditentukan.

Cloudflare Turnstile bersifat opsional sebagai pemeriksaan anti-bot. Jika dipakai, validasi token pada Cloudflare Worker/server tepercaya; secret Turnstile hanya berada di environment Worker. Turnstile bukan login Google maupun autentikasi Firebase. Cloudflare Access cocok untuk membatasi aplikasi privat, bukan sebagai login pengguna umum Horas.

## Latihan kalimat

CSV kamus hanya memuat kosakata dan definisi, bukan contoh kalimat atau tata bahasa. Mode **Susun kalimat** disiapkan khusus Batak Toba, tetapi akan menampilkan status materi belum tersedia sampai latihan berpasangan terjemahan Indonesia–Batak, urutan token, dan referensi sumber tervalidasi diberikan. `SentenceExerciseRepository` adalah seam untuk memuat katalog lokal/Firebase. Aplikasi hanya akan memeriksa urutan terhadap materi yang disediakan sumber; tidak mengekstrapolasi tata bahasa dari entri kamus.

Setiap dokumen latihan mendatang perlu memuat `id`, `dialect` (`toba`), `indonesianPrompt`, `batakSentence`, `tokens` sesuai urutan sumber, `sourceName`, dan `sourceReference`. `tokens.join(' ')` harus sama persis dengan `batakSentence`. Tinjau hak penggunaan dan akurasi dialek sebelum menambahkan dokumen. Tanpa katalog, repository lokal memang kosong dan layar menjelaskan materi belum disediakan.

`HorasApp` menerima `authRepository`, `userProfileRepository`, serta `sentenceExerciseRepository` agar adapter backend dapat diinjeksi tanpa mengubah layar. Implementasi Firebase harus menginisialisasi FlutterFire sebelum aplikasi, memetakan Google/Firebase Auth ke `AuthRepository`, menerjemahkan Firestore `Timestamp` ke `DateTime` di adapter, dan menerapkan Security Rules berbasis UID. Progres lokal tidak otomatis dikirim setelah login; migrasi/sinkronisasi memerlukan kebijakan konflik dan persetujuan produk tersendiri.

## Pengembangan Firebase

Firebase belum dikonfigurasi karena kredensial dan project Firebase belum disediakan. `DictionaryRepository` memisahkan sumber data dari UI; `CsvDictionaryRepository` adalah sumber offline saat ini. Setelah konfigurasi FlutterFire tersedia, tambahkan implementasi repository berbasis Firestore yang mengikuti field kamus dan pilih repository tersebut saat aplikasi dimulai. Jangan menambahkan kredensial ke source control.

## Pemeriksaan

```sh
flutter test
flutter analyze
```

## Progres per akun dan performa

**Kata tersimpan dan statistik kuis kini milik masing-masing akun.**

- Firestore: satu dokumen per akun di `users/{uid}/progress/summary`
  (`savedEntryIds`, `completedQuizzes`, `correctAnswers`, `answeredQuestions`).
  Satu dokumen berarti membuka aplikasi hanya 1 baca. Perubahan memakai
  `arrayUnion`/`arrayRemove`/`increment` sehingga dua perangkat tergabung,
  bukan saling menimpa.
- Di perangkat: cache terpisah per akun (`acct.<uid>.*`) sehingga aplikasi
  terbuka instan dan tetap jalan offline. Mode tamu memakai kunci lama.
- Progres yang dikumpulkan sebagai tamu dipindahkan ke akun pertama yang
  masuk di perangkat itu, lalu data tamu dikosongkan.
- Perubahan diterapkan ke UI dulu, lalu dikirim ke server di latar belakang.

**Kamus dibaca dari Firebase, dengan salinan di perangkat.**

- Firestore: `dictionary_meta/current` (versi) dan `dictionary_packs/*`
  (kamus dibagi menjadi beberapa paket berisi ratusan entri). Satu pemasangan
  baru hanya membaca sekitar 7 dokumen, bukan 14 ribu dokumen satu per satu.
- Pertama kali dibuka: kamus diunduh lalu disimpan di perangkat. Berikutnya
  aplikasi terbuka instan dan bisa offline.
- Setiap dibuka, aplikasi mengecek versi di latar belakang (1 baca). Versi baru
  diunduh dan mulai dipakai pada pembukaan berikutnya.
- Jika pembukaan pertama tanpa internet (atau kamus belum dipublikasikan),
  aplikasi memakai `assets/data/dict_entries.csv` sebagai cadangan.
- Memperbarui kamus: ubah CSV, lalu jalankan
  `python tools/publish_dictionary.py --csv assets/data/dict_entries.csv --key serviceAccountKey.json`.
- Memerlukan paket `path_provider` (`flutter pub add path_provider`). Di web
  tidak ada salinan berkas, jadi kamus diunduh setiap dibuka (sekitar 7 baca).

Yang membuat aplikasi ringan:

- Kamus diurai/dibaca di isolate latar belakang (`compute`), bukan di thread UI.
- `DictionaryIndex` menghitung sekali: kunci pencarian huruf kecil, kelas
  kata, bahan kuis, dan posisi id. Pencarian tidak lagi membuat string baru
  per entri, dan diberi jeda 250 ms saat mengetik.
- Hasil pencarian disimpan di state layar kamus, jadi menyimpan kata atau
  berpindah tab tidak menyaring ulang seluruh kamus.
- Soal kuis diambil acak dari data yang sudah disiapkan.
- Firebase dan kamus dimuat bersamaan; layar pemuatan langsung tampil.

## Soal kuis dari Firebase

Tab Latihan memakai bank soal di Firestore, bukan soal acak dari kamus:

- `quiz_meta/current` (versi) dan `quiz_packs/*` (isi soal). Dibuat oleh
  `python tools/publish_quiz.py --csv tools/database_bahasa_batak.csv --key <kunci>`.
- Satu pemasangan baru membaca sekitar 2 dokumen. Salinan disimpan di perangkat
  (SharedPreferences), jadi Latihan siap instan dan bisa offline.
- Setiap dibuka, aplikasi mengecek versi di latar belakang (1 baca). Versi baru
  dipakai pada pembukaan berikutnya.
- Satu putaran = 10 soal acak dari bank soal, tanpa pengulangan.
- Jika bank soal belum bisa diambil (belum dipublikasikan, atau pembukaan pertama
  tanpa internet), kuis memakai soal otomatis dari kamus seperti sebelumnya.
- Untuk memperbarui soal: ubah CSV, jalankan ulang `publish_quiz.py`.

