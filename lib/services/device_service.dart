import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentity {
  final String deviceId;
  final String deviceName;

  const DeviceIdentity({
    required this.deviceId,
    required this.deviceName,
  });
}

class DeviceService {
  static const _channel = MethodChannel('id.go.rsudkotabaubau.absensi/device');
  static const _storage = FlutterSecureStorage();
  static const _fallbackKey = 'fallback_device_id';

  static DeviceIdentity? _cached;

  static Future<DeviceIdentity> getIdentity() async {
    if (_cached != null) return _cached!;

    String deviceId = '';
    String deviceName = 'Android';

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      if (result != null) {
        deviceId = (result['device_id'] ?? '').toString().trim();
        final name = (result['device_name'] ?? '').toString().trim();
        if (name.isNotEmpty) deviceName = name;
      }
    } catch (_) {}

    if (deviceId.isEmpty) {
      deviceId = await _storage.read(key: _fallbackKey) ?? '';
      if (deviceId.isEmpty) {
        final rand = Random.secure();
        final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
        deviceId = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await _storage.write(key: _fallbackKey, value: deviceId);
      }
    }

    _cached = DeviceIdentity(deviceId: deviceId, deviceName: deviceName);
    return _cached!;
  }
}
