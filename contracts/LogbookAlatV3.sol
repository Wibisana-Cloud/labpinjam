// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Logbook alat dengan arsip permanen; riwayat tetap dapat dibaca.
contract LogbookAlatV3 {
    address public immutable admin;
    struct Alat { string kode; string nama; string deskripsi; bool terdaftar; }
    struct Peminjaman { address peminjam; uint256 waktuPinjam; uint256 waktuKembali; }
    string[] private daftarKode;
    mapping(string => Alat) private dataAlat;
    mapping(string => Peminjaman[]) private riwayat;
    mapping(string => bool) private arsip;

    event AlatDitambahkan(string kode, string nama, address indexed petugas);
    event AlatDipinjam(string kode, address indexed peminjam);
    event AlatDikembalikan(string kode, address indexed peminjam);
    event AlatDiarsipkan(string kode, address indexed petugas);
    event AlatDiubah(string kode, string nama, address indexed petugas);

    modifier hanyaAdmin() {
        require(msg.sender == admin, "Hanya admin yang boleh mengelola alat");
        _;
    }
    modifier alatTerdaftar(string memory kode) {
        require(dataAlat[kode].terdaftar, "Kode alat tidak terdaftar");
        _;
    }
    constructor() { admin = msg.sender; }

    function tambahAlat(string calldata kode, string calldata nama, string calldata deskripsi) external hanyaAdmin {
        bytes memory karakter = bytes(kode);
        require(karakter.length > 0 && karakter.length <= 32, "Kode wajib 1-32 byte");
        require(bytes(nama).length > 0 && bytes(nama).length <= 100, "Nama wajib 1-100 byte");
        require(bytes(deskripsi).length <= 500, "Deskripsi maksimal 500 byte");
        for (uint256 i; i < karakter.length; i++) {
            bytes1 c = karakter[i];
            require((c >= 0x41 && c <= 0x5A) || (c >= 0x30 && c <= 0x39) || c == 0x2D,
                "Kode hanya boleh A-Z, 0-9, dan -");
        }
        require(!dataAlat[kode].terdaftar, "Kode alat sudah digunakan");
        dataAlat[kode] = Alat(kode, nama, deskripsi, true);
        daftarKode.push(kode);
        emit AlatDitambahkan(kode, nama, msg.sender);
    }

    function ubahAlat(string calldata kode, string calldata nama, string calldata deskripsi)
        external hanyaAdmin alatTerdaftar(kode) {
        require(!arsip[kode], "Alat sudah diarsipkan");
        require(bytes(nama).length > 0 && bytes(nama).length <= 100, "Nama wajib 1-100 byte");
        require(bytes(deskripsi).length <= 500, "Deskripsi maksimal 500 byte");
        dataAlat[kode].nama = nama;
        dataAlat[kode].deskripsi = deskripsi;
        emit AlatDiubah(kode, nama, msg.sender);
    }

    // Jumlah dan daftar mencakup arsip, agar catatan historis tetap dapat ditemukan.
    function jumlahAlat() external view returns (uint256) { return daftarKode.length; }
    function lihatDaftarAlat() external view returns (string[] memory) { return daftarKode; }
    function apakahDiarsipkan(string calldata kode) external view alatTerdaftar(kode) returns (bool) { return arsip[kode]; }
    function ambilAlat(string calldata kode) external view alatTerdaftar(kode)
        returns (string memory nama, string memory deskripsi, bool tersedia) {
        Alat storage alat = dataAlat[kode];
        return (alat.nama, alat.deskripsi, lihatStatus(kode));
    }
    function lihatStatus(string memory kode) public view alatTerdaftar(kode) returns (bool tersedia) {
        Peminjaman[] storage data = riwayat[kode];
        return !arsip[kode] && (data.length == 0 || data[data.length - 1].waktuKembali != 0);
    }
    function arsipkanAlat(string calldata kode) external hanyaAdmin alatTerdaftar(kode) {
        require(!arsip[kode], "Alat sudah diarsipkan");
        require(lihatStatus(kode), "Alat sedang dipinjam");
        arsip[kode] = true;
        emit AlatDiarsipkan(kode, msg.sender);
    }
    function pinjamAlat(string calldata kode) external alatTerdaftar(kode) {
        require(!arsip[kode], "Alat sudah diarsipkan");
        require(lihatStatus(kode), "Alat sedang dipinjam");
        riwayat[kode].push(Peminjaman(msg.sender, block.timestamp, 0));
        emit AlatDipinjam(kode, msg.sender);
    }
    function kembalikanAlat(string calldata kode) external alatTerdaftar(kode) {
        Peminjaman[] storage data = riwayat[kode];
        require(data.length > 0 && data[data.length - 1].waktuKembali == 0, "Tidak ada pinjaman aktif");
        Peminjaman storage aktif = data[data.length - 1];
        require(aktif.peminjam == msg.sender, "Hanya peminjam yang dapat mengembalikan");
        aktif.waktuKembali = block.timestamp;
        emit AlatDikembalikan(kode, msg.sender);
    }
    function lihatRiwayat(string calldata kode) external view alatTerdaftar(kode) returns (Peminjaman[] memory) {
        return riwayat[kode];
    }
}
