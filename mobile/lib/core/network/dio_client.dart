import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  final Dio dio;
  static String _baseUrl = kDebugMode
      ? "http://localhost:8000/api/v1"
      : "https://kcmkcmkcmkcmkcmkcmkcm.dpdns.org/api/v1";

  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  static String get baseUrl => _baseUrl;

  DioClient() : dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.baseUrl = _baseUrl;
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        // Handle global error codes here (e.g., redirect to login on 401)
        return handler.next(e);
      },
    ));
  }
}
