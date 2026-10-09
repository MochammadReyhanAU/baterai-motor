# Baterai Motor

Aplikasi Android & iPhone untuk memantau baterai LFP motor listrik yang memakai **JK BMS (JiKong)** lewat Bluetooth, dengan tampilan yang mudah dipahami.

## Isi aplikasi

| Layar | Isi |
|---|---|
| **Beranda** | Gambar motor yang bereaksi: roda berputar saat jalan, lampu menyala saat motor hidup, dan kabel berdenyut saat dicas. Isi baterai ditampilkan dalam persen dan perkiraan km, dengan saran seperti "Sebaiknya cas setelah perjalanan ini". Ada juga sisa waktu jalan (atau waktu sampai penuh), daya, suhu, ringkasan kondisi baterai dengan lampu hijau/kuning/merah, dan detail teknis. |
| **Sel** | Semua sel dalam bentuk baterai mini, dengan tanda sel tertinggi/terendah, status keseimbangan, dan hambatan kabel. |
| **Riwayat** | Grafik isi baterai, daya, dan suhu (1 jam sampai 3 hari), energi yang dipakai/dicas hari ini, dan grafik 7 hari. |
| **Kontrol** | Charge, Discharge, dan Balancer ON/OFF. Awalnya terkunci, ada konfirmasi sebelum mengubah, dan **mematikan daya saat motor terdeteksi jalan ditolak**. |
| **Pengaturan** | Nama dan warna motor, jarak tempuh saat baterai penuh, kalibrasi deteksi menyala/jalan, versi protokol, dan tombol putuskan/lupakan BMS. |

Ada juga **mode demo** (Parkir / Jalan / Dicas) memakai data dari screenshot aplikasi JK Anda, jadi tampilan bisa dicoba tanpa baterai.

## Batasan yang perlu diketahui

- **Status "motor menyala" hanya perkiraan.** BMS tidak tahu posisi kunci kontak. Aplikasi menebak dari arus yang keluar: di bawah 0.3 A dianggap parkir, 0.3–3 A dianggap menyala tapi diam, dan 3 A ke atas dianggap jalan. Kalibrasinya ada di Pengaturan.
- **Perkiraan km = jarak penuh × persen baterai.** Angka bawaannya 80 km, bisa diubah di Pengaturan.
- **BMS hanya bisa tersambung ke satu aplikasi sekaligus.** Tutup aplikasi JK BMS sebelum memakai aplikasi ini.
- Riwayat hanya tercatat selama aplikasi terbuka dan terhubung (1 titik per menit, disimpan 3 hari).
- Protokol yang didukung: JK02 24S (firmware lama) dan JK02 32S (firmware v11 ke atas). Versi dideteksi otomatis dari struktur data BMS, tidak bergantung pada nomor versi. Model JK04 yang sangat lama (hardware v3) belum didukung.

---

## Cara memasang ke HP Android

1. Salin file **`BateraiMotor.apk`** ke HP (lewat kabel USB, Google Drive, atau WhatsApp ke diri sendiri).
   - Atau unduh dari GitHub: tab **Actions** › **Build Android (APK)** › hasil build terakhir › **BateraiMotor-apk**.
2. Buka file tersebut di HP. Jika muncul peringatan "sumber tidak dikenal", izinkan **Pasang aplikasi tidak dikenal** untuk aplikasi yang dipakai membuka file (File Manager / Drive), lalu lanjutkan.
3. Google Play Protect mungkin memperingatkan bahwa aplikasi ini belum dikenal. Ini wajar untuk aplikasi buatan sendiri. Pilih **Tetap pasang**.
4. Buka **Baterai Motor**, ketuk **Cari baterai saya**, lalu izinkan **Perangkat di sekitar**. Di Android 11 ke bawah, izin yang diminta adalah **Lokasi**, dan GPS harus menyala saat mencari. Ini aturan Android untuk Bluetooth, bukan karena aplikasi memakai lokasi Anda.

**Kunci tanda tangan:** APK ditandatangani dengan kunci pribadi (`baterai-motor.jks`) yang disimpan **di luar repository**. Simpan file itu dan passwordnya baik-baik. Update aplikasi hanya bisa dipasang tanpa menghapus data jika memakai kunci yang sama.

## Cara memasang ke iPhone (dari Windows, tanpa Mac)

Ringkasnya: kode diunggah ke GitHub, lalu GitHub membangun file `.ipa` di Mac milik mereka (gratis). Setelah itu Sideloadly di Windows memasang file tersebut ke iPhone memakai Apple ID Anda.

### 1. Unggah kode ke GitHub (sekali saja)
1. Buat akun di github.com.
2. Klik **New repository** dan beri nama, misalnya `baterai-motor`.
   - Repository **Public**: menit build Mac gratis tanpa batas.
   - Repository **Private**: ada kuota menit Mac gratis per bulan. *Perlu dicek di halaman harga GitHub, ketentuannya bisa berubah.*
3. Pilih **uploading an existing file**, lalu seret **seluruh isi** folder ini, termasuk folder `.github`. Klik **Commit changes**.
   - Atau pakai aplikasi **GitHub Desktop**, yang lebih mudah untuk pembaruan berikutnya.

### 2. Build file .ipa
1. Buka tab **Actions** di repository → **Build iOS (IPA)** → **Run workflow**.
2. Tunggu sekitar 10–20 menit sampai muncul centang hijau.
3. Buka hasil build, lalu unduh **BateraiMotor-ipa** di bagian *Artifacts*. Ekstrak zip-nya untuk mendapatkan `BateraiMotor.ipa`.

### 3. Pasang dengan Sideloadly
1. Unduh **Sideloadly** dari sideloadly.io dan pasang di Windows.
2. Sambungkan iPhone ke PC dengan kabel USB, lalu ketuk **Trust / Percayai** di iPhone.
3. Seret `BateraiMotor.ipa` ke Sideloadly, isi Apple ID, lalu klik **Start**.
4. Di iPhone:
   - Buka **Pengaturan → Umum → VPN & Manajemen Perangkat**, pilih Apple ID Anda, lalu **Percayai**.
   - iOS 16 ke atas: buka **Pengaturan → Privasi & Keamanan → Mode Pengembang**, nyalakan, lalu restart iPhone.
5. Buka aplikasi **Baterai Motor** dan izinkan Bluetooth.

> **Dengan Apple ID gratis, aplikasi berhenti bisa dibuka setelah 7 hari.** Ulangi langkah 3 untuk memasang ulang (data riwayat biasanya tetap ada). Sideloadly punya fitur refresh otomatis. Supaya bertahan 1 tahun, perlu akun Apple Developer berbayar.

### Kalau build di GitHub gagal
Buka langkah yang merah di halaman Actions, salin pesan errornya, lalu kirim ke Claude untuk diperbaiki.

---

## Untuk pengembang

- Flutter 3.47.7, Dart 3.13. Tes: `flutter test` (frame asli dari esphome-jk-bms).
- Build Android: `flutter build apk --release` (perlu Android SDK; compileSdk 37).
- Pratinjau di browser: `flutter run -d chrome`, lalu buka `/?demo=riding` (Bluetooth tidak tersedia di web).
- Struktur:
  - `lib/protocol/jk_protocol.dart`: perintah, penyusun frame, dan parser.
  - `lib/services/ble_link.dart`: koneksi Bluetooth (flutter_reactive_ble, BSD-3).
  - `lib/logic/insights.dart`: deteksi status motor, penilaian kondisi, dan teks bahasa Indonesia.
  - `lib/ui/`: semua layar. `widgets/motor_scene.dart` berisi gambar motor animasi.

Protokol dipetakan dari [esphome-jk-bms](https://github.com/syssi/esphome-jk-bms). Aplikasi ini tidak berafiliasi dengan JiKong.
