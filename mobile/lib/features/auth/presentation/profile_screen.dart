import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dio = DioClient().dio;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _errorMessage;

  // Edit Mode state
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  File? _pickedImageFile;
  String? _selectedAvatarUrl;

  final List<String> _predefinedAvatars = [
    "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
    "https://api.dicebear.com/7.x/avataaars/png?seed=Aneka",
    "https://api.dicebear.com/7.x/avataaars/png?seed=Adrian",
    "https://api.dicebear.com/7.x/avataaars/png?seed=Jack",
    "https://api.dicebear.com/7.x/avataaars/png?seed=Nala",
    "https://api.dicebear.com/7.x/avataaars/png?seed=Bella",
    "https://api.dicebear.com/7.x/avataaars/png?seed=Oliver",
    "https://api.dicebear.com/7.x/avataaars/png?seed=Luna",
  ];

  // Contributor reviews and auth tracking
  String? _currentUserId;
  bool _isLoggedIn = false;
  List<dynamic> _contributorReviews = [];
  bool _isLoadingReviews = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus().then((_) => _fetchProfile());
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    _isLoggedIn = token != null;
    if (_isLoggedIn) {
      try {
        final response = await _dio.get("/users/me");
        if (response.statusCode == 200) {
          setState(() {
            _currentUserId = response.data['id'];
          });
        }
      } catch (e) {
        debugPrint("Error fetching current user info: $e");
      }
    }
  }

  Future<void> _fetchContributorReviews(String userId) async {
    setState(() => _isLoadingReviews = true);
    try {
      final response = await _dio.get("/reviews/users/$userId");
      if (response.statusCode == 200) {
        setState(() {
          _contributorReviews = response.data;
        });
      }
    } catch (e) {
      debugPrint("Error fetching contributor reviews: $e");
    } finally {
      setState(() => _isLoadingReviews = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = widget.userId != null
          ? await _dio.get("/users/${widget.userId}")
          : await _dio.get("/users/me");
      if (response.statusCode == 200) {
        setState(() {
          _user = response.data;
          _isLoading = false;
        });
        if (_user != null && _user!['id'] != null) {
          await _fetchContributorReviews(_user!['id']);
        }
      } else {
        setState(() {
          _errorMessage = "Failed to load profile. Please try again.";
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      String msg = "Connection error. Make sure backend is running.";
      if (e.response != null && e.response?.data != null && e.response?.data is Map) {
        final detail = e.response?.data['detail'];
        if (detail != null) {
          msg = detail.toString();
        }
      }
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
      debugPrint("Error fetching profile: $e");
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
      context.go('/?refresh=${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _pickedImageFile = File(pickedFile.path);
          _selectedAvatarUrl = null;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackgroundColor : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24.0),
          height: MediaQuery.of(context).size.height * 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Select an Avatar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Choose from one of our impressive illustrations",
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _predefinedAvatars.length,
                  itemBuilder: (context, index) {
                    final avatarUrl = _predefinedAvatars[index];
                    final isSelected = _selectedAvatarUrl == avatarUrl;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatarUrl = avatarUrl;
                          _pickedImageFile = null;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(avatarUrl),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackgroundColor : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: SafeArea(
            child: Wrap(
              children: <Widget>[
                const Center(
                  child: Text(
                    "Profile Photo Options",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEEF2F6),
                    child: Icon(Icons.photo_camera_rounded, color: AppTheme.primaryColor),
                  ),
                  title: const Text('Take Photo (Camera)', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEEF2F6),
                    child: Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEEF2F6),
                    child: Icon(Icons.face_rounded, color: AppTheme.primaryColor),
                  ),
                  title: const Text('Choose from Avatars', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _showAvatarPicker();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    String? uploadedPhotoUrl;

    try {
      if (_pickedImageFile != null) {
        final filename = _pickedImageFile!.path.split('/').last;
        final formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(
            _pickedImageFile!.path,
            filename: filename,
          ),
        });

        final uploadResponse = await _dio.post(
          "/users/me/photo",
          data: formData,
        );

        if (uploadResponse.statusCode == 200) {
          uploadedPhotoUrl = uploadResponse.data['profile_photo_url'];
        } else {
          throw Exception("Failed to upload photo");
        }
      }

      final finalPhotoUrl = _selectedAvatarUrl ?? uploadedPhotoUrl ?? _user!['profile_photo_url'];

      final response = await _dio.put(
        "/users/me",
        data: {
          "name": name,
          "email": email.isNotEmpty ? email : null,
          if (finalPhotoUrl != null) "profile_photo_url": finalPhotoUrl,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _user = response.data;
          _isEditing = false;
          _pickedImageFile = null;
          _selectedAvatarUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to update profile. Please try again.";
      });
      debugPrint("Error updating profile: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith("http")) return path;
    final rootHost = DioClient.baseUrl.replaceAll("/api/v1", "");
    return "$rootHost$path";
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

  void _addContributorReviewDialog() {
    if (!_isLoggedIn) {
      context.push('/login').then((_) => _checkLoginStatus().then((_) => _fetchProfile()));
      return;
    }

    double selectedRating = 5.0;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Review Contributor"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final ratingValue = index + 1.0;
                  return IconButton(
                    icon: Icon(
                      selectedRating >= ratingValue ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = ratingValue),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: "Add your feedback about this contributor..."),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Submit"),
              onPressed: () async {
                try {
                  await _dio.post("/reviews/users/${_user!['id']}", data: {
                    "rating": selectedRating.toInt(),
                    "comment": commentController.text.trim(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchProfile(); // reload profile to recalculate reputation
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error submitting contributor review.")),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openAdminPanel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSecret = prefs.getString('admin_secret');
    if (savedSecret == "localmate_admin_secret_key" && mounted) {
      context.push('/admin');
      return;
    }

    if (!mounted) return;

    final TextEditingController secretController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin Authentication"),
        content: TextField(
          controller: secretController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Admin Secret Key",
            hintText: "Enter administrative credentials",
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Verify"),
            onPressed: () async {
              final key = secretController.text.trim();
              if (key == "localmate_admin_secret_key") {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('admin_secret', key);
                if (context.mounted) {
                  Navigator.pop(context); // close dialog
                  context.push('/admin');
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid admin credentials.")),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = widget.userId == null || widget.userId == _currentUserId;

    ImageProvider? imageProvider;
    if (_pickedImageFile != null) {
      imageProvider = FileImage(_pickedImageFile!);
    } else if (_selectedAvatarUrl != null) {
      imageProvider = NetworkImage(_selectedAvatarUrl!);
    } else if (_user != null && _user!['profile_photo_url'] != null && _user!['profile_photo_url'].isNotEmpty) {
      imageProvider = NetworkImage(_getFullImageUrl(_user!['profile_photo_url']));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? (_isEditing ? "Edit Profile" : "My Profile") : "Contributor Profile"),
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
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _fetchProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                        ),
                        if (isMe) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text("Log Out"),
                            onPressed: _logout,
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // User Info Header / Avatar Pick Row
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withAlpha(51),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(26),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        )
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: isDark ? AppTheme.cardDarkColor : Colors.grey.shade100,
                                      backgroundImage: imageProvider,
                                      child: (_pickedImageFile == null &&
                                              _selectedAvatarUrl == null &&
                                              (_user!['profile_photo_url'] == null || _user!['profile_photo_url'].isEmpty))
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
                                  if (isMe && _isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _showPhotoOptions,
                                        child: const CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppTheme.primaryColor,
                                          child: Icon(
                                            Icons.edit_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (!_isEditing) ...[
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
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Form Fields (Visible only in edit mode)
                        if (_isEditing) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              labelText: "Full Name (Required)",
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Name is required";
                              }
                              if (value.trim().length < 2) {
                                return "Name must be at least 2 characters";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _user!['phone_number'],
                            enabled: false, // Phone number NOT editable
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone_iphone_rounded),
                              labelText: "Mobile Number (Disabled)",
                              fillColor: isDark ? AppTheme.cardDarkColor.withAlpha(150) : Colors.grey.shade100,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                              labelText: "Email Address (Optional)",
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return "Please enter a valid email address";
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _pickedImageFile = null;
                                      _selectedAvatarUrl = null;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text("Cancel"),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveProfile,
                                  child: const Text("Save Changes"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Reputation Dashboard Card (Only in regular read-only mode)
                        if (!_isEditing && _user!['reputation'] != null) ...[
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

                        // Navigation Menus (Only in regular read-only mode)
                        if (!_isEditing) ...[
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.storefront_rounded, color: AppTheme.primaryColor),
                                  title: Text(isMe ? "My Recommendations" : "Recommendations"),
                                  subtitle: Text(isMe ? "Manage services you recommended" : "View services they recommended"),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(isMe ? '/my-listings' : '/my-listings?userId=${widget.userId}'),
                                ),
                                if (isMe) ...[
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.bookmark_outline_rounded, color: AppTheme.primaryColor),
                                    title: const Text("Saved Bookmarks"),
                                    subtitle: const Text("Quickly view pinned services"),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => context.push('/saved-listings'),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.security_rounded, color: AppTheme.primaryColor),
                                    title: const Text("Admin Panel"),
                                    subtitle: const Text("Manage system listings and users"),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: _openAdminPanel,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Contributor Reviews Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Contributor Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              if (!isMe)
                                TextButton.icon(
                                  icon: const Icon(Icons.rate_review_outlined),
                                  label: const Text("Write Review"),
                                  onPressed: _addContributorReviewDialog,
                                ),
                            ],
                          ),
                          const Divider(),
                          
                          if (_isLoadingReviews)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_contributorReviews.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(child: Text("No reviews yet. Share your experience!")),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _contributorReviews.length,
                              itemBuilder: (context, index) {
                                final rev = _contributorReviews[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(rev['author']?['name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const Spacer(),
                                          Row(
                                            children: List.generate(5, (starIdx) {
                                              return Icon(
                                                starIdx < rev['rating'] ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                                size: 16,
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                      if (rev['comment'] != null && rev['comment'].isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(rev['comment'], style: TextStyle(color: Colors.grey.shade700)),
                                      ],
                                      const Divider(height: 16),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 32),
                        ],

                        // Actions: Edit Profile (if isMe) / Logout (if isMe)
                        if (!_isEditing && isMe) ...[
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text("Edit Profile"),
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                                _nameController.text = _user!['name'] ?? '';
                                _emailController.text = _user!['email'] ?? '';
                                _pickedImageFile = null;
                                _selectedAvatarUrl = null;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
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
                      ],
                    ),
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
