import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import screens when created
// For compilation safety, we will define placeholder widgets/routes
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/profile_create_screen.dart';
import '../../features/listings/presentation/listings_screen.dart';
import '../../features/listings/presentation/add_listing_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/my_listings_screen.dart';
import '../../features/listings/presentation/saved_listings_screen.dart';
import '../../features/listings/presentation/edit_listing_screen.dart';
import '../../features/listings/presentation/admin_dashboard_screen.dart';
import '../../features/listings/presentation/map_picker_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final loggingIn = state.matchedLocation == '/login';
    
    if (token == null && !loggingIn) {
      return '/login';
    }
    
    if (token != null && loggingIn) {
      return '/';
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        final refresh = state.uri.queryParameters['refresh'];
        return ListingsScreen(refreshKey: refresh);
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/profile/create',
      builder: (context, state) => const ProfileCreateScreen(),
    ),
    GoRoute(
      path: '/profile/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProfileScreen(userId: id);
      },
    ),
    GoRoute(
      path: '/my-listings',
      builder: (context, state) {
        final userId = state.uri.queryParameters['userId'];
        return MyListingsScreen(userId: userId);
      },
    ),
    GoRoute(
      path: '/saved-listings',
      builder: (context, state) => const SavedListingsScreen(),
    ),
    GoRoute(
      path: '/listings/add',
      builder: (context, state) => const AddListingScreen(),
    ),
    GoRoute(
      path: '/listings/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ListingDetailScreen(listingId: id);
      },
    ),
    GoRoute(
      path: '/listings/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EditListingScreen(listingId: id);
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/map-picker',
      builder: (context, state) {
        final latVal = state.uri.queryParameters['lat'];
        final lngVal = state.uri.queryParameters['lng'];
        final double? lat = latVal != null ? double.tryParse(latVal) : null;
        final double? lng = lngVal != null ? double.tryParse(lngVal) : null;
        return MapPickerScreen(initialLatitude: lat, initialLongitude: lng);
      },
    ),
  ],
);
