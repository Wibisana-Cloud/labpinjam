class Alat {
  final String kode;
  final String nama;
  final String deskripsi;
  final bool tersedia;
  final bool diarsipkan;
  final String? peminjamAktif;

  const Alat({
    required this.kode,
    required this.nama,
    required this.deskripsi,
    required this.tersedia,
    this.diarsipkan = false,
    this.peminjamAktif,
  });

  bool cocokFilter(String filter, {String? wallet}) => switch (filter) {
    'Semua' => true,
    'Tersedia' => !diarsipkan && tersedia,
    'Dipinjam' => !diarsipkan && !tersedia,
    'Arsip' => diarsipkan,
    'Pinjaman saya' =>
      !diarsipkan &&
          !tersedia &&
          wallet != null &&
          peminjamAktif?.toLowerCase() == wallet.toLowerCase(),
    _ => !diarsipkan,
  };
}
