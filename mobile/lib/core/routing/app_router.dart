import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import screens when created
// For compilation safety, we will define placeholder widgets/routes
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/listings/presentation/listings_screen.dart';
import '../../features/listings/presentation/add_listing_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/my_listings_screen.dart';
import '../../features/listings/presentation/saved_listings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final loggingIn = state.matchedLocation == '/login';
    
    // Allow users to search/browse listings without login (public)
    // Only redirect to login if attempting to create/modify listing or review
    final requiresAuth = state.matchedLocation.startsWith('/listings/add') ||
                         state.matchedLocation.startsWith('/profile') ||
                         state.matchedLocation.startsWith('/my-listings') ||
                         state.matchedLocation.startsWith('/saved-listings');
    
    if (token == null && requiresAuth) {
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
      builder: (context, state) => const ListingsScreen(),
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
      path: '/my-listings',
      builder: (context, state) => const MyListingsScreen(),
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
  ],
);
