Berikut versi README yang lebih menarik, informatif, dan profesional untuk proyek `LenScanner`:

---

# 📸 LenScanner

**Aplikasi Flutter untuk Pembacaan Data Kamera Real-Time & Penyimpanan Otomatis ke Excel**

LenScanner dirancang untuk menangkap data angka secara real-time menggunakan kamera, memprosesnya melalui OCR, membandingkan hasil, menghitung selisih, dan menyimpannya ke file Excel secara otomatis. Didukung fitur suara beep untuk validasi, serta sistem pemuatan data otomatis dari scan sebelumnya.

---

## 🚀 Fitur Unggulan

✅ **Real-Time OCR Scan**
Gunakan kamera untuk mengenali angka secara langsung dan cepat.

✅ **Scan Ganda & Validasi**

* **Scan 1:** Data pertama ditangkap dan disimpan bersama waktu.
* **Scan 2:** Data kedua ditangkap, dibandingkan dengan Scan 1, dan dihitung selisihnya.

✅ **Perhitungan Selisih Otomatis**
Secara otomatis menghitung selisih dari dua hasil scan.

✅ **Penyimpanan ke Excel**
Data scan disimpan secara rapi ke dalam file Excel di folder **Download**, termasuk waktu dan nama yang dimasukkan.

✅ **Suara Beep Feedback**
Memberikan umpan balik audio saat terjadi kesalahan input atau proses gagal.

✅ **Load Data Sebelumnya**
Otomatis memuat hasil scan terakhir saat aplikasi dibuka kembali.

---

## 📁 Struktur Folder Penting

```
assets/
└── sounds/
    └── beep.mp3   # Suara beep saat error
```

---

## 📦 Dependency Utama

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_scalable_ocr: ^2.2.1
  camera: ^0.10.0
  path_provider: ^2.1.5
  permission_handler: ^12.0.1
  image: ^4.2.0
  excel: ^2.1.0
  intl: ^0.19.0
  audioplayers: ^5.2.1
```

---

## 📌 Catatan

* Pastikan izin kamera dan penyimpanan telah diberikan.
* File Excel akan disimpan sebagai `DataScan.xlsx` di folder **Download**.
* Jalankan di perangkat fisik, karena fitur kamera tidak berjalan di emulator.

---
