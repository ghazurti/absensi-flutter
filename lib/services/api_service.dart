import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  Future<Response> login(String email, String password) {
    return _dio.post('/login', data: {'email': email, 'password': password});
  }

  Future<Response> logout() {
    return _dio.post('/logout');
  }

  Future<Response> getMe() {
    return _dio.get('/me');
  }

  Future<Response> getDashboard() {
    return _dio.get('/dashboard');
  }

  // Shift
  Future<Response> getShifts({int? bulan, int? tahun}) {
    return _dio.get('/shifts', queryParameters: {
      if (bulan != null) 'bulan': bulan,
      if (tahun != null) 'tahun': tahun,
    });
  }

  Future<Response> createShift(Map<String, dynamic> data) {
    return _dio.post('/shifts', data: data);
  }

  Future<Response> updateShift(int id, Map<String, dynamic> data) {
    return _dio.put('/shifts/$id', data: data);
  }

  Future<Response> deleteShift(int id) {
    return _dio.delete('/shifts/$id');
  }

  // Absensi
  Future<Response> getAbsensi({int? bulan, int? tahun}) {
    return _dio.get('/absensi', queryParameters: {
      if (bulan != null) 'bulan': bulan,
      if (tahun != null) 'tahun': tahun,
    });
  }

  Future<Response> checkIn(FormData formData) {
    return _dio.post('/absensi/check-in', data: formData);
  }

  Future<Response> checkOut(FormData formData) {
    return _dio.post('/absensi/check-out', data: formData);
  }

  Future<Response> getRekap({int? bulan, int? tahun}) {
    return _dio.get('/absensi/rekap', queryParameters: {
      if (bulan != null) 'bulan': bulan,
      if (tahun != null) 'tahun': tahun,
    });
  }

  // Izin
  Future<Response> getIzin() {
    return _dio.get('/izin');
  }

  Future<Response> createIzin(FormData formData) {
    return _dio.post('/izin', data: formData);
  }

  // Skor
  Future<Response> getSkor({int? bulan, int? tahun}) {
    return _dio.get('/skor', queryParameters: {
      if (bulan != null) 'bulan': bulan,
      if (tahun != null) 'tahun': tahun,
    });
  }

  // Profil
  Future<Response> updateProfile(FormData formData) {
    return _dio.post('/profile', data: formData);
  }

  Future<Response> gantiPassword({
    required String passwordLama,
    required String password,
    required String passwordConfirmation,
  }) {
    return _dio.post('/profile', data: {
      'password_lama': passwordLama,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'token');
  }
}
