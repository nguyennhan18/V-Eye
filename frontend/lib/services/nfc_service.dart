import 'package:nfc_manager/nfc_manager.dart';
import 'package:flutter/foundation.dart';

class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  bool _isAvailable = false;

  Future<void> init() async {
    try {
      _isAvailable = await NfcManager.instance.checkAvailability() ==
          NfcAvailability.enabled;
    } catch (e) {
      _isAvailable = false;
    }
  }

  /// Bắt đầu lắng nghe NFC, khi có thẻ NFC sẽ gọi hàm callback [onDiscoveredCallback].
  Future<void> startListening(Function() onDiscoveredCallback) async {
    if (!_isAvailable) {
      if (kDebugMode) {
        print("NFC is not available on this device.");
      }
      return;
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          // Chỉ cần chạm thẻ NFC bất kỳ là kích hoạt luồng dò tranh
          onDiscoveredCallback();
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error starting NFC session: $e");
      }
    }
  }

  Future<void> stopListening() async {
    if (_isAvailable) {
      try {
        await NfcManager.instance.stopSession();
      } catch (e) {
        if (kDebugMode) print("Error stopping NFC: $e");
      }
    }
  }
}
