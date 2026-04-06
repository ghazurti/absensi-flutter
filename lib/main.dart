import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Absensi RSUD Baubau',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1565C0),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthProvider>().checkLogin();
      _updateNotifikasiShift();
    });
  }

  Future<void> _updateNotifikasiShift() async {
    try {
      final token = await ApiService().getToken();
      if (token == null) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await ApiService().getShifts(
        bulan: DateTime.now().month,
        tahun: DateTime.now().year,
      );

      final shifts = res.data as List<dynamic>;
      final shiftHariIni = shifts.firstWhere(
        (s) => s['tanggal'].toString().startsWith(today),
        orElse: () => null,
      );

      final notif = NotificationService();
      if (shiftHariIni != null) {
        await notif.updateDariShift(
          jamMasuk: shiftHariIni['jam_masuk'],
          jamKeluar: shiftHariIni['jam_keluar'],
          jenisShift: shiftHariIni['jenis_shift'],
        );
      } else {
        // Tidak ada shift hari ini — batalkan notif
        await notif.batalkanSemua();
      }
    } catch (_) {
      // Gagal ambil shift — biarkan notif yang sudah ada
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isLoggedIn ? const DashboardScreen() : const LoginScreen();
      },
    );
  }
}
