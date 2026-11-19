# LabPinjam

Aplikasi Flutter untuk pencatatan peminjaman alat laboratorium melalui smart contract **LogbookAlatV2** di Ethereum Sepolia. Wallet menandatangani transaksi melalui Reown AppKit/MetaMask; aplikasi tidak menyimpan private key.

## Fitur

- Daftar alat, jumlah alat, nama, deskripsi, serta status tersedia/dipinjam.
- Pencarian kode/nama, filter status, tombol refresh dan tarik untuk memuat ulang.
- Detail alat dan riwayat peminjaman.
- Koneksi wallet pada Sepolia dan identifikasi admin dari kontrak.
- Tambah alat khusus admin; kode unik, nama, dan deskripsi divalidasi.
- Pinjam alat dan pengembalian oleh wallet peminjam.
- Status pengiriman transaksi, hash transaksi, serta pemeriksaan receipt.

Status berhasil harus berdasarkan receipt transaksi, bukan hanya diterimanya hash. Pembaruan data dilakukan melalui refresh/alur kembali dari halaman; belum ada langganan event otomatis.

## Kontrak dan jaringan

| Konfigurasi | Nilai |
|---|---|
| Kontrak | LogbookAlatV2 |
| Jaringan | Ethereum Sepolia |
| Chain ID | 11155111 |
| Alamat | `0x5ca0dD2Bf9Eab9C457f5Bcb0267D8593Ae366594` |
| ABI | `assets/logbook_alat_abi.json` |
| Pragma source | `^0.8.20` |
| Compiler deployment (menurut dokumentasi proyek) | Solidity v0.8.34+commit.80d5c536 |
| Optimizer deployment | Nonaktif |

[Source code kontrak di Etherscan](https://sepolia.etherscan.io/address/0x5ca0dD2Bf9Eab9C457f5Bcb0267D8593Ae366594#code)

[Contoh transaksi yang dibagikan saat pengujian](https://sepolia.etherscan.io/tx/0x5724b331ff6dd4c812607c3ed4ad1182171ea6d0c14a14390b0d9d47d88ed632). Buka explorer untuk melihat fungsi dan status transaksi tersebut.

Admin ditetapkan dari wallet deployer pada constructor dan bersifat immutable. Pembatasan admin ditegakkan di kontrak, selain pembatasan tampilan di aplikasi.

## Versi lingkungan dan paket

Versi berikut dicatat dalam dokumentasi proyek. Cocokkan dengan lingkungan dan pubspec.lock saat menjalankan ulang:

| Komponen | Versi |
|---|---|
| Flutter | 3.44.9 |
| Dart | 3.12.2 |
| web3dart | 3.0.3 |
| http | 1.6.0 |
| wallet | 0.0.18 |
| reown_appkit | 1.9.0 |
| cupertino_icons | 1.0.9 |
| flutter_lints | 6.0.0 |

Gunakan `pubspec.lock` untuk menjaga versi dependensi. Android memerlukan SDK dan JDK yang kompatibel dengan proyek; konfigurasi Java proyek menggunakan Java 17.

## Menjalankan aplikasi

1. Unduh/clone repository ini, buka folder yang berisi `pubspec.yaml`.
2. Siapkan Flutter, Android SDK, perangkat Android dengan USB debugging, serta MetaMask.
3. Atur MetaMask ke Sepolia dan siapkan Sepolia ETH untuk gas transaksi uji.
4. Isi konfigurasi di `lib/config/blockchain_config.dart`:

```dart
class BlockchainConfig {
  static const String rpcUrl =
      'https://eth-sepolia.g.alchemy.com/v2/ISI_API_KEY_ALCHEMY';
  static const String contractAddress =
      '0x5ca0dD2Bf9Eab9C457f5Bcb0267D8593Ae366594';
  static const int chainId = 11155111;
  static const String abiAssetPath = 'assets/logbook_alat_abi.json';
  static const String reownProjectId = 'ISI_PROJECT_ID_REOWN';
}
```

Gunakan API key dan project ID milik sendiri. Jangan memasukkan seed phrase atau private key. Konfigurasi saat ini berupa konstanta; perintah di bawah tidak menggunakan `--dart-define`.

5. Jalankan:

```powershell
flutter pub get
flutter analyze
flutter devices
flutter run -d ID_PERANGKAT
```

Ganti `ID_PERANGKAT` dengan hasil `flutter devices`. Baca daftar/riwayat tanpa mengirim transaksi; hubungkan wallet untuk tambah, pinjam, dan kembalikan alat.

## Struktur

```text
lib/
  main.dart
  config/blockchain_config.dart
  services/blockchain_service.dart
  ui/lab_ui.dart
  pages/
    detail_alat_page.dart
    wallet_page.dart
    transaksi_alat_panel.dart
    tambah_alat_panel.dart
assets/logbook_alat_abi.json
android/
```

### Source smart contract

Kode smart contract disimpan di `contracts/LogbookAlat2.sol`. Nama kontrak di dalam file adalah `LogbookAlatV2`; nama file dan nama kontrak boleh berbeda.

Untuk melengkapi repository:

1. Buat folder `contracts` di folder utama proyek, sejajar dengan `lib` dan `assets`.
2. Salin kode Solidity asli dari editor Remix ke file `contracts/LogbookAlat2.sol`.
3. Gunakan kode yang sama dengan kontrak yang sudah di-deploy dan digunakan aplikasi.
4. Pastikan `assets/logbook_alat_abi.json` berisi ABI hasil kompilasi kontrak tersebut, serta alamat kontrak pada konfigurasi menunjuk ke deployment yang sesuai.

Menyalin source ke repository tidak memerlukan deployment ulang. Kecocokan source dengan deployment belum diperiksa ulang dalam penyusunan dokumentasi ini.

## Arsitektur dan alur

Flutter membaca kontrak melalui `BlockchainService` -> web3dart -> RPC Alchemy -> Sepolia. ABI menjelaskan fungsi dan format data. Transaksi perubahan data diajukan ke wallet melalui Reown, disetujui pengguna di MetaMask, kemudian diproses jaringan. Etherscan digunakan untuk memeriksa transaksi dan source kontrak.

| Operasi | Fungsi kontrak | Pengguna |
|---|---|---|
| Daftar/jumlah | lihatDaftarAlat, jumlahAlat | Semua |
| Detail/status | ambilAlat, lihatStatus | Semua |
| Riwayat | lihatRiwayat | Semua |
| Tambah alat | tambahAlat | Admin |
| Pinjam | pinjamAlat | Wallet, jika alat tersedia |
| Kembalikan | kembalikanAlat | Peminjam aktif |

## Build APK

```powershell
flutter pub get
flutter build apk --release
```

Hasil: `build/app/outputs/flutter-apk/app-release.apk`.

Saat dokumentasi dibuat, baru `app-debug.apk` yang ditemukan; build release belum diverifikasi. Uji pemasangan dan alur utama pada APK yang akan dikumpulkan. Dokumen tugas meminta APK hasil build dan tidak secara eksplisit mewajibkan varian release.

Unggah APK ke Google Drive atau GitHub Releases dan cantumkan tautannya di bawah. Jangan unggah seluruh folder `build/` ke Git.

## Pengujian dan batasan

Dokumentasi sebelumnya mencatat laporan keberhasilan alur tambah, pinjam, dan pengembalian serta hasil analisis Dart tanpa masalah. Penyusunan README ini tidak menjalankan ulang aplikasi, mengompilasi source Solidity, atau memverifikasi transaksi langsung. APK debug tersedia; build release dan pengujian menyeluruh belum dikonfirmasi.

Kendala yang ditangani meliputi alamat kontrak salah salin, pembaruan ABI V2, konfigurasi RPC Sepolia pada wallet, serta kompatibilitas build Android/dependensi. Uji ulang build release setelah perubahan dependensi.

Proyek ini adalah prototipe pembelajaran. Transaksi memerlukan persetujuan wallet, gas, dan waktu konfirmasi. Blockchain mencatat pernyataan wallet; tidak membuktikan serah terima fisik, kondisi alat, atau identitas mahasiswa. Belum tersedia edit/hapus alat, filter khusus milik wallet, serta sinkronisasi event otomatis.

Dokumen tugas secara eksplisit mengizinkan alternatif Logbook peminjaman alat Lab IoT. LabPinjam menggunakan alternatif tersebut: nama alat, alamat wallet peminjam, waktu pinjam, dan waktu kembali dicatat on-chain. Perubahan status dilakukan melalui peminjaman dan pengembalian.

## Pengumpulan

- Repository: ISI_LINK_REPOSITORY (pastikan dapat diakses dosen).
- APK: ISI_LINK_APK.
- Video demo 3-5 menit: ISI_LINK_VIDEO (YouTube unlisted/Google Drive).
- Laporan singkat PDF maksimal 5 halaman: lampirkan laporan kelompok.
- Jurnal Tonton 1-2 halaman: disusun masing-masing anggota sesuai kegiatan menonton sebenarnya.

Video memperlihatkan deploy di Remix, pembacaan data di aplikasi, tambah alat melalui aplikasi dan persetujuan wallet, serta hash/status transaksi di Etherscan. Tambahkan pinjam/kembali bila waktu mencukupi. Gunakan alamat kontrak yang konsisten dan jangan menampilkan private key/seed phrase.

## Aturan smart contract

- Admin ditetapkan sekali dari `msg.sender` saat deployment dan tidak dapat diganti.
- `tambahAlat` hanya dapat dipanggil admin. Kode wajib unik, panjang 1-32 byte, dan hanya berisi A-Z, 0-9, atau minus.
- Nama alat wajib berisi 1-100 byte; deskripsi maksimal 500 byte. Batas ini adalah byte UTF-8, bukan jumlah karakter.
- Alat tersedia jika belum pernah dipinjam atau peminjaman terakhir sudah dikembalikan.
- `pinjamAlat` mencatat alamat wallet pemanggil dan `block.timestamp`.
- `kembalikanAlat` hanya menerima peminjam aktif dan mencatat waktu kembali.
- `lihatRiwayat` mengembalikan seluruh riwayat untuk kode alat yang terdaftar.
- Event yang tersedia: `AlatDitambahkan`, `AlatDipinjam`, dan `AlatDikembalikan`.

## Skenario uji sebelum pengumpulan

- [ ] Daftar, detail, status, dan riwayat terbaca dari kontrak Sepolia.
- [ ] Admin dapat menambah alat dengan kode baru; data muncul setelah transaksi berhasil dan refresh.
- [ ] Kode duplikat, kode tidak valid, serta input melebihi batas ditolak.
- [ ] Wallet nonadmin ditolak oleh kontrak ketika mencoba menambah alat.
- [ ] Alat tersedia dapat dipinjam; peminjaman kedua saat masih aktif ditolak.
- [ ] Wallet lain tidak dapat mengembalikan pinjaman aktif.
- [ ] Peminjam dapat mengembalikan alat dan waktu kembali tercatat.
- [ ] Penolakan wallet, gangguan koneksi, dan transaksi gagal ditampilkan dengan jelas.
- [ ] Hash transaksi pada aplikasi cocok dengan transaksi sukses di Etherscan.
- [ ] APK yang dikumpulkan dapat dipasang dan menjalankan alur utama di HP.

## Keamanan dan sumber

Gunakan Sepolia dan wallet khusus tugas. Jangan masukkan private key atau seed phrase ke kode, repository, video, maupun tangkapan layar. Hindari menyimpan nama lengkap atau NIM mahasiswa on-chain; peminjam pada kontrak ini direpresentasikan oleh alamat wallet.

Sumber teknis yang digunakan dalam proyek:

- Flutter SDK dan paket web3dart/http untuk antarmuka serta akses RPC.
- Reown AppKit dan MetaMask untuk koneksi wallet serta persetujuan transaksi.
- Remix IDE untuk kompilasi/deployment Solidity dan Etherscan untuk pemeriksaan kontrak/transaksi.
- Bantuan AI digunakan untuk penyusunan dokumentasi ini. Setiap anggota tetap harus memahami kode yang dikumpulkan.

Lengkapi sumber tutorial atau kode yang benar-benar diadaptasi: ISI_SUMBER_KODE_ATAU_TUTORIAL. Jurnal Tonton disusun sendiri oleh setiap anggota sesuai ketentuan tugas.
