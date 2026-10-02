import '../database/app_database.dart';
import 'library_locations_store.dart';

const String kLibraryLocationSource = 'Library folder';

Future<int> scanLibraryLocations(
  AppDatabase db, {
  LibraryLocationsStore store = const LibraryLocationsStore(),
  String? only,
}) async =>
    0;

Future<List<String>> booksInLocation(AppDatabase db, String location) async =>
    const [];
