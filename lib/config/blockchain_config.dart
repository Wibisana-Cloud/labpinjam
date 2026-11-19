class BlockchainConfig {
  static void validasi({bool wallet = false}) {
    final uri = Uri.tryParse(rpcUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !['https', 'http'].contains(uri.scheme) ||
        rpcUrl.contains('ISI_')) {
      throw StateError(
        'RPC_URL belum diisi dengan benar. Jalankan profil LabPinjam (lokal) di VS Code atau gunakan --dart-define-from-file=config.local.json.',
      );
    }
    if (wallet && !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(reownProjectId)) {
      throw StateError(
        'REOWN_PROJECT_ID belum diisi dengan benar. Periksa config.local.json lalu hentikan dan jalankan ulang aplikasi.',
      );
    }
  }

  static const String rpcUrl = String.fromEnvironment('RPC_URL');
  static const String contractAddress = String.fromEnvironment(
    'CONTRACT_ADDRESS',
    defaultValue: '0x18C597a50cA4A1F4b4c720d2D542C3e09D44f858',
  );
  static const int chainId = 11155111;
  static const String abiAssetPath = 'assets/logbook_alat_abi.json';
  static const String reownProjectId = String.fromEnvironment(
    'REOWN_PROJECT_ID',
  );
}

