import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  final _dio = DioClient().dio;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = "Please enter a phone number");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint("Attempting OTP send. Base URL: ${DioClient.baseUrl}");
      final response = await _dio.post("/auth/otp/send", data: {"phone_number": phone});
      if (response.statusCode == 200) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent successfully!")),
        );
      }
    } catch (e) {
      debugPrint("OTP Send Error: $e");
      setState(() => _errorMessage = "Failed to send OTP. Try again. Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorMessage = "Please enter the OTP code");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post("/auth/otp/verify", data: {
        "phone_number": phone,
        "code": otp,
      });

      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        final isNewUser = response.data['is_new_user'] ?? false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);

        if (mounted) {
          if (isNewUser) {
            context.go('/profile/create');
          } else {
            // Navigate back or to home screen using GoRouter
            if (context.canPop()) {
              context.pop(true);
            } else {
              context.go('/');
            }
          }
        }
      }
    } catch (e) {
      debugPrint("OTP Verify Error: $e");
      setState(() => _errorMessage = "Invalid OTP code. Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post("/auth/google", data: {
        "id_token": "mock_google_id_token",
        "name": "Google Resident User",
        "email": "resident@gmail.com",
      });

      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        final isNewUser = response.data['is_new_user'] ?? false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);

        if (mounted) {
          if (isNewUser) {
            context.go('/profile/create');
          } else {
            if (context.canPop()) {
              context.pop(true);
            } else {
              context.go('/');
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Google Login Error: $e");
      setState(() => _errorMessage = "Google authentication failed. Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showServerSettingsDialog() {
    final TextEditingController urlController = TextEditingController(text: DioClient.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Server Settings"),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: "API Base URL",
            hintText: "http://192.168.1.100:8000/api/v1",
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () async {
              final newUrl = urlController.text.trim();
              if (newUrl.isEmpty || (!newUrl.startsWith("http://") && !newUrl.startsWith("https://"))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid URL starting with http:// or https://")),
                );
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('custom_base_url', newUrl);
              DioClient.setBaseUrl(newUrl);

              navigator.pop();
              messenger.showSnackBar(
                SnackBar(content: Text("Server base URL updated to: $newUrl")),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFFE11D48)),
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "LocalMate",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Discover trusted local services recommended by residents",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              if (!_otpSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                    labelText: "Mobile Number",
                    hintText: "+91 9999900000",
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Send OTP Code"),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                    labelText: "6-Digit OTP Code",
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Verify & Login"),
                ),
                TextButton(
                  onPressed: () => setState(() => _otpSent = false),
                  child: const Text("Change phone number"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
