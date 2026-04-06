import 'package:flutter/material.dart';

class AppConstants {
  static const String baseUrl = 'https://absensi.rsudkotabaubau.com/api';

  // Koordinat RSUD Kota Baubau
  static const double rsudLatitude = -5.48299;
  static const double rsudLongitude = 122.59259;
  static const double radiusAbsensi = 300; // meter (sesuai konfigurasi backend)

  static const Color primaryColor = Color(0xFF1565C0);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF57F17);
  static const Color errorColor = Color(0xFFC62828);
}
