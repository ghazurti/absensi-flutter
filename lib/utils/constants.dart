import 'package:flutter/material.dart';

class AppConstants {
  static const String baseUrl = 'https://absensi.rsudkotabaubau.com/api';

  // Koordinat RSUD Kota Baubau
  static const double rsudLatitude = -5.48299;
  static const double rsudLongitude = 122.59259;
  static const double radiusAbsensi = 300; // meter (sesuai konfigurasi backend)

  // Warna dari logo RSUD Kota Baubau
  static const Color primaryColor = Color(0xFF009540);   // hijau logo
  static const Color secondaryColor = Color(0xFFF5C200); // kuning/emas logo
  static const Color primaryDark = Color(0xFF006B2D);    // hijau gelap
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF57F17);
  static const Color errorColor = Color(0xFFC62828);

  static const String logoPath = 'assets/images/logo-rsud-baubau.png';
}
