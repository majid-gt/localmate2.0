import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _dio = DioClient().dio;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.get("/users/me");
      if (response.statusCode == 200) {
        setState(() {
          _user = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load profile. Please try again.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error. Make sure backend is running.";
        _isLoading = false;
      });
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged out successfully")),
      );
      context.go('/');
    }
  }

  LinearGradient _getReputationGradient(String level) {
    if (level.contains("Gold")) {
      return const LinearGradient(
        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (level.contains("Silver")) {
      return const LinearGradient(
        colors: [Color(0xFF94A3B8), Color(0xFF475569)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      // Bronze / Default
      return const LinearGradient(
        colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Color _getReputationBadgeColor(String level) {
    if (level.contains("Gold")) {
      return const Color(0xFFFEF3C7);
    } else if (level.contains("Silver")) {
      return const Color(0xFFF1F5F9);
    } else {
      return const Color(0xFFFFEDD5);
    }
  }

  Color _getReputationTextColor(String level) {
    if (level.contains("Gold")) {
      return const Color(0xFF92400E);
    } else if (level.contains("Silver")) {
      return const Color(0xFF1E293B);
    } else {
      return const Color(0xFF7C2D12);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchProfile,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // User Info Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: isDark ? AppTheme.cardDarkColor : Colors.grey.shade100,
                                backgroundImage: _user!['profile_photo_url'] != null
                                    ? NetworkImage(_user!['profile_photo_url'])
                                    : null,
                                child: _user!['profile_photo_url'] == null
                                    ? Text(
                                        (_user!['name'] ?? 'U').substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _user!['name'] ?? 'Resident User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _user!['phone_number'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            if (_user!['email'] != null && _user!['email'].isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _user!['email'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Reputation Dashboard Card
                      if (_user!['reputation'] != null) ...[
                        Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: _getReputationGradient(_user!['reputation']['reputation_level']),
                            ),
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "REPUTATION DASHBOARD",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getReputationBadgeColor(_user!['reputation']['reputation_level']),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _user!['reputation']['reputation_level'],
                                        style: TextStyle(
                                          color: _getReputationTextColor(_user!['reputation']['reputation_level']),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildRepMetric(
                                      label: "Total Points",
                                      value: "${_user!['reputation']['points']}",
                                      icon: Icons.offline_bolt_rounded,
                                    ),
                                    _buildRepMetric(
                                      label: "Listings",
                                      value: "${_user!['reputation']['total_listings']}",
                                      icon: Icons.storefront,
                                    ),
                                    _buildRepMetric(
                                      label: "Reviews Recv.",
                                      value: "${_user!['reputation']['total_reviews']}",
                                      icon: Icons.rate_review_outlined,
                                    ),
                                    _buildRepMetric(
                                      label: "Avg. Rating",
                                      value: "${_user!['reputation']['avg_rating']} ★",
                                      icon: Icons.star_rate_rounded,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Navigation Menus
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.storefront_rounded, color: AppTheme.primaryColor),
                              title: const Text("My Recommendations"),
                              subtitle: const Text("Manage services you recommended"),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/my-listings'),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.bookmark_outline_rounded, color: AppTheme.primaryColor),
                              title: const Text("Saved Bookmarks"),
                              subtitle: const Text("Quickly view pinned services"),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/saved-listings'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Logout Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text("Log Out", style: TextStyle(color: Colors.red)),
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRepMetric({required String label, required String value, required IconData icon}) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
