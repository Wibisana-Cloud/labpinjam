# LabPinjam V3

Aplikasi Flutter untuk pencatatan peminjaman alat laboratorium melalui smart contract **LogbookAlatV3** pada Ethereum Sepolia. Transaksi disetujui melalui Reown AppKit dan MetaMask; aplikasi tidak meminta private key atau seed phrase.

Repository: [Wibisana-Cloud/labpinjam](https://github.com/Wibisana-Cloud/labpinjam).

## Fitur

- Daftar alat, jumlah inventaris, detail, status tersedia/dipinjam, dan riwayat.
- Pencarian kode/nama serta filter Semua, Aktif, Tersedia, Dipinjam, Pinjaman saya, dan Arsip.
- Tambah alat serta edit nama/deskripsi oleh admin.
- Peminjaman dan pengembalian oleh wallet peminjam aktif.
- Arsip oleh admin untuk alat yang tidak sedang dipinjam; riwayat tetap tersedia.
- Hash transaksi, pemeriksaan receipt, dan pesan kegagalan. Hash saja bukan bukti transaksi sukses.
- Refresh manual dan pemantauan event tambah, edit, pinjam, kembali, serta arsip untuk memperbarui daftar.

Filter Pinjaman saya memakai alamat wallet yang dipilih melalui halaman Wallet. Filter tersebut bukan mekanisme otorisasi transaksi. Pembatasan akses ditegakkan oleh smart contract.

## Kontrak dan jaringan

| Konfigurasi | Nilai |
|---|---|
| Kontrak | `LogbookAlatV3` |
| Source | `contracts/LogbookAlatV3.sol` |
| Jaringan | Ethereum Sepolia |
| Chain ID | `11155111` |
| Alamat | `0x18C597a50cA4A1F4b4c720d2D542C3e09D44f858` |
| ABI | `assets/logbook_alat_abi.json` |
| Konfigurasi | `lib/config/blockchain_config.dart` |

[Lihat kontrak di Etherscan Sepolia](https://sepolia.etherscan.io/address/0x18C597a50cA4A1F4b4c720d2D542C3e09D44f858#code).

Deployment telah dilaporkan berhasil melalui Remix. Verifikasi source di Etherscan belum dikonfirmasi berhasil; percobaan terakhir yang ditinjau gagal karena kode Dart ditempel pada kolom source Solidity. Untuk verifikasi, gunakan source Solidity yang sama dengan deployment dan pengaturan compiler, optimizer, serta EVM target yang sama. Tidak perlu deploy ulang hanya untuk memperbaiki pengajuan verifikasi.

Aplikasi memakai satu kontrak V3. Data V2 tidak otomatis dipindahkan; riwayat lama tetap berada pada deployment V2.

## Aturan smart contract

- Admin ditetapkan dari wallet deployer dan tidak dapat diganti.
- Kode alat unik, 1-32 byte, hanya A-Z, 0-9, atau minus.
- Nama wajib berisi 1-100 byte; deskripsi maksimal 500 byte.
- Hanya admin dapat menambah dan mengedit alat. Edit nama/deskripsi tidak mengubah kode atau riwayat.
- Alat tersedia dapat dipinjam; hanya peminjam aktif dapat mengembalikannya.
- Alat arsip tidak dapat dipinjam atau diedit. Arsip permanen pada versi ini dan kode tidak dapat digunakan ulang.
- Total inventaris mencakup arsip; jumlah Dipinjam tidak menghitung arsip.

## Versi lingkungan dan dependensi

Dokumentasi pengembangan mencatat Flutter 3.44.9 dan Dart 3.12.2. Cocokkan versi SDK di komputer dengan kebutuhan `pubspec.yaml`.

| Paket | Batas versi pada pubspec.yaml |
|---|---|
| web3dart | ^3.0.3 |
| http | ^1.6.0 |
| wallet | ^0.0.18 |
| reown_appkit | ^1.9.0 |
| cupertino_icons | ^1.0.8 |
| flutter_lints | ^6.0.0 |

`pubspec.lock` mencatat versi dependensi yang terpasang. Android memerlukan SDK dan JDK yang sesuai dengan konfigurasi proyek.

## Menjalankan aplikasi

1. Clone repository dan buka folder proyek:

```powershell
git clone https://github.com/Wibisana-Cloud/labpinjam.git
cd labpinjam
flutter pub get
```

2. Buat konfigurasi lokal dari contoh:

```powershell
Copy-Item config.example.json config.local.json
```

3. Isi `RPC_URL` dengan endpoint Sepolia milik sendiri dan `REOWN_PROJECT_ID` dengan project ID Reown milik sendiri. Alamat kontrak V3 sudah dicantumkan pada contoh. Jangan mengganti nama kunci JSON.

```json
{
  "RPC_URL": "https://eth-sepolia.g.alchemy.com/v2/ISI_API_KEY",
  "REOWN_PROJECT_ID": "ISI_PROJECT_ID",
  "CONTRACT_ADDRESS": "0x18C597a50cA4A1F4b4c720d2D542C3e09D44f858"
}
```

4. Siapkan MetaMask di Sepolia, wallet khusus tugas, Sepolia ETH untuk gas transaksi, dan perangkat Android dengan USB debugging.
5. Periksa dan jalankan:

```powershell
flutter analyze
flutter devices
flutter run -d DEVICE_ID --dart-define-from-file=config.local.json
```

Ganti `DEVICE_ID` dengan ID dari `flutter devices`. Alternatifnya, pilih profil **LabPinjam (lokal)** di Run and Debug VS Code lalu tekan F5.

`config.local.json` tidak diunggah ke Git. Nilai dibaca saat build; hentikan dan jalankan ulang aplikasi setelah mengubahnya. Hot reload tidak mengganti nilai dart-define. Parameter build bukan penyimpanan rahasia, sehingga jangan memuat private key atau seed phrase di dalamnya.

## Struktur utama

```text
contracts/LogbookAlatV3.sol
assets/logbook_alat_abi.json
lib/
  main.dart
  config/blockchain_config.dart
  models/alat.dart
  services/
  pages/
  ui/
config.example.json
pubspec.yaml
pubspec.lock
```

## Penggunaan

1. Buka beranda untuk membaca daftar dan detail alat.
2. Hubungkan akun melalui Wallet. Wallet deployer memperoleh formulir admin.
3. Tambah alat dengan kode baru, lalu setujui MetaMask dan periksa receipt.
4. Buka detail untuk meminjam atau mengembalikan alat.
5. Untuk edit, buka Wallet > Edit alat > masukkan kode > Muat data alat > ubah data > Simpan melalui MetaMask.
6. Untuk arsip, buka Wallet > Arsipkan alat > masukkan kode > konfirmasi > setujui MetaMask. Periksa hasilnya pada filter Arsip.

Jika konfirmasi belum tersedia, gunakan Cek konfirmasi. Periksa aktivitas MetaMask sebelum mengulang permintaan yang hasilnya belum jelas.

## Build APK

```powershell
flutter build apk --release --dart-define-from-file=config.local.json
```

Hasil: `build/app/outputs/flutter-apk/app-release.apk`. Uji APK di HP sebelum diunggah ke Google Drive atau GitHub Releases. Jangan unggah seluruh folder build ke repository.

## Pengujian dan batasan

Pemeriksaan Dart serta pengujian format ABI dan sembilan kasus filter pada paket pengembangan sebelumnya telah lolos. Hasil ini tidak membuktikan seluruh alur transaksi di HP atau kecocokan bytecode deployment. Pengujian menyeluruh V3, APK release, dan verifikasi source masih perlu dilengkapi dengan bukti.

Pemantauan event memerlukan RPC yang mendukung filter Ethereum. Jika terputus, gunakan Sambung atau refresh manual. Hash pending belum disimpan setelah halaman ditutup. Admin tidak dapat diganti, arsip belum dapat dipulihkan, dan riwayat dibaca seluruhnya sehingga perlu pengembangan untuk skala besar. Blockchain mencatat aktivitas wallet, bukan bukti serah terima fisik atau kondisi alat.

## Pengumpulan

- Repository: https://github.com/Wibisana-Cloud/labpinjam
- APK: ISI_LINK_APK
- Video demo 3-5 menit: ISI_LINK_VIDEO
- Laporan kelompok: PDF maksimal 5 halaman.
- Jurnal Tonton: PDF individu 1-2 halaman.

Video menunjukkan deployment, baca/tambah data melalui aplikasi, dan pemeriksaan transaksi di Etherscan. Identitas serta kontribusi anggota dicantumkan pada laporan terpisah.

## Keamanan dan sumber

Gunakan testnet Sepolia. Jangan unggah private key, seed phrase, atau config.local.json. Hindari data pribadi di blockchain publik.

Pengembangan menggunakan Flutter, web3dart, Reown AppKit, MetaMask, dan Remix. Dokumentasi serta pembaruan kode dibantu AI; anggota kelompok tetap harus memahami kode yang dikumpulkan. Lengkapi sumber tutorial/kode yang benar-benar diadaptasi: ISI_SUMBER_KODE_ATAU_TUTORIAL.
