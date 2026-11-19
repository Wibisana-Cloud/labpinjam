import 'package:flutter/foundation.dart';

// Filter context only, never a source of transaction authorization.
// Updated whenever the wallet screen receives connection/account changes.
class WalletPilihan {
  static final alamat = ValueNotifier<String?>(null);
}
