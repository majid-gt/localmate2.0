import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _dio = DioClient().dio;
  Map<String, dynamic>? _listing;
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isLoggedIn = false;
  String? _currentUserId;
  bool _showVerificationTile = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndFetchDetails();
  }

  Future<void> _checkLoginAndFetchDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    _isLoggedIn = token != null;
    
    await _fetchDetails();
    if (_isLoggedIn) {
      await _checkIfSaved();
      await _fetchCurrentUser();
    }
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final response = await _dio.get("/users/me");
      if (response.statusCode == 200) {
        setState(() {
          _currentUserId = response.data['id'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDetails() async {
    try {
      final response = await _dio.get("/listings/${widget.listingId}");
      if (response.statusCode == 200) {
        setState(() {
          _listing = response.data;
        });
      }
      
      final reviewsResp = await _dio.get("/reviews/listings/${widget.listingId}");
      if (reviewsResp.statusCode == 200) {
        setState(() {
          _reviews = reviewsResp.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final response = await _dio.get("/saved-listings/");
      if (response.statusCode == 200) {
        final List saved = response.data;
        final alreadySaved = saved.any((item) => item['id'] == widget.listingId);
        setState(() => _isSaved = alreadySaved);
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (!_isLoggedIn) {
      context.push('/login').then((_) => _checkLoginAndFetchDetails());
      return;
    }

    try {
      if (_isSaved) {
        await _dio.delete("/saved-listings/${widget.listingId}");
        setState(() => _isSaved = false);
      } else {
        await _dio.post("/saved-listings/${widget.listingId}");
        setState(() => _isSaved = true);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update bookmark status.")),
        );
      }
    }
  }

  void _addReviewDialog() {
    if (!_isLoggedIn) {
      context.push('/login').then((_) => _checkLoginAndFetchDetails());
      return;
    }

    double selectedRating = 5.0;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Write a Review"),
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
                decoration: const InputDecoration(hintText: "Add your comment here..."),
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
                  await _dio.post("/reviews/listings/${widget.listingId}", data: {
                    "rating": selectedRating.toInt(),
                    "comment": commentController.text.trim(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  _fetchDetails();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error submitting review.")),
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

  String _getFullImageUrl(String path) {
    if (path.startsWith("http")) return path;
    final rootHost = DioClient.baseUrl.replaceAll("/api/v1", "");
    return "$rootHost$path";
  }

  void _triggerVerificationTile() {
    final listing = _listing;
    if (listing == null) return;
    final contributor = listing['contributor'];
    if (contributor == null) return;
    final contributorId = contributor['id'] ?? listing['contributor_id'];
    
    // Don't show if the contributor is the current user
    if (_isLoggedIn && _currentUserId != null && contributorId == _currentUserId) {
      return;
    }
    
    setState(() {
      _showVerificationTile = true;
    });
  }

  void _showVerificationFormDialog() {
    if (!_isLoggedIn) {
      context.push('/login').then((_) => _checkLoginAndFetchDetails());
      return;
    }

    final listing = _listing;
    if (listing == null || listing['contributor'] == null) return;
    final contributorName = listing['contributor']['name'] ?? 'Contributor';
    final contributorId = listing['contributor']['id'] ?? listing['contributor_id'];

    double selectedRating = 5.0;
    int selectedSpecialPoints = 5; // Default to 5 points
    File? proofImage;
    final descriptionController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            Future<void> pickProofImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 80,
                );
                if (picked != null) {
                  setDialogState(() {
                    proofImage = File(picked.path);
                  });
                }
              } catch (e) {
                debugPrint("Error picking proof image: $e");
              }
            }

            void showPhotoSourceSelector() {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext sheetCtx) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_camera, color: Color(0xFFE11D48)),
                          title: const Text("Take Photo (Camera)"),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickProofImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library, color: Color(0xFFE11D48)),
                          title: const Text("Choose from Gallery"),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickProofImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Verify Service & Review $contributorName"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Rate this recommendation's accuracy:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starVal = index + 1.0;
                        return GestureDetector(
                          onTap: isSubmitting ? null : () {
                            setDialogState(() {
                              selectedRating = starVal;
                            });
                          },
                          child: Icon(
                            selectedRating >= starVal ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "How did you benefit from this service?",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: "E.g., I called the plumber and they arrived in 20 mins, resolved the leakage perfectly. Excellent service!",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Upload Proof of Utilization (Optional):",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (proofImage == null)
                      OutlinedButton.icon(
                        onPressed: isSubmitting ? null : showPhotoSourceSelector,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text("Upload Image (e.g. Receipt/Work photo)"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    else
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(proofImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                            onPressed: isSubmitting ? null : () {
                              setDialogState(() {
                                proofImage = null;
                              });
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      "Award Reputation Points to Contributor:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [0, 5, 10, 20].map((points) {
                        final isSelected = selectedSpecialPoints == points;
                        return ChoiceChip(
                          label: Text("+$points pts"),
                          selected: isSelected,
                          selectedColor: const Color(0xFFE11D48).withOpacity(0.15),
                          checkmarkColor: const Color(0xFFE11D48),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFFE11D48) : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                          onSelected: isSubmitting ? null : (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedSpecialPoints = points;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final desc = descriptionController.text.trim();
                    if (desc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please write a small description of your experience.")),
                      );
                      return;
                    }

                    setDialogState(() {
                      isSubmitting = true;
                    });

                    try {
                      String? uploadedImageUrl;

                      // 1. Upload proof image if provided
                      if (proofImage != null) {
                        final filename = proofImage!.path.split('/').last;
                        final formData = FormData.fromMap({
                          "file": await MultipartFile.fromFile(
                            proofImage!.path,
                            filename: filename,
                          ),
                        });

                        final uploadResponse = await _dio.post(
                          "/reviews/upload",
                          data: formData,
                        );

                        if (uploadResponse.statusCode == 200) {
                          uploadedImageUrl = uploadResponse.data['image_url'];
                        } else {
                          throw Exception("Failed to upload proof image.");
                        }
                      }

                      // 2. Submit contributor review
                      final reviewResponse = await _dio.post(
                        "/reviews/users/$contributorId",
                        data: {
                          "rating": selectedRating.toInt(),
                          "comment": desc,
                          "listing_id": widget.listingId,
                          if (uploadedImageUrl != null) "image_url": uploadedImageUrl,
                          "special_points": selectedSpecialPoints,
                        },
                      );

                      if (reviewResponse.statusCode == 201 || reviewResponse.statusCode == 200) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Verification submitted! Awarded $selectedSpecialPoints points to $contributorName."
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        setState(() {
                          _showVerificationTile = false;
                        });
                        _fetchDetails(); // Reload listing detail details
                      }
                    } catch (e) {
                      debugPrint("Error submitting verification review: $e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Error submitting verification review. Try again.")),
                        );
                      }
                    } finally {
                      setDialogState(() {
                        isSubmitting = false;
                      });
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVerificationBouncingTile() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 4,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
          ),
          color: Theme.of(context).brightness == Brightness.dark
               ? const Color(0xFF1E293B)
               : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars, color: Color(0xFFE11D48), size: 28),
                    SizedBox(width: 8),
                    Text(
                      "Was this helpful?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Help other newcomers by verifying that you utilized this service and got benefited!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text("Yes, verify my experience"),
                  onPressed: _showVerificationFormDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
    final webUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch navigation application.")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error launching map: $e");
    }
  }

  void _openFullScreenImages(int initialIndex) {
    final images = _listing!['images'] as List;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenImageViewer(
          images: images,
          initialIndex: initialIndex,
          getFullImageUrl: _getFullImageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Not Found"),
        ),
        body: const Center(child: Text("Listing not found")),
      );
    }

    final listing = _listing!;
    final avgRating = listing['average_rating'] ?? 0.0;

    final isOwner = _isLoggedIn && _currentUserId != null && 
        (listing['contributor_id'] == _currentUserId || 
         (listing['contributor'] != null && listing['contributor']['id'] == _currentUserId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        actions: [
          if (isOwner)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                onPressed: () {
                  context.push('/listings/${widget.listingId}/edit').then((result) {
                    if (result == true) {
                      _checkLoginAndFetchDetails();
                    }
                  });
                },
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border_outlined, color: Colors.white, size: 20),
              onPressed: _toggleSave,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Carousel at the top
            if (listing['images'] != null && (listing['images'] as List).isNotEmpty)
              ImageCarousel(
                images: listing['images'] as List,
                getFullImageUrl: _getFullImageUrl,
                onTapImage: _openFullScreenImages,
              )
            else
              Container(
                height: 240,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.storefront, size: 80, color: Colors.grey),
                ),
              ),

            // Top Section (Main Details Card)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x1AE11D48),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              listing['category']['name'] ?? '',
                              style: const TextStyle(
                                color: Color(0xFFE11D48),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (avgRating > 0.0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    avgRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        listing['name'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        listing['description'] ?? 'No description provided.',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Provider Information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Provider Information",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              tileColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AE11D48),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person, color: Color(0xFFE11D48), size: 20),
                              ),
                              title: Text(
                                listing['owner_name'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text("Owner"),
                              trailing: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0x1A10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.call, color: Color(0xFF10B981)),
                                  onPressed: () async {
                                    _triggerVerificationTile();
                                    final telUri = Uri.parse("tel:${listing['owner_phone']}");
                                    if (await canLaunchUrl(telUri)) {
                                      await launchUrl(telUri);
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Calling owner: ${listing['owner_phone']}")),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                            Divider(
                              height: 1, 
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)
                            ),
                            ListTile(
                              tileColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AE11D48),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.location_on, color: Color(0xFFE11D48), size: 20),
                              ),
                              title: Text(
                                listing['address'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                "Lat: ${listing['latitude']}, Lng: ${listing['longitude']}",
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.directions, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () {
                                    _triggerVerificationTile();
                                    _openNavigation(listing['latitude'], listing['longitude']);
                                  },
                                ),
                              ),
                            ),
                            Divider(
                              height: 1, 
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)
                            ),
                            ListTile(
                              tileColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AE11D48),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.access_time, color: Color(0xFFE11D48), size: 20),
                              ),
                              title: Text(
                                listing['working_hours'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text("Working Hours"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_showVerificationTile && !isOwner)
              _buildVerificationBouncingTile(),

            // Contributor Row
            if (listing['contributor'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade800
                          : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                  ),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Recommended By",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade800
                                  : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              final contributorId = listing['contributor']['id'] ?? listing['contributor_id'];
                              if (contributorId != null) {
                                context.push('/profile/$contributorId');
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                   CircleAvatar(
                                     radius: 24,
                                     backgroundColor: Theme.of(context).brightness == Brightness.dark
                                         ? const Color(0xFF1E293B)
                                         : const Color(0xFFF1F5F9),
                                     child: const Icon(Icons.face, color: Color(0xFFE11D48), size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          listing['contributor']['name'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Local Resident Contributor",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (listing['contributor']['phone_number'] != null)
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0x1A10B981),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.call, color: Color(0xFF10B981)),
                                        onPressed: () async {
                                          _triggerVerificationTile();
                                          final phone = listing['contributor']['phone_number'];
                                          final telUri = Uri.parse("tel:$phone");
                                          if (await canLaunchUrl(telUri)) {
                                            await launchUrl(telUri);
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text("Calling contributor: $phone")),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // User Reviews Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "User Reviews",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.rate_review_outlined, size: 18, color: Color(0xFFE11D48)),
                            label: const Text(
                              "Write Review",
                              style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold),
                            ),
                            onPressed: _addReviewDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              backgroundColor: const Color(0x1AE11D48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_reviews.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  "No reviews yet.\nShare your experience!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _reviews.length,
                          itemBuilder: (context, index) {
                            final rev = _reviews[index];
                            final authorName = rev['author']?['name'] ?? 'Anonymous';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade800
                                      : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                       CircleAvatar(
                                         radius: 14,
                                         backgroundColor: const Color(0x1AE11D48),
                                         child: Text(
                                           authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A',
                                           style: const TextStyle(
                                             color: Color(0xFFE11D48),
                                             fontSize: 12,
                                             fontWeight: FontWeight.bold,
                                           ),
                                         ),
                                       ),
                                      const SizedBox(width: 8),
                                      Text(
                                        authorName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: List.generate(5, (starIdx) {
                                          return Icon(
                                            starIdx < rev['rating'] ? Icons.star : Icons.star_border,
                                            color: Colors.amber,
                                            size: 14,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  if (rev['comment'] != null && rev['comment'].toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      rev['comment'],
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final List<dynamic> images;
  final String Function(String) getFullImageUrl;
  final void Function(int) onTapImage;

  const ImageCarousel({
    super.key,
    required this.images,
    required this.getFullImageUrl,
    required this.onTapImage,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            itemBuilder: (context, idx) {
              final imgUrl = widget.getFullImageUrl(widget.images[idx]['image_url']);
              return GestureDetector(
                onTap: () => widget.onTapImage(idx),
                child: Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              );
            },
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                    stops: const [0.0, 0.25, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_currentIndex + 1} / ${widget.images.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;
  final String Function(String) getFullImageUrl;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.getFullImageUrl,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Image ${_currentIndex + 1} of ${widget.images.length}",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, idx) {
              final imgUrl = widget.getFullImageUrl(widget.images[idx]['image_url']);
              return InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    imgUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 80,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (dotIdx) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: dotIdx == _currentIndex ? 12.0 : 6.0,
                  height: 6.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: dotIdx == _currentIndex ? Colors.white : Colors.white24,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
