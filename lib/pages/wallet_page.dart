import '../ui/lab_ui.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../config/blockchain_config.dart';
import '../services/blockchain_service.dart';
import 'transaksi_alat_panel.dart';
import 'tambah_alat_panel.dart';
import 'arsip_alat_panel.dart';
import 'ubah_alat_panel.dart';
import '../services/wallet_pilihan.dart';

class WalletPage extends StatefulWidget {
  final String? kode;
  final bool kembalikan;

  const WalletPage({super.key, this.kode, this.kembalikan = false});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  ReownAppKitModal? _appKit;
  final BlockchainService _service = BlockchainService();
  String? _admin;
  String? _adminError;
  bool _memuatAdmin = false;
  bool _transaksiAdminAktif = false;
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _siapkanWallet();
      }
    });
  }

  Future<void> _siapkanWallet() async {
    try {
      BlockchainConfig.validasi(wallet: true);
      final namespaces = ReownAppKitModalNetworks.getAllSupportedNamespaces()
          .toList();

      for (final namespace in namespaces) {
        ReownAppKitModalNetworks.removeSupportedNetworks(namespace);
      }

      ReownAppKitModalNetworks.addSupportedNetworks('eip155', [
        ReownAppKitModalNetworkInfo(
          name: 'Ethereum Sepolia',
          chainId: '11155111',
          currency: 'ETH',
          rpcUrl: BlockchainConfig.rpcUrl,
          explorerUrl: 'https://sepolia.etherscan.io',
          isTestNetwork: true,
        ),
      ]);

      final appKit = ReownAppKitModal(
        context: context,
        projectId: BlockchainConfig.reownProjectId,
        metadata: const PairingMetadata(
          name: 'LabPinjam',
          description: 'Peminjaman alat laboratorium di Ethereum Sepolia',
          // Metadata sementara selama pengembangan.
          url: 'https://example.com',
          icons: [],
          redirect: Redirect(native: 'labpinjam://', linkMode: false),
        ),
        featuresConfig: FeaturesConfig(socials: [], showMainWallets: true),
        disconnectOnDispose: false,
      );

      _appKit = appKit;

      await appKit.init();

      if (!mounted) return;

      final sepolia = ReownAppKitModalNetworks.getNetworkInfo(
        'eip155',
        '11155111',
      );

      if (sepolia == null) {
        throw StateError('Ethereum Sepolia tidak ditemukan.');
      }

      await appKit.selectChain(sepolia);

      if (!mounted) return;

      appKit.addListener(_perbaruiTampilan);
      _perbaruiTampilan();

      setState(() => _memuat = false);
      if (widget.kode == null) await _muatAdmin();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _memuat = false;
        _error = BlockchainService.pesanErrorAman(
          error is ReownAppKitModalException ? error.message : error,
        );
      });
    }
  }

  Future<void> _muatAdmin() async {
    if (!mounted || _memuatAdmin) return;
    setState(() {
      _memuatAdmin = true;
      _adminError = null;
    });
    try {
      final admin = await _service.ambilAdmin();
      if (mounted) setState(() => _admin = admin);
    } catch (e) {
      if (mounted) {
        setState(() => _adminError = BlockchainService.pesanErrorAman(e));
      }
    } finally {
      if (mounted) setState(() => _memuatAdmin = false);
    }
  }

  void _perbaruiTampilan() {
    WalletPilihan.alamat.value = _appKit?.isConnected == true
        ? _appKit?.session?.getAddress('eip155')
        : null;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    final appKit = _appKit;

    if (appKit != null) {
      appKit.removeListener(_perbaruiTampilan);
      appKit.dispose();
    }

    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_transaksiAdminAktif,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.kode == null ? 'Wallet & admin' : 'Konfirmasi transaksi',
          ),
        ),
        body: _buatIsiHalaman(),
      ),
    );
  }

  Widget _buatIsiHalaman() {
    if (_memuat) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 16),
              const Text('Gagal menyiapkan wallet'),
              const SizedBox(height: 12),
              SelectableText(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final appKit = _appKit;

    if (appKit == null) {
      return const Center(child: Text('Wallet belum siap.'));
    }

    final terhubung = appKit.isConnected;
    final jaringan = appKit.selectedChain?.name ?? 'Belum dipilih';
    final alamat = appKit.session?.getAddress('eip155');

    final adminAktif =
        terhubung &&
        _admin != null &&
        alamat?.toLowerCase() == _admin!.toLowerCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF075E56), Color(0xFF108D7D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 34,
              ),
              const SizedBox(height: 22),
              Text(
                terhubung ? 'Wallet terhubung' : 'Mulai dengan wallet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                terhubung
                    ? 'Siap untuk aktivitas laboratorium.'
                    : 'Hubungkan MetaMask untuk meminjam dan mengembalikan alat.',
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Jaringan aplikasi: $jaringan',
                style: const TextStyle(color: Color(0xFFC5EEE4), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LabSectionTitle(
                  icon: Icons.person_outline,
                  title: 'Akun saya',
                  subtitle: 'Kelola koneksi dan lihat saldo wallet.',
                ),
                if (terhubung && alamat != null) ...[
                  const SizedBox(height: 18),
                  AddressTile(address: alamat),
                ],
                const SizedBox(height: 18),
                IgnorePointer(
                  ignoring: _transaksiAdminAktif,
                  child: AppKitModalConnectButton(appKit: appKit),
                ),
                if (terhubung) ...[
                  const SizedBox(height: 12),
                  IgnorePointer(
                    ignoring: _transaksiAdminAktif,
                    child: AppKitModalAccountButton(appKitModal: appKit),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.kode == null && (terhubung || _transaksiAdminAktif)) ...[
          const SizedBox(height: 20),
          if (_memuatAdmin)
            const LabNotice(text: 'Memeriksa peran akun...', loading: true)
          else if (_adminError != null) ...[
            LabNotice(
              text: 'Peran akun belum dapat dibaca.\n$_adminError',
              error: true,
            ),
            TextButton(
              onPressed: _muatAdmin,
              child: const Text('Periksa kembali'),
            ),
          ] else if (adminAktif || _transaksiAdminAktif) ...[
            const LabSectionTitle(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Ruang admin',
              subtitle: 'Tambah, edit, atau arsipkan perangkat laboratorium.',
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _transaksiAdminAktif
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ArsipAlatPage(appKit: appKit),
                      ),
                    ),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Arsipkan alat'),
            ),
            OutlinedButton.icon(
              onPressed: _transaksiAdminAktif
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => UbahAlatPage(appKit: appKit),
                      ),
                    ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit alat'),
            ),
            TambahAlatPanel(
              appKit: appKit,
              onBusyChanged: (value) {
                if (mounted) setState(() => _transaksiAdminAktif = value);
              },
            ),
          ] else
            const LabNotice(
              text:
                  'Akun pengguna. Pilih alat di beranda untuk '
                  'meminjam. Penambahan alat dikelola oleh admin.',
            ),
        ],
        if (widget.kode != null) ...[
          const SizedBox(height: 20),
          TransaksiAlatPanel(
            appKit: appKit,
            kode: widget.kode!,
            kembalikan: widget.kembalikan,
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Persetujuan transaksi dilakukan di MetaMask.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF667773), fontSize: 12),
        ),
      ],
    );
  }
}
