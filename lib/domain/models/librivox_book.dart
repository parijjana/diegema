import '../../core/utils/text_sanitizer.dart';

typedef JsonMap = Map<String, dynamic>;

class LibriVoxAuthor {
  final String id;
  final String firstName;
  final String lastName;

  LibriVoxAuthor({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  String get fullName {
    if (firstName.isEmpty) return lastName;
    if (lastName.isEmpty) return firstName;
    return '$firstName $lastName';
  }

  factory LibriVoxAuthor.fromJson(JsonMap json) {
    return LibriVoxAuthor(
      id: (json['id']?.toString() ?? ''),
      firstName: (json['first_name']?.toString() ?? ''),
      lastName: (json['last_name']?.toString() ?? ''),
    );
  }

  JsonMap toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
    };
  }
}

class LibriVoxBook {
  final String id;
  final String title;
  final String description;
  final int totalTimeSecs;
  final List<LibriVoxAuthor> authors;
  final String urlRss;
  final String urlZipFile;
  final String urlIarchive;
  final String language;
  final List<String> narrators;

  /// True (the default) for every book from the real LibriVox/archive.org
  /// APIs. Only the canned web demo's curated catalog ever sets this to
  /// false, to mark a browse-only preview entry whose audio was not
  /// bundled with the demo. See rework_plan.md: "Every non-playable entry
  /// must be visibly marked in the UI."
  final bool demoPlayable;

  LibriVoxBook({
    required this.id,
    required this.title,
    required this.description,
    required this.totalTimeSecs,
    required this.authors,
    required this.urlRss,
    required this.urlZipFile,
    this.urlIarchive = '',
    required this.language,
    required this.narrators,
    this.demoPlayable = true,
  });

  String get authorNames {
    if (authors.isEmpty) return 'Unknown Author';
    return authors.map((a) => a.fullName).join(', ');
  }

  String get coverArtUrl {
    String identifier = id;
    if (urlIarchive.isNotEmpty) {
      final parts = urlIarchive.split('/details/');
      if (parts.length > 1) {
        identifier = parts[1].replaceAll('/', '').trim();
      }
    }
    if (identifier.isNotEmpty && !identifier.contains(RegExp(r'^\d+$'))) {
      return 'https://archive.org/services/img/$identifier';
    }
    return '';
  }

  factory LibriVoxBook.fromJson(JsonMap json) {
    final authorsList = json['authors'] as List? ?? [];
    final parsedAuthors =
        authorsList.map((a) => LibriVoxAuthor.fromJson(a as JsonMap)).toList();

    final sectionsList = json['sections'] as List? ?? [];
    final Set<String> uniqueNarrators = {};
    for (final sec in sectionsList) {
      if (sec is JsonMap) {
        final readersList = sec['readers'] as List? ?? [];
        for (final r in readersList) {
          if (r is JsonMap) {
            final name = r['display_name']?.toString().trim() ?? '';
            if (name.isNotEmpty) {
              uniqueNarrators.add(name);
            }
          }
        }
      }
    }
    final narrators = uniqueNarrators.toList()..sort();

    return LibriVoxBook(
      id: (json['id']?.toString() ?? ''),
      title: (json['title']?.toString() ?? 'Unknown Title'),
      description:
          TextSanitizer.sanitize(json['description']?.toString() ?? ''),
      totalTimeSecs:
          int.tryParse(json['totaltimesecs']?.toString() ?? '0') ?? 0,
      authors: parsedAuthors,
      urlRss: (json['url_rss']?.toString() ?? ''),
      urlZipFile: (json['url_zip_file']?.toString() ?? ''),
      urlIarchive: (json['url_iarchive']?.toString() ?? ''),
      language: (json['language']?.toString() ?? 'English'),
      narrators: narrators,
    );
  }

  JsonMap toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'totaltimesecs': totalTimeSecs.toString(),
      'authors': authors.map((a) => a.toJson()).toList(),
      'url_rss': urlRss,
      'url_zip_file': urlZipFile,
      'url_iarchive': urlIarchive,
      'language': language,
      'sections': narrators
          .map(
            (n) => {
              'readers': [
                {'display_name': n}
              ],
            },
          )
          .toList(),
    };
  }
}
