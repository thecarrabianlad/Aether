import 'package:aether/core/database/database.dart';
import 'package:aether/core/services/supabase_service.dart';
import 'package:drift/drift.dart';
import 'package:gotrue/gotrue.dart' show AuthException;
import 'package:postgrest/postgrest.dart' show PostgrestException;
import 'package:uuid/uuid.dart';

import 'package:aether/features/habits/models/habit.dart'; // Import for the Habit model

/// Offline-first habits data layer.
///
/// The UI always reads from the local Drift database via the `watch*`
/// streams, so it updates instantly. Mutations write to Drift first
/// (immediate UI reaction) then push to Supabase in the background.
/// `sync*` methods pull remote data into the local DB.
class HabitsService {
  final AppDatabase _db;
  final _supabase = SupabaseService.instance.client;

  HabitsService(this._db);

  String? get _userId => _supabase.auth.currentUser?.id;

  // ── Habits ──────────────────────────────────────────

  Stream<List<Habit>> watchHabits() {
    // TODO: Implement streaming habits from Drift, transforming them into Habit model
    return Stream.value([]);
  }

  Future<void> createHabit({
    required String name,
    required HabitCategory category,
    required String icon, // Changed to String as IconData is not serializable
    required String color, // Changed to String as Color is not serializable
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    // TODO: Implement local Drift write then push to Supabase
  }

  Future<void> toggleCompletion(String habitId, bool completed) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    // TODO: Implement local Drift write then push to Supabase
  }

  Future<void> syncHabits() async {
    final userId = _userId;
    if (userId == null) return;

    // TODO: Implement pulling habits from Supabase and updating Drift
  }

  Future<void> syncHabitLogs() async {
    final userId = _userId;
    if (userId == null) return;

    // TODO: Implement pulling habit logs from Supabase and updating Drift
  }

  // ── Helpers ──────────────────────────────────────────

  /// Runs a remote push, swallowing network errors so the local-first
  /// write still stands (offline-first). Rethrows auth errors so they
  /// can be surfaced to the user.
  Future<void> _push(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      if (e is AuthException || (e is PostgrestException && e.code == 'PGRST301')) {
        rethrow;
      }
      // Offline or transient error — local DB is source of truth until
      // the next successful sync. Intentionally ignored.
    }
  }

  // TODO: Add _habitFromRow and _habitToRow for data mapping
}
