import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'downloads_location_web.dart';
import 'removed_books_store.dart';

/// What removing a book would do to files. Web: nothing on disk.
class BookRemovalPlan {
  final List<String> deletePaths;
  final int bytes;
  final bool filesUntouched;
  const BookRemovalPlan(
      {this.deletePaths = const [],
      this.bytes = 0,
      this.filesUntouched = false});
}

Future<BookRemovalPlan> planBookRemoval(UnifiedAudiobook book,
        {String? documentsPath, DownloadsLocation? downloads}) async =>
    const BookRemovalPlan();

Future<int> removeBook(AppDatabase db, UnifiedAudiobook book,
    {String? documentsPath,
    DownloadsLocation? downloads,
    RemovedBooksStore removedStore = const RemovedBooksStore()}) async {
  await db.deleteAudiobookAndUserData(book.id);
  return 0;
}
