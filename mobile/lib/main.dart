import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/network/dio_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  var customBaseUrl = prefs.getString('custom_base_url');
  if (customBaseUrl != null && customBaseUrl.isNotEmpty) {
    if (customBaseUrl.contains("localhost")) {
      customBaseUrl = customBaseUrl.replaceAll("localhost", "127.0.0.1");
      await prefs.setString('custom_base_url', customBaseUrl);
    }
    DioClient.setBaseUrl(customBaseUrl);
  }

  runApp(
    const ProviderScope(
      child: LocalMateApp(),
    ),
  );
}

class LocalMateApp extends StatelessWidget {
  const LocalMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LocalMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
