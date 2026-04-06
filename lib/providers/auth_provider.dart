import 'package:flutter/material.dart';
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
      } catch (_) {
        await _api.clearToken();
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
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await _api.clearToken();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    if (e.runtimeType.toString().contains('DioException')) {
      final response = (e as dynamic).response;
      if (response != null) {
        return response.data['message'] ?? 'Terjadi kesalahan';
      }
    }
    return 'Tidak dapat terhubung ke server';
  }
}
