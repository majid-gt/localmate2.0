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
      final response = await _dio.post("/auth/otp/send", data: {"phone_number": phone});
      if (response.statusCode == 200) {
        setState(() => _otpSent = true);
        final debugCode = response.data['debug_code'];
        // In local development, show the generated OTP code in a Snackbar for testing ease
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Test OTP: $debugCode (Use this to verify)")),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to send OTP. Try again.");
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
      setState(() => _errorMessage = "Invalid OTP code. Please check and try again.");
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
      setState(() => _errorMessage = "Google authentication failed.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.people_alt_rounded,
                size: 80,
                color: Color(0xFF6366F1),
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
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text("OR"),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.g_mobiledata, size: 28),
                onPressed: _isLoading ? null : _googleLogin,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: const Text("Sign in with Google"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
