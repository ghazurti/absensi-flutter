import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  final ApiService _api = ApiService();

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> checkLogin() async {
    final token = await _api.getToken();
    if (token != null) {
      try {
        final response = await _api.getMe();
        _user = UserModel.fromJson(response.data);
        _isLoggedIn = true;
        await _saveUserCache(_user!);
      } catch (e) {
        final statusCode = _getStatusCode(e);
        if (statusCode == 401) {
          // Coba perbarui token otomatis agar pengguna tidak logout sendiri
          try {
            final refreshRes = await _api.refreshToken();
            final newToken = refreshRes.data['access_token'];
            if (newToken != null) {
              await _api.saveToken(newToken.toString());
              final meRes = await _api.getMe();
              _user = UserModel.fromJson(meRes.data);
              _isLoggedIn = true;
              await _saveUserCache(_user!);
            } else {
              await _api.clearToken();
              await _clearUserCache();
            }
          } catch (refreshErr) {
            final refreshStatus = _getStatusCode(refreshErr);
            if (refreshStatus == 401 || refreshStatus == 403) {
              await _api.clearToken();
              await _clearUserCache();
            } else {
              final cached = await _loadUserCache();
              if (cached != null) {
                _user = cached;
                _isLoggedIn = true;
              }
            }
          }
        } else if (statusCode == 403) {
          // Perangkat tidak cocok / diblokir admin
          await _api.clearToken();
          await _clearUserCache();
        } else {
          // Network error / server down — pakai data cache supaya tetap login
          final cached = await _loadUserCache();
          if (cached != null) {
            _user = cached;
            _isLoggedIn = true;
          }
        }
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await _api.login(email, password);
      final token = response.data['access_token'];
      await _api.saveToken(token);
      _user = UserModel.fromJson(response.data['user']);
      await _saveUserCache(_user!);
      _isLoggedIn = true;
      notifyListeners();
      return null;
    } catch (e) {
      return _parseError(e);
    }
  }

  Future<void> refreshUser() async {
    try {
      final response = await _api.getMe();
      _user = UserModel.fromJson(response.data);
      await _saveUserCache(_user!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await _api.clearToken();
    await _clearUserCache();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> _saveUserCache(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(user.toJson()));
  }

  Future<UserModel?> _loadUserCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_user');
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearUserCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user');
  }

  int? _getStatusCode(dynamic e) {
    try {
      if (e.runtimeType.toString().contains('DioException')) {
        return (e as dynamic).response?.statusCode as int?;
      }
    } catch (_) {}
    return null;
  }

  String _parseError(dynamic e) {
    if (e.runtimeType.toString().contains('DioException')) {
      final response = (e as dynamic).response;
      if (response != null) {
        final data = response.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
        return 'Terjadi kesalahan (${response.statusCode})';
      }
    }
    return 'Tidak dapat terhubung ke server';
  }
}
