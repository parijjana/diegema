/// Platform seam for [AppDatabase].
///
/// Native builds (macOS, iOS, Android, Linux, Windows, and the VM test
/// runner) get the real drift/sqlite3-backed implementation in
/// `app_database_io.dart`. Web builds get an in-memory, dependency-free
/// implementation in `app_database_web.dart` instead: `sqlite3_flutter_libs`
/// uses `dart:ffi` `external` bindings that do not compile for web at all
/// (see rework_plan.md's "Skip drift on web" decision), so the real
/// implementation must never even be imported into a web build's dependency
/// graph. This file is a pure re-export barrel so every call site can keep
/// importing `database/app_database.dart` unchanged.
library;

export 'app_database_io.dart' if (dart.library.html) 'app_database_web.dart';
