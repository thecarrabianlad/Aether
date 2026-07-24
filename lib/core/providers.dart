import 'package:flutter/material.dart'; // Added for VoidCallback
import 'package:aether/core/database/database.dart';
import 'package:aether/core/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authProvider = Provider<AuthService>((ref) => AuthService.instance);

/// Global drawer state provider
final drawerProvider = StateProvider<bool>((ref) => false);

/// Global provider for the "Add" button action in the BottomNavbar.
/// The currently active screen can override this to set its specific action.
final globalAddActionProvider = StateProvider<VoidCallback?>((ref) => null);