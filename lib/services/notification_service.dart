import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _androidCheckIn = AndroidNotificationDetails(
    'checkin_channel',
    'Pengingat Check-In',
    channelDescription: 'Notifikasi pengingat check-in absensi',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const _androidCheckOut = AndroidNotificationDetails(
    'checkout_channel',
    'Pengingat Check-Out',
    channelDescription: 'Notifikasi pengingat check-out absensi',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Makassar')); // WITA

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Otomatis set notif berdasarkan data shift hari ini.
  /// Dipanggil setiap kali app dibuka.
  Future<void> updateDariShift({
    required String jamMasuk,
    required String jamKeluar,
    required String jenisShift,
  }) async {
    await requestPermission();

    final masuk = _parseJam(jamMasuk);
    final keluar = _parseJam(jamKeluar);

    // Notif check-in = 30 menit sebelum jam masuk
    final notifMasukJam = masuk[0];
    final notifMasukMenit = masuk[1];
    final masukDikurangi = _kurangi30Menit(notifMasukJam, notifMasukMenit);

    // Notif check-out = 30 menit sebelum jam keluar
    final notifKeluarJam = keluar[0];
    final notifKeluarMenit = keluar[1];
    final keluarDikurangi = _kurangi30Menit(notifKeluarJam, notifKeluarMenit);

    // Cek apakah shift malam (jam keluar < jam masuk = melewati tengah malam)
    final isMalam = keluar[0] < masuk[0] ||
        (keluar[0] == masuk[0] && keluar[1] < masuk[1]);

    await _plugin.cancel(1);
    await _plugin.cancel(2);

    // Notif check-in — hari ini
    await _plugin.zonedSchedule(
      1,
      'Pengingat Check-In ${_labelShift(jenisShift)}',
      'Shift ${_labelShift(jenisShift)} mulai jam $jamMasuk. Jangan terlambat!',
      _jadwalHariIni(masukDikurangi[0], masukDikurangi[1]),
      NotificationDetails(
        android: _androidCheckIn,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Notif check-out — hari ini atau besok (shift malam)
    await _plugin.zonedSchedule(
      2,
      'Pengingat Check-Out ${_labelShift(jenisShift)}',
      'Shift selesai jam $jamKeluar. Jangan lupa check-out!',
      isMalam
          ? _jadwalBesok(keluarDikurangi[0], keluarDikurangi[1])
          : _jadwalHariIni(keluarDikurangi[0], keluarDikurangi[1]),
      NotificationDetails(
        android: _androidCheckOut,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Gunakan jam default jika tidak ada shift hari ini
  Future<void> setDefault() async {
    await requestPermission();
    await jadwalkanPengingatCheckIn(jam: 7, menit: 30);
    await jadwalkanPengingatCheckOut(jam: 16, menit: 30);
  }

  Future<void> jadwalkanPengingatCheckIn({int jam = 7, int menit = 30}) async {
    await _plugin.cancel(1);
    await _plugin.zonedSchedule(
      1,
      'Pengingat Absensi',
      'Jangan lupa check-in hari ini!',
      _jadwalHariIni(jam, menit),
      NotificationDetails(
        android: _androidCheckIn,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> jadwalkanPengingatCheckOut({int jam = 16, int menit = 30}) async {
    await _plugin.cancel(2);
    await _plugin.zonedSchedule(
      2,
      'Pengingat Absensi',
      'Jangan lupa check-out sebelum pulang!',
      _jadwalHariIni(jam, menit),
      NotificationDetails(
        android: _androidCheckOut,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> batalkanSemua() async => await _plugin.cancelAll();
  Future<void> batalkanCheckIn() async => await _plugin.cancel(1);
  Future<void> batalkanCheckOut() async => await _plugin.cancel(2);

  // ─── Helpers ────────────────────────────────────────────────────────────────

  List<int> _parseJam(String jam) {
    // Format: "HH:mm" atau "HH:mm:ss"
    final parts = jam.split(':');
    return [int.parse(parts[0]), int.parse(parts[1])];
  }

  List<int> _kurangi30Menit(int jam, int menit) {
    final total = jam * 60 + menit - 30;
    final totalPositif = total < 0 ? total + 1440 : total; // wrap ke hari sebelumnya
    return [totalPositif ~/ 60, totalPositif % 60];
  }

  String _labelShift(String jenis) {
    switch (jenis) {
      case 'pagi': return 'Pagi';
      case 'siang': return 'Siang';
      case 'malam': return 'Malam';
      default: return jenis;
    }
  }

  tz.TZDateTime _jadwalHariIni(int jam, int menit) {
    final now = tz.TZDateTime.now(tz.local);
    var jadwal = tz.TZDateTime(tz.local, now.year, now.month, now.day, jam, menit);
    // Kalau sudah lewat, set ke besok
    if (jadwal.isBefore(now)) {
      jadwal = jadwal.add(const Duration(days: 1));
    }
    return jadwal;
  }

  tz.TZDateTime _jadwalBesok(int jam, int menit) {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, jam, menit);
  }
}
