import 'package:aether/core/database/database.dart';
import 'package:aether/core/database/tables/courses.dart';
import 'package:aether/core/database/tables/lectures.dart';
import 'package:aether/core/database/tables/assignments.dart';
import 'package:aether/core/services/supabase_service.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class AcademicsService {
  final AppDatabase _db;
  final _supabase = SupabaseService.instance.client;

  AcademicsService(this._db);

  // ── Courses ──────────────────────────────────────────

  Future<List<Course>> getCourses() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final remote = await _supabase.from('courses').select().eq('user_id', userId);

    for (final row in remote) {
      final r = row as Map<String, dynamic>;
      final exists = await (_db.select(_db.courses)
            ..where((t) => t.id.equals(r['id'] as String)))
          .getSingleOrNull();
      final course = Course(
        id: r['id'] as String,
        userId: r['userId'] as String? ?? userId,
        name: r['name'] as String? ?? '',
        code: r['code'] as String?,
        professor: r['professor'] as String?,
        color: r['color'] as String? ?? '#8B5CF6',
        icon: r['icon'] as String?,
        semester: r['semester'] as String?,
        location: r['location'] as String?,
        credits: r['credits'] as int?,
        scheduleDays: r['scheduleDays'] is List
            ? (r['scheduleDays'] as List).join(',')
            : r['scheduleDays'] as String?,
        scheduleStart: r['scheduleStart'] as String?,
        scheduleEnd: r['scheduleEnd'] as String?,
        createdAt: r['createdAt'] is String ? DateTime.parse(r['createdAt'] as String) : DateTime.now(),
        updatedAt: r['updatedAt'] is String ? DateTime.parse(r['updatedAt'] as String) : DateTime.now(),
      );
      if (exists != null) {
        await _db.update(_db.courses).replace(course);
      } else {
        await _db.into(_db.courses).insert(course);
      }
    }

    return _db.select(_db.courses).get();
  }

  Stream<List<Course>> watchCourses() {
    return (_db.select(_db.courses).watch());
  }

  Future<Course> createCourse({
    required String name,
    String? code,
    String? professor,
    String? color,
    String? icon,
    String? semester,
    String? location,
    int? credits,
    String? scheduleDays,
    String? scheduleStart,
    String? scheduleEnd,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final id = const Uuid().v4();
    final now = DateTime.now();

    await _supabase.from('courses').insert({
      'id': id,
      'userId': userId,
      'name': name,
      'code': code,
      'professor': professor,
      'color': color ?? '#8B5CF6',
      'icon': icon,
      'semester': semester,
      'location': location,
      'credits': credits,
      'scheduleDays': scheduleDays?.split(',').map((s) => s.trim()).toList(),
      'scheduleStart': scheduleStart,
      'scheduleEnd': scheduleEnd,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    return _db.into(_db.courses).insertReturning(Course(
      id: id,
      userId: userId,
      name: name,
      code: code,
      professor: professor,
      color: color ?? '#8B5CF6',
      icon: icon,
      semester: semester,
      location: location,
      credits: credits,
      scheduleDays: scheduleDays,
      scheduleStart: scheduleStart,
      scheduleEnd: scheduleEnd,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> deleteCourse(String courseId) async {
    await _supabase.from('courses').delete().eq('id', courseId);
    await (_db.delete(_db.courses)..where((t) => t.id.equals(courseId))).go();
  }

  Future<void> updateCourse(Course course) async {
    final now = DateTime.now();
    await _supabase.from('courses').update({
      'name': course.name,
      'code': course.code,
      'professor': course.professor,
      'color': course.color,
      'icon': course.icon,
      'semester': course.semester,
      'location': course.location,
      'credits': course.credits,
      'scheduleDays': course.scheduleDays?.split(',').map((s) => s.trim()).toList(),
      'scheduleStart': course.scheduleStart,
      'scheduleEnd': course.scheduleEnd,
      'updatedAt': now.toIso8601String(),
    }).eq('id', course.id);

    await _db.update(_db.courses).replace(course.copyWith(updatedAt: now));
  }

  // ── Lectures ──────────────────────────────────────────

  Future<List<Lecture>> getLectures({String? courseId, bool? today}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _supabase.from('lectures').select().eq('user_id', userId);
    if (courseId != null) query = query.eq('course_id', courseId);
    if (today == true) {
      final start = DateTime.now().toUtc().copyWith(hour: 0, minute: 0);
      final end = start.add(const Duration(days: 1));
      query = query.gte('scheduled_at', start.toIso8601String()).lt('scheduled_at', end.toIso8601String());
    }

    final remote = await query.order('scheduled_at', ascending: true);
    final lectures = remote.map((row) {
      final r = row as Map<String, dynamic>;
      return Lecture(
        id: r['id'] as String,
        courseId: r['course_id'] as String? ?? courseId ?? '',
        userId: r['userId'] as String? ?? userId,
        title: r['title'] as String? ?? '',
        chapter: r['chapter'] as String?,
        tag: r['tag'] as String?,
        scheduledAt: r['scheduled_at'] != null ? DateTime.parse(r['scheduled_at'] as String) : null,
        durationMinutes: r['duration_minutes'] as int? ?? 90,
        isCompleted: r['is_completed'] as bool? ?? false,
        completedAt: r['completed_at'] != null ? DateTime.parse(r['completed_at'] as String) : null,
        createdAt: r['created_at'] is String ? DateTime.parse(r['created_at'] as String) : DateTime.now(),
        updatedAt: r['updated_at'] is String ? DateTime.parse(r['updated_at'] as String) : DateTime.now(),
      );
    }).toList();

    for (final lec in lectures) {
      final exists = await (_db.select(_db.lectures)
            ..where((l) => l.id.equals(lec.id)))
          .getSingleOrNull();
      if (exists != null) {
        await _db.update(_db.lectures).replace(lec);
      } else {
        await _db.into(_db.lectures).insert(lec);
      }
    }
    return lectures;
  }

  Future<void> createLecture(String courseId, String title) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _supabase.from('lectures').insert({
      'id': id,
      'course_id': courseId,
      'user_id': userId,
      'title': title,
      'is_completed': false,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await _db.into(_db.lectures).insert(Lecture(
      id: id,
      courseId: courseId,
      userId: userId,
      title: title,
      isCompleted: false,
      durationMinutes: 90,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> toggleLectureCompletion(String lectureId, bool completed) async {
    final now = DateTime.now();
    await _supabase.from('lectures').update({
      'is_completed': completed,
      'completed_at': completed ? now.toIso8601String() : null,
      'updated_at': now.toIso8601String(),
    }).eq('id', lectureId);

    await (_db.update(_db.lectures)
      ..where((l) => l.id.equals(lectureId)))
      .write(LecturesCompanion(
        isCompleted: Value(completed),
        completedAt: Value(completed ? now : null),
        updatedAt: Value(now),
      ));
  }

  // ── Assignments ──────────────────────────────────────

  Future<List<Assignment>> watchAssignments({String? courseId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _supabase.from('assignments').select().eq('user_id', userId);
    if (courseId != null) query = query.eq('course_id', courseId);

    final remote = await query.order('due_date', ascending: true);
    final assignments = remote.map((row) {
      final r = row as Map<String, dynamic>;
      return Assignment(
        id: r['id'] as String,
        courseId: r['course_id'] as String? ?? courseId ?? '',
        userId: r['userId'] as String? ?? userId,
        title: r['title'] as String? ?? '',
        description: r['description'] as String?,
        dueDate: r['due_date'] != null ? DateTime.parse(r['due_date'] as String) : null,
        isCompleted: r['is_completed'] as bool? ?? false,
        completedAt: r['completed_at'] != null ? DateTime.parse(r['completed_at'] as String) : null,
        createdAt: r['created_at'] is String ? DateTime.parse(r['created_at'] as String) : DateTime.now(),
        updatedAt: r['updated_at'] is String ? DateTime.parse(r['updated_at'] as String) : DateTime.now(),
      );
    }).toList();

    for (final a in assignments) {
      final exists = await (_db.select(_db.assignments)
            ..where((t) => t.id.equals(a.id)))
          .getSingleOrNull();
      if (exists != null) {
        await _db.update(_db.assignments).replace(a);
      } else {
        await _db.into(_db.assignments).insert(a);
      }
    }
    return assignments;
  }

  Future<void> createAssignment(String courseId, String title) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _supabase.from('assignments').insert({
      'id': id,
      'course_id': courseId,
      'user_id': userId,
      'title': title,
      'is_completed': false,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await _db.into(_db.assignments).insert(Assignment(
      id: id,
      courseId: courseId,
      userId: userId,
      title: title,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> toggleAssignmentCompletion(String assignmentId, bool completed) async {
    final now = DateTime.now();
    await _supabase.from('assignments').update({
      'is_completed': completed,
      'completed_at': completed ? now.toIso8601String() : null,
      'updated_at': now.toIso8601String(),
    }).eq('id', assignmentId);

    await (_db.update(_db.assignments)
      ..where((a) => a.id.equals(assignmentId)))
      .write(AssignmentsCompanion(
        isCompleted: Value(completed),
        completedAt: Value(completed ? now : null),
        updatedAt: Value(now),
      ));
  }
}
