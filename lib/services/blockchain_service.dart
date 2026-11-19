import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart' show EthereumAddress;

import '../config/blockchain_config.dart';
import '../models/alat.dart';
export '../models/alat.dart';

class RiwayatPeminjaman {
  final String peminjam;
  final DateTime waktuPinjam;
  final DateTime? waktuKembali;

  const RiwayatPeminjaman({
    required this.peminjam,
    required this.waktuPinjam,
    required this.waktuKembali,
  });
}

class BlockchainService {
  final Web3Client _client = Web3Client(BlockchainConfig.rpcUrl, http.Client());

  DeployedContract? _contract;

  // web3dart polls Ethereum event filters over the configured HTTP RPC.
  Stream<void> pantauPerubahanAlat() async* {
    await _cekJaringan();
    final contract = await _ambilKontrak();
    const names = [
      'AlatDitambahkan',
      'AlatDipinjam',
      'AlatDikembalikan',
      'AlatDiarsipkan',
      'AlatDiubah',
    ];
    final topics = names.map((name) {
      final bytes = contract.event(name).signature;
      return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    }).toList();
    yield* _client
        .events(FilterOptions(address: contract.address, topics: [topics]))
        .map((_) {});
  }

  Future<void> _cekJaringan() async {
    BlockchainConfig.validasi();
    final chainId = await _client.getChainId().timeout(
      const Duration(seconds: 20),
    );

    if (chainId != BigInt.from(BlockchainConfig.chainId)) {
      throw StateError('RPC harus menggunakan Ethereum Sepolia.');
    }
  }

  Future<DeployedContract> _ambilKontrak() async {
    BlockchainConfig.validasi();
    if (_contract != null) return _contract!;
    if (!RegExp(
      r'^0x[0-9a-fA-F]{40}$',
    ).hasMatch(BlockchainConfig.contractAddress)) {
      throw StateError('Isi CONTRACT_ADDRESS dengan alamat deployment V3.');
    }

    final abi = await rootBundle.loadString(BlockchainConfig.abiAssetPath);

    _contract = DeployedContract(
      ContractAbi.fromJson(abi, 'LogbookAlatV3'),
      EthereumAddress.fromHex(BlockchainConfig.contractAddress),
    );

    return _contract!;
  }

  Future<int> ambilJumlahAlat() async {
    await _cekJaringan();
    final contract = await _ambilKontrak();
    final result = await _client
        .call(
          contract: contract,
          function: contract.function('jumlahAlat'),
          params: [],
        )
        .timeout(const Duration(seconds: 20));
    return (result.first as BigInt).toInt();
  }

  Future<String> ambilAdmin() async {
    await _cekJaringan();
    final contract = await _ambilKontrak();
    final hasil = await _client
        .call(
          contract: contract,
          function: contract.function('admin'),
          params: [],
        )
        .timeout(const Duration(seconds: 20));
    return (hasil.first as EthereumAddress).with0x;
  }

  Future<Alat> ambilAlat(String kode) async {
    final contract = await _ambilKontrak();
    final hasil = await _client
        .call(
          contract: contract,
          function: contract.function('ambilAlat'),
          params: [kode],
        )
        .timeout(const Duration(seconds: 20));
    final arsip = await ambilArsip(kode);
    final history = !(hasil[2] as bool) && !arsip
        ? await ambilRiwayat(kode)
        : <RiwayatPeminjaman>[];
    return Alat(
      kode: kode,
      nama: hasil[0] as String,
      deskripsi: hasil[1] as String,
      tersedia: hasil[2] as bool,
      diarsipkan: arsip,
      peminjamAktif: history.isNotEmpty && history.first.waktuKembali == null
          ? history.first.peminjam
          : null,
    );
  }

  static String? validasiKode(String? value) {
    final kode = (value ?? '').trim();
    if (!RegExp(r'^[A-Z0-9-]{1,32}$').hasMatch(kode)) {
      return 'Gunakan 1–32 karakter: A-Z, 0-9, atau tanda minus.';
    }
    return null;
  }

  static String? validasiNama(String? value) {
    final nama = (value ?? '').trim();
    if (nama.isEmpty) return 'Nama alat wajib diisi.';
    if (utf8.encode(nama).length > 100) return 'Nama maksimal 100 byte UTF-8.';
    return null;
  }

  static String? validasiDeskripsi(String? value) {
    if (utf8.encode((value ?? '').trim()).length > 500) {
      return 'Deskripsi maksimal 500 byte UTF-8.';
    }
    return null;
  }

  Future<String> buatDataTambahAlat({
    required String pengirim,
    required String kode,
    required String nama,
    required String deskripsi,
  }) async {
    final kesalahan =
        validasiKode(kode) ??
        validasiNama(nama) ??
        validasiDeskripsi(deskripsi);
    if (kesalahan != null) throw StateError(kesalahan);
    final admin = await ambilAdmin();
    if (pengirim.toLowerCase() != admin.toLowerCase()) {
      throw StateError('Hanya wallet admin yang boleh menambah alat.');
    }
    final contract = await _ambilKontrak();
    final daftar = await _client
        .call(
          contract: contract,
          function: contract.function('lihatDaftarAlat'),
          params: [],
        )
        .timeout(const Duration(seconds: 20));
    if ((daftar.first as List).contains(kode.trim())) {
      throw StateError('Kode alat sudah digunakan. Pilih kode lain.');
    }
    final bytes = contract.function('tambahAlat').encodeCall([
      kode.trim(),
      nama.trim(),
      deskripsi.trim(),
    ]);
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<String> buatDataUbahAlat({
    required String pengirim,
    required String kode,
    required String nama,
    required String deskripsi,
  }) async {
    final error =
        validasiKode(kode) ??
        validasiNama(nama) ??
        validasiDeskripsi(deskripsi);
    if (error != null) throw StateError(error);
    if ((await ambilAdmin()).toLowerCase() != pengirim.toLowerCase()) {
      throw StateError('Hanya admin yang boleh mengubah alat.');
    }
    if (await ambilArsip(kode)) {
      throw StateError('Alat arsip tidak dapat diubah.');
    }
    final contract = await _ambilKontrak();
    final bytes = contract.function('ubahAlat').encodeCall([
      kode,
      nama.trim(),
      deskripsi.trim(),
    ]);
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<bool> ambilArsip(String kode) async {
    final contract = await _ambilKontrak();
    final result = await _client
        .call(
          contract: contract,
          function: contract.function('apakahDiarsipkan'),
          params: [kode],
        )
        .timeout(const Duration(seconds: 20));
    return result.first as bool;
  }

  Future<String> buatDataArsipAlat({
    required String pengirim,
    required String kode,
  }) async {
    final error = validasiKode(kode);
    if (error != null) throw StateError(error);
    if ((await ambilAdmin()).toLowerCase() != pengirim.toLowerCase()) {
      throw StateError('Hanya admin yang boleh mengarsipkan alat.');
    }
    if (await ambilArsip(kode)) throw StateError('Alat sudah diarsipkan.');
    if (!await ambilStatus(kode)) {
      throw StateError('Kembalikan alat terlebih dahulu.');
    }
    final contract = await _ambilKontrak();
    final bytes = contract.function('arsipkanAlat').encodeCall([kode]);
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<bool> ambilStatus(String kode) async {
    final contract = await _ambilKontrak();

    final hasil = await _client
        .call(
          contract: contract,
          function: contract.function('lihatStatus'),
          params: [kode],
        )
        .timeout(const Duration(seconds: 20));

    return hasil.first as bool;
  }

  Future<List<Alat>> ambilDaftarAlat() async {
    await _cekJaringan();

    final contract = await _ambilKontrak();

    final hasil = await _client
        .call(
          contract: contract,
          function: contract.function('lihatDaftarAlat'),
          params: [],
        )
        .timeout(const Duration(seconds: 20));

    final daftarKode = List<String>.from(hasil.first as List);

    return Future.wait(daftarKode.map(ambilAlat));
  }

  Future<List<RiwayatPeminjaman>> ambilRiwayat(String kode) async {
    await _cekJaringan();

    final contract = await _ambilKontrak();

    final hasil = await _client
        .call(
          contract: contract,
          function: contract.function('lihatRiwayat'),
          params: [kode],
        )
        .timeout(const Duration(seconds: 20));

    final data = hasil.first as List;

    return data
        .map((item) {
          final baris = item as List;
          final alamat = baris[0] as EthereumAddress;
          final pinjam = baris[1] as BigInt;
          final kembali = baris[2] as BigInt;

          return RiwayatPeminjaman(
            peminjam: alamat.with0x,
            waktuPinjam: DateTime.fromMillisecondsSinceEpoch(
              pinjam.toInt() * 1000,
              isUtc: true,
            ),
            waktuKembali: kembali == BigInt.zero
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    kembali.toInt() * 1000,
                    isUtc: true,
                  ),
          );
        })
        .toList()
        .reversed
        .toList();
  }

  Future<String> buatDataTransaksi({
    required String kode,
    required String peminjam,
    required bool kembalikan,
  }) async {
    await _cekJaringan();

    if (await ambilArsip(kode)) throw StateError('Alat sudah diarsipkan.');
    final tersedia = await ambilStatus(kode);

    if (kembalikan) {
      if (tersedia) {
        throw StateError('Alat sudah tersedia.');
      }

      final riwayat = await ambilRiwayat(kode);

      if (riwayat.isEmpty ||
          riwayat.first.peminjam.toLowerCase() != peminjam.toLowerCase()) {
        throw StateError(
          'Hanya wallet peminjam yang dapat mengembalikan alat.',
        );
      }
    } else if (!tersedia) {
      throw StateError('Alat sedang dipinjam.');
    }

    final contract = await _ambilKontrak();
    final fungsi = contract.function(
      kembalikan ? 'kembalikanAlat' : 'pinjamAlat',
    );

    final bytes = fungsi.encodeCall([kode]);

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '0x$hex';
  }

  // null: belum dikonfirmasi, true: berhasil, false: gagal.
  Future<bool?> cekTransaksi(String hash) async {
    final receipt = await _client
        .getTransactionReceipt(hash)
        .timeout(const Duration(seconds: 20));

    if (receipt == null) return null;

    if (receipt.status == null) {
      throw StateError('Status transaksi belum dapat dibaca.');
    }

    return receipt.status!;
  }

  static String pesanErrorAman(Object error) {
    var pesan = error.toString();
    final rpc = BlockchainConfig.rpcUrl;

    if (rpc.isNotEmpty) {
      pesan = pesan.replaceAll(rpc, '[RPC URL]');
    }

    final uri = Uri.tryParse(rpc);

    if (uri != null && uri.pathSegments.isNotEmpty) {
      final key = uri.pathSegments.last;

      if (key.isNotEmpty) {
        pesan = pesan.replaceAll(key, '[API KEY]');
      }
    }

    return pesan;
  }

  void dispose() {
    _client.dispose();
  }
}
