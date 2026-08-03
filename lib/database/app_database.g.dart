// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AudiobooksTable extends Audiobooks
    with TableInfo<$AudiobooksTable, Audiobook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudiobooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Local'));
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDownloadedMeta =
      const VerificationMeta('isDownloaded');
  @override
  late final GeneratedColumn<bool> isDownloaded = GeneratedColumn<bool>(
      'is_downloaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_downloaded" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        author,
        description,
        source,
        coverUrl,
        isDownloaded,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audiobooks';
  @override
  VerificationContext validateIntegrity(Insertable<Audiobook> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
          _isDownloadedMeta,
          isDownloaded.isAcceptableOrUnknown(
              data['is_downloaded']!, _isDownloadedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Audiobook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Audiobook(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AudiobooksTable createAlias(String alias) {
    return $AudiobooksTable(attachedDatabase, alias);
  }
}

class Audiobook extends DataClass implements Insertable<Audiobook> {
  final String id;
  final String title;
  final String author;
  final String description;
  final String source;
  final String? coverUrl;
  final bool isDownloaded;
  final DateTime createdAt;
  const Audiobook(
      {required this.id,
      required this.title,
      required this.author,
      required this.description,
      required this.source,
      this.coverUrl,
      required this.isDownloaded,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['description'] = Variable<String>(description);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AudiobooksCompanion toCompanion(bool nullToAbsent) {
    return AudiobooksCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      description: Value(description),
      source: Value(source),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      isDownloaded: Value(isDownloaded),
      createdAt: Value(createdAt),
    );
  }

  factory Audiobook.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Audiobook(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      description: serializer.fromJson<String>(json['description']),
      source: serializer.fromJson<String>(json['source']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'description': serializer.toJson<String>(description),
      'source': serializer.toJson<String>(source),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Audiobook copyWith(
          {String? id,
          String? title,
          String? author,
          String? description,
          String? source,
          Value<String?> coverUrl = const Value.absent(),
          bool? isDownloaded,
          DateTime? createdAt}) =>
      Audiobook(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        description: description ?? this.description,
        source: source ?? this.source,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        createdAt: createdAt ?? this.createdAt,
      );
  Audiobook copyWithCompanion(AudiobooksCompanion data) {
    return Audiobook(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      description:
          data.description.present ? data.description.value : this.description,
      source: data.source.present ? data.source.value : this.source,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Audiobook(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, author, description, source,
      coverUrl, isDownloaded, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Audiobook &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.description == this.description &&
          other.source == this.source &&
          other.coverUrl == this.coverUrl &&
          other.isDownloaded == this.isDownloaded &&
          other.createdAt == this.createdAt);
}

class AudiobooksCompanion extends UpdateCompanion<Audiobook> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String> description;
  final Value<String> source;
  final Value<String?> coverUrl;
  final Value<bool> isDownloaded;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AudiobooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.source = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudiobooksCompanion.insert({
    required String id,
    required String title,
    required String author,
    required String description,
    this.source = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        author = Value(author),
        description = Value(description);
  static Insertable<Audiobook> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? description,
    Expression<String>? source,
    Expression<String>? coverUrl,
    Expression<bool>? isDownloaded,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (source != null) 'source': source,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudiobooksCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? author,
      Value<String>? description,
      Value<String>? source,
      Value<String?>? coverUrl,
      Value<bool>? isDownloaded,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AudiobooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      source: source ?? this.source,
      coverUrl: coverUrl ?? this.coverUrl,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudiobooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _audiobookIdMeta =
      const VerificationMeta('audiobookId');
  @override
  late final GeneratedColumn<String> audiobookId = GeneratedColumn<String>(
      'audiobook_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _audioPathOrUrlMeta =
      const VerificationMeta('audioPathOrUrl');
  @override
  late final GeneratedColumn<String> audioPathOrUrl = GeneratedColumn<String>(
      'audio_path_or_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isStreamMeta =
      const VerificationMeta('isStream');
  @override
  late final GeneratedColumn<bool> isStream = GeneratedColumn<bool>(
      'is_stream', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_stream" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        audiobookId,
        chapterIndex,
        title,
        audioPathOrUrl,
        durationSeconds,
        isStream
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(Insertable<Chapter> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('audiobook_id')) {
      context.handle(
          _audiobookIdMeta,
          audiobookId.isAcceptableOrUnknown(
              data['audiobook_id']!, _audiobookIdMeta));
    } else if (isInserting) {
      context.missing(_audiobookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('audio_path_or_url')) {
      context.handle(
          _audioPathOrUrlMeta,
          audioPathOrUrl.isAcceptableOrUnknown(
              data['audio_path_or_url']!, _audioPathOrUrlMeta));
    } else if (isInserting) {
      context.missing(_audioPathOrUrlMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('is_stream')) {
      context.handle(_isStreamMeta,
          isStream.isAcceptableOrUnknown(data['is_stream']!, _isStreamMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      audiobookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audiobook_id'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      audioPathOrUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}audio_path_or_url'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      isStream: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_stream'])!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final String id;
  final String audiobookId;
  final int chapterIndex;
  final String title;
  final String audioPathOrUrl;
  final int durationSeconds;
  final bool isStream;
  const Chapter(
      {required this.id,
      required this.audiobookId,
      required this.chapterIndex,
      required this.title,
      required this.audioPathOrUrl,
      required this.durationSeconds,
      required this.isStream});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['audiobook_id'] = Variable<String>(audiobookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['title'] = Variable<String>(title);
    map['audio_path_or_url'] = Variable<String>(audioPathOrUrl);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['is_stream'] = Variable<bool>(isStream);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      audiobookId: Value(audiobookId),
      chapterIndex: Value(chapterIndex),
      title: Value(title),
      audioPathOrUrl: Value(audioPathOrUrl),
      durationSeconds: Value(durationSeconds),
      isStream: Value(isStream),
    );
  }

  factory Chapter.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<String>(json['id']),
      audiobookId: serializer.fromJson<String>(json['audiobookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      title: serializer.fromJson<String>(json['title']),
      audioPathOrUrl: serializer.fromJson<String>(json['audioPathOrUrl']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      isStream: serializer.fromJson<bool>(json['isStream']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'audiobookId': serializer.toJson<String>(audiobookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'title': serializer.toJson<String>(title),
      'audioPathOrUrl': serializer.toJson<String>(audioPathOrUrl),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'isStream': serializer.toJson<bool>(isStream),
    };
  }

  Chapter copyWith(
          {String? id,
          String? audiobookId,
          int? chapterIndex,
          String? title,
          String? audioPathOrUrl,
          int? durationSeconds,
          bool? isStream}) =>
      Chapter(
        id: id ?? this.id,
        audiobookId: audiobookId ?? this.audiobookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        title: title ?? this.title,
        audioPathOrUrl: audioPathOrUrl ?? this.audioPathOrUrl,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        isStream: isStream ?? this.isStream,
      );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      audiobookId:
          data.audiobookId.present ? data.audiobookId.value : this.audiobookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      title: data.title.present ? data.title.value : this.title,
      audioPathOrUrl: data.audioPathOrUrl.present
          ? data.audioPathOrUrl.value
          : this.audioPathOrUrl,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      isStream: data.isStream.present ? data.isStream.value : this.isStream,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('audiobookId: $audiobookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title, ')
          ..write('audioPathOrUrl: $audioPathOrUrl, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('isStream: $isStream')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, audiobookId, chapterIndex, title,
      audioPathOrUrl, durationSeconds, isStream);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.audiobookId == this.audiobookId &&
          other.chapterIndex == this.chapterIndex &&
          other.title == this.title &&
          other.audioPathOrUrl == this.audioPathOrUrl &&
          other.durationSeconds == this.durationSeconds &&
          other.isStream == this.isStream);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<String> id;
  final Value<String> audiobookId;
  final Value<int> chapterIndex;
  final Value<String> title;
  final Value<String> audioPathOrUrl;
  final Value<int> durationSeconds;
  final Value<bool> isStream;
  final Value<int> rowid;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.audiobookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.title = const Value.absent(),
    this.audioPathOrUrl = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.isStream = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChaptersCompanion.insert({
    required String id,
    required String audiobookId,
    required int chapterIndex,
    required String title,
    required String audioPathOrUrl,
    this.durationSeconds = const Value.absent(),
    this.isStream = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        audiobookId = Value(audiobookId),
        chapterIndex = Value(chapterIndex),
        title = Value(title),
        audioPathOrUrl = Value(audioPathOrUrl);
  static Insertable<Chapter> custom({
    Expression<String>? id,
    Expression<String>? audiobookId,
    Expression<int>? chapterIndex,
    Expression<String>? title,
    Expression<String>? audioPathOrUrl,
    Expression<int>? durationSeconds,
    Expression<bool>? isStream,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (audiobookId != null) 'audiobook_id': audiobookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (title != null) 'title': title,
      if (audioPathOrUrl != null) 'audio_path_or_url': audioPathOrUrl,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (isStream != null) 'is_stream': isStream,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChaptersCompanion copyWith(
      {Value<String>? id,
      Value<String>? audiobookId,
      Value<int>? chapterIndex,
      Value<String>? title,
      Value<String>? audioPathOrUrl,
      Value<int>? durationSeconds,
      Value<bool>? isStream,
      Value<int>? rowid}) {
    return ChaptersCompanion(
      id: id ?? this.id,
      audiobookId: audiobookId ?? this.audiobookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      audioPathOrUrl: audioPathOrUrl ?? this.audioPathOrUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isStream: isStream ?? this.isStream,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (audiobookId.present) {
      map['audiobook_id'] = Variable<String>(audiobookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (audioPathOrUrl.present) {
      map['audio_path_or_url'] = Variable<String>(audioPathOrUrl.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (isStream.present) {
      map['is_stream'] = Variable<bool>(isStream.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('audiobookId: $audiobookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title, ')
          ..write('audioPathOrUrl: $audioPathOrUrl, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('isStream: $isStream, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackProgressTable extends PlaybackProgress
    with TableInfo<$PlaybackProgressTable, PlaybackProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _audiobookIdMeta =
      const VerificationMeta('audiobookId');
  @override
  late final GeneratedColumn<String> audiobookId = GeneratedColumn<String>(
      'audiobook_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _positionSecondsMeta =
      const VerificationMeta('positionSeconds');
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
      'position_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [audiobookId, chapterIndex, positionSeconds, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<PlaybackProgressData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('audiobook_id')) {
      context.handle(
          _audiobookIdMeta,
          audiobookId.isAcceptableOrUnknown(
              data['audiobook_id']!, _audiobookIdMeta));
    } else if (isInserting) {
      context.missing(_audiobookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
          _positionSecondsMeta,
          positionSeconds.isAcceptableOrUnknown(
              data['position_seconds']!, _positionSecondsMeta));
    } else if (isInserting) {
      context.missing(_positionSecondsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {audiobookId};
  @override
  PlaybackProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackProgressData(
      audiobookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audiobook_id'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      positionSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_seconds'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlaybackProgressTable createAlias(String alias) {
    return $PlaybackProgressTable(attachedDatabase, alias);
  }
}

class PlaybackProgressData extends DataClass
    implements Insertable<PlaybackProgressData> {
  final String audiobookId;
  final int chapterIndex;
  final int positionSeconds;
  final DateTime updatedAt;
  const PlaybackProgressData(
      {required this.audiobookId,
      required this.chapterIndex,
      required this.positionSeconds,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['audiobook_id'] = Variable<String>(audiobookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['position_seconds'] = Variable<int>(positionSeconds);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackProgressCompanion toCompanion(bool nullToAbsent) {
    return PlaybackProgressCompanion(
      audiobookId: Value(audiobookId),
      chapterIndex: Value(chapterIndex),
      positionSeconds: Value(positionSeconds),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackProgressData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackProgressData(
      audiobookId: serializer.fromJson<String>(json['audiobookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'audiobookId': serializer.toJson<String>(audiobookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackProgressData copyWith(
          {String? audiobookId,
          int? chapterIndex,
          int? positionSeconds,
          DateTime? updatedAt}) =>
      PlaybackProgressData(
        audiobookId: audiobookId ?? this.audiobookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PlaybackProgressData copyWithCompanion(PlaybackProgressCompanion data) {
    return PlaybackProgressData(
      audiobookId:
          data.audiobookId.present ? data.audiobookId.value : this.audiobookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressData(')
          ..write('audiobookId: $audiobookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(audiobookId, chapterIndex, positionSeconds, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackProgressData &&
          other.audiobookId == this.audiobookId &&
          other.chapterIndex == this.chapterIndex &&
          other.positionSeconds == this.positionSeconds &&
          other.updatedAt == this.updatedAt);
}

class PlaybackProgressCompanion extends UpdateCompanion<PlaybackProgressData> {
  final Value<String> audiobookId;
  final Value<int> chapterIndex;
  final Value<int> positionSeconds;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaybackProgressCompanion({
    this.audiobookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackProgressCompanion.insert({
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : audiobookId = Value(audiobookId),
        chapterIndex = Value(chapterIndex),
        positionSeconds = Value(positionSeconds);
  static Insertable<PlaybackProgressData> custom({
    Expression<String>? audiobookId,
    Expression<int>? chapterIndex,
    Expression<int>? positionSeconds,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (audiobookId != null) 'audiobook_id': audiobookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackProgressCompanion copyWith(
      {Value<String>? audiobookId,
      Value<int>? chapterIndex,
      Value<int>? positionSeconds,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PlaybackProgressCompanion(
      audiobookId: audiobookId ?? this.audiobookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (audiobookId.present) {
      map['audiobook_id'] = Variable<String>(audiobookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressCompanion(')
          ..write('audiobookId: $audiobookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _audiobookIdMeta =
      const VerificationMeta('audiobookId');
  @override
  late final GeneratedColumn<String> audiobookId = GeneratedColumn<String>(
      'audiobook_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _positionSecondsMeta =
      const VerificationMeta('positionSeconds');
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
      'position_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, audiobookId, chapterIndex, positionSeconds, note, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(Insertable<Bookmark> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('audiobook_id')) {
      context.handle(
          _audiobookIdMeta,
          audiobookId.isAcceptableOrUnknown(
              data['audiobook_id']!, _audiobookIdMeta));
    } else if (isInserting) {
      context.missing(_audiobookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
          _positionSecondsMeta,
          positionSeconds.isAcceptableOrUnknown(
              data['position_seconds']!, _positionSecondsMeta));
    } else if (isInserting) {
      context.missing(_positionSecondsMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      audiobookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audiobook_id'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      positionSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_seconds'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final String id;
  final String audiobookId;
  final int chapterIndex;
  final int positionSeconds;
  final String note;
  final DateTime createdAt;
  const Bookmark(
      {required this.id,
      required this.audiobookId,
      required this.chapterIndex,
      required this.positionSeconds,
      required this.note,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['audiobook_id'] = Variable<String>(audiobookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['position_seconds'] = Variable<int>(positionSeconds);
    map['note'] = Variable<String>(note);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      audiobookId: Value(audiobookId),
      chapterIndex: Value(chapterIndex),
      positionSeconds: Value(positionSeconds),
      note: Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory Bookmark.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<String>(json['id']),
      audiobookId: serializer.fromJson<String>(json['audiobookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'audiobookId': serializer.toJson<String>(audiobookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bookmark copyWith(
          {String? id,
          String? audiobookId,
          int? chapterIndex,
          int? positionSeconds,
          String? note,
          DateTime? createdAt}) =>
      Bookmark(
        id: id ?? this.id,
        audiobookId: audiobookId ?? this.audiobookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      audiobookId:
          data.audiobookId.present ? data.audiobookId.value : this.audiobookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('audiobookId: $audiobookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, audiobookId, chapterIndex, positionSeconds, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.audiobookId == this.audiobookId &&
          other.chapterIndex == this.chapterIndex &&
          other.positionSeconds == this.positionSeconds &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> id;
  final Value<String> audiobookId;
  final Value<int> chapterIndex;
  final Value<int> positionSeconds;
  final Value<String> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.audiobookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    required String note,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        audiobookId = Value(audiobookId),
        chapterIndex = Value(chapterIndex),
        positionSeconds = Value(positionSeconds),
        note = Value(note);
  static Insertable<Bookmark> custom({
    Expression<String>? id,
    Expression<String>? audiobookId,
    Expression<int>? chapterIndex,
    Expression<int>? positionSeconds,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (audiobookId != null) 'audiobook_id': audiobookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith(
      {Value<String>? id,
      Value<String>? audiobookId,
      Value<int>? chapterIndex,
      Value<int>? positionSeconds,
      Value<String>? note,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return BookmarksCompanion(
      id: id ?? this.id,
      audiobookId: audiobookId ?? this.audiobookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (audiobookId.present) {
      map['audiobook_id'] = Variable<String>(audiobookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('audiobookId: $audiobookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WikipediaCacheTable extends WikipediaCache
    with TableInfo<$WikipediaCacheTable, WikipediaCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WikipediaCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cache_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
      'query', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _extractMeta =
      const VerificationMeta('extract');
  @override
  late final GeneratedColumn<String> extract = GeneratedColumn<String>(
      'extract', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pageUrlMeta =
      const VerificationMeta('pageUrl');
  @override
  late final GeneratedColumn<String> pageUrl = GeneratedColumn<String>(
      'page_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [cacheKey, query, title, extract, thumbnailUrl, pageUrl, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wikipedia_cache';
  @override
  VerificationContext validateIntegrity(Insertable<WikipediaCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(_cacheKeyMeta,
          cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('query')) {
      context.handle(
          _queryMeta, query.isAcceptableOrUnknown(data['query']!, _queryMeta));
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('extract')) {
      context.handle(_extractMeta,
          extract.isAcceptableOrUnknown(data['extract']!, _extractMeta));
    } else if (isInserting) {
      context.missing(_extractMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    }
    if (data.containsKey('page_url')) {
      context.handle(_pageUrlMeta,
          pageUrl.isAcceptableOrUnknown(data['page_url']!, _pageUrlMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  WikipediaCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WikipediaCacheData(
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      query: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}query'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      extract: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}extract'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url']),
      pageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}page_url']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $WikipediaCacheTable createAlias(String alias) {
    return $WikipediaCacheTable(attachedDatabase, alias);
  }
}

class WikipediaCacheData extends DataClass
    implements Insertable<WikipediaCacheData> {
  final String cacheKey;
  final String query;
  final String title;
  final String extract;
  final String? thumbnailUrl;
  final String? pageUrl;
  final DateTime cachedAt;
  const WikipediaCacheData(
      {required this.cacheKey,
      required this.query,
      required this.title,
      required this.extract,
      this.thumbnailUrl,
      this.pageUrl,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['query'] = Variable<String>(query);
    map['title'] = Variable<String>(title);
    map['extract'] = Variable<String>(extract);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || pageUrl != null) {
      map['page_url'] = Variable<String>(pageUrl);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  WikipediaCacheCompanion toCompanion(bool nullToAbsent) {
    return WikipediaCacheCompanion(
      cacheKey: Value(cacheKey),
      query: Value(query),
      title: Value(title),
      extract: Value(extract),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      pageUrl: pageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(pageUrl),
      cachedAt: Value(cachedAt),
    );
  }

  factory WikipediaCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WikipediaCacheData(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      query: serializer.fromJson<String>(json['query']),
      title: serializer.fromJson<String>(json['title']),
      extract: serializer.fromJson<String>(json['extract']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      pageUrl: serializer.fromJson<String?>(json['pageUrl']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'query': serializer.toJson<String>(query),
      'title': serializer.toJson<String>(title),
      'extract': serializer.toJson<String>(extract),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'pageUrl': serializer.toJson<String?>(pageUrl),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  WikipediaCacheData copyWith(
          {String? cacheKey,
          String? query,
          String? title,
          String? extract,
          Value<String?> thumbnailUrl = const Value.absent(),
          Value<String?> pageUrl = const Value.absent(),
          DateTime? cachedAt}) =>
      WikipediaCacheData(
        cacheKey: cacheKey ?? this.cacheKey,
        query: query ?? this.query,
        title: title ?? this.title,
        extract: extract ?? this.extract,
        thumbnailUrl:
            thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
        pageUrl: pageUrl.present ? pageUrl.value : this.pageUrl,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  WikipediaCacheData copyWithCompanion(WikipediaCacheCompanion data) {
    return WikipediaCacheData(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      query: data.query.present ? data.query.value : this.query,
      title: data.title.present ? data.title.value : this.title,
      extract: data.extract.present ? data.extract.value : this.extract,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      pageUrl: data.pageUrl.present ? data.pageUrl.value : this.pageUrl,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WikipediaCacheData(')
          ..write('cacheKey: $cacheKey, ')
          ..write('query: $query, ')
          ..write('title: $title, ')
          ..write('extract: $extract, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('pageUrl: $pageUrl, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      cacheKey, query, title, extract, thumbnailUrl, pageUrl, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WikipediaCacheData &&
          other.cacheKey == this.cacheKey &&
          other.query == this.query &&
          other.title == this.title &&
          other.extract == this.extract &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.pageUrl == this.pageUrl &&
          other.cachedAt == this.cachedAt);
}

class WikipediaCacheCompanion extends UpdateCompanion<WikipediaCacheData> {
  final Value<String> cacheKey;
  final Value<String> query;
  final Value<String> title;
  final Value<String> extract;
  final Value<String?> thumbnailUrl;
  final Value<String?> pageUrl;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const WikipediaCacheCompanion({
    this.cacheKey = const Value.absent(),
    this.query = const Value.absent(),
    this.title = const Value.absent(),
    this.extract = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.pageUrl = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WikipediaCacheCompanion.insert({
    required String cacheKey,
    required String query,
    required String title,
    required String extract,
    this.thumbnailUrl = const Value.absent(),
    this.pageUrl = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : cacheKey = Value(cacheKey),
        query = Value(query),
        title = Value(title),
        extract = Value(extract);
  static Insertable<WikipediaCacheData> custom({
    Expression<String>? cacheKey,
    Expression<String>? query,
    Expression<String>? title,
    Expression<String>? extract,
    Expression<String>? thumbnailUrl,
    Expression<String>? pageUrl,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (query != null) 'query': query,
      if (title != null) 'title': title,
      if (extract != null) 'extract': extract,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (pageUrl != null) 'page_url': pageUrl,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WikipediaCacheCompanion copyWith(
      {Value<String>? cacheKey,
      Value<String>? query,
      Value<String>? title,
      Value<String>? extract,
      Value<String?>? thumbnailUrl,
      Value<String?>? pageUrl,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return WikipediaCacheCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      query: query ?? this.query,
      title: title ?? this.title,
      extract: extract ?? this.extract,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      pageUrl: pageUrl ?? this.pageUrl,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (extract.present) {
      map['extract'] = Variable<String>(extract.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (pageUrl.present) {
      map['page_url'] = Variable<String>(pageUrl.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WikipediaCacheCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('query: $query, ')
          ..write('title: $title, ')
          ..write('extract: $extract, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('pageUrl: $pageUrl, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AudiobooksTable audiobooks = $AudiobooksTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $PlaybackProgressTable playbackProgress =
      $PlaybackProgressTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $WikipediaCacheTable wikipediaCache = $WikipediaCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [audiobooks, chapters, playbackProgress, bookmarks, wikipediaCache];
}

typedef $$AudiobooksTableCreateCompanionBuilder = AudiobooksCompanion Function({
  required String id,
  required String title,
  required String author,
  required String description,
  Value<String> source,
  Value<String?> coverUrl,
  Value<bool> isDownloaded,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$AudiobooksTableUpdateCompanionBuilder = AudiobooksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> author,
  Value<String> description,
  Value<String> source,
  Value<String?> coverUrl,
  Value<bool> isDownloaded,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$AudiobooksTableFilterComposer
    extends Composer<_$AppDatabase, $AudiobooksTable> {
  $$AudiobooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AudiobooksTableOrderingComposer
    extends Composer<_$AppDatabase, $AudiobooksTable> {
  $$AudiobooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AudiobooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudiobooksTable> {
  $$AudiobooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AudiobooksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AudiobooksTable,
    Audiobook,
    $$AudiobooksTableFilterComposer,
    $$AudiobooksTableOrderingComposer,
    $$AudiobooksTableAnnotationComposer,
    $$AudiobooksTableCreateCompanionBuilder,
    $$AudiobooksTableUpdateCompanionBuilder,
    (Audiobook, BaseReferences<_$AppDatabase, $AudiobooksTable, Audiobook>),
    Audiobook,
    PrefetchHooks Function()> {
  $$AudiobooksTableTableManager(_$AppDatabase db, $AudiobooksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudiobooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudiobooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudiobooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AudiobooksCompanion(
            id: id,
            title: title,
            author: author,
            description: description,
            source: source,
            coverUrl: coverUrl,
            isDownloaded: isDownloaded,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String author,
            required String description,
            Value<String> source = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AudiobooksCompanion.insert(
            id: id,
            title: title,
            author: author,
            description: description,
            source: source,
            coverUrl: coverUrl,
            isDownloaded: isDownloaded,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AudiobooksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AudiobooksTable,
    Audiobook,
    $$AudiobooksTableFilterComposer,
    $$AudiobooksTableOrderingComposer,
    $$AudiobooksTableAnnotationComposer,
    $$AudiobooksTableCreateCompanionBuilder,
    $$AudiobooksTableUpdateCompanionBuilder,
    (Audiobook, BaseReferences<_$AppDatabase, $AudiobooksTable, Audiobook>),
    Audiobook,
    PrefetchHooks Function()>;
typedef $$ChaptersTableCreateCompanionBuilder = ChaptersCompanion Function({
  required String id,
  required String audiobookId,
  required int chapterIndex,
  required String title,
  required String audioPathOrUrl,
  Value<int> durationSeconds,
  Value<bool> isStream,
  Value<int> rowid,
});
typedef $$ChaptersTableUpdateCompanionBuilder = ChaptersCompanion Function({
  Value<String> id,
  Value<String> audiobookId,
  Value<int> chapterIndex,
  Value<String> title,
  Value<String> audioPathOrUrl,
  Value<int> durationSeconds,
  Value<bool> isStream,
  Value<int> rowid,
});

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioPathOrUrl => $composableBuilder(
      column: $table.audioPathOrUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isStream => $composableBuilder(
      column: $table.isStream, builder: (column) => ColumnFilters(column));
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioPathOrUrl => $composableBuilder(
      column: $table.audioPathOrUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isStream => $composableBuilder(
      column: $table.isStream, builder: (column) => ColumnOrderings(column));
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get audioPathOrUrl => $composableBuilder(
      column: $table.audioPathOrUrl, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<bool> get isStream =>
      $composableBuilder(column: $table.isStream, builder: (column) => column);
}

class $$ChaptersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChaptersTable,
    Chapter,
    $$ChaptersTableFilterComposer,
    $$ChaptersTableOrderingComposer,
    $$ChaptersTableAnnotationComposer,
    $$ChaptersTableCreateCompanionBuilder,
    $$ChaptersTableUpdateCompanionBuilder,
    (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
    Chapter,
    PrefetchHooks Function()> {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> audiobookId = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> audioPathOrUrl = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<bool> isStream = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChaptersCompanion(
            id: id,
            audiobookId: audiobookId,
            chapterIndex: chapterIndex,
            title: title,
            audioPathOrUrl: audioPathOrUrl,
            durationSeconds: durationSeconds,
            isStream: isStream,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String audiobookId,
            required int chapterIndex,
            required String title,
            required String audioPathOrUrl,
            Value<int> durationSeconds = const Value.absent(),
            Value<bool> isStream = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChaptersCompanion.insert(
            id: id,
            audiobookId: audiobookId,
            chapterIndex: chapterIndex,
            title: title,
            audioPathOrUrl: audioPathOrUrl,
            durationSeconds: durationSeconds,
            isStream: isStream,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChaptersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChaptersTable,
    Chapter,
    $$ChaptersTableFilterComposer,
    $$ChaptersTableOrderingComposer,
    $$ChaptersTableAnnotationComposer,
    $$ChaptersTableCreateCompanionBuilder,
    $$ChaptersTableUpdateCompanionBuilder,
    (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
    Chapter,
    PrefetchHooks Function()>;
typedef $$PlaybackProgressTableCreateCompanionBuilder
    = PlaybackProgressCompanion Function({
  required String audiobookId,
  required int chapterIndex,
  required int positionSeconds,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$PlaybackProgressTableUpdateCompanionBuilder
    = PlaybackProgressCompanion Function({
  Value<String> audiobookId,
  Value<int> chapterIndex,
  Value<int> positionSeconds,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PlaybackProgressTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlaybackProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaybackProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackProgressTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaybackProgressTable,
    PlaybackProgressData,
    $$PlaybackProgressTableFilterComposer,
    $$PlaybackProgressTableOrderingComposer,
    $$PlaybackProgressTableAnnotationComposer,
    $$PlaybackProgressTableCreateCompanionBuilder,
    $$PlaybackProgressTableUpdateCompanionBuilder,
    (
      PlaybackProgressData,
      BaseReferences<_$AppDatabase, $PlaybackProgressTable,
          PlaybackProgressData>
    ),
    PlaybackProgressData,
    PrefetchHooks Function()> {
  $$PlaybackProgressTableTableManager(
      _$AppDatabase db, $PlaybackProgressTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> audiobookId = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<int> positionSeconds = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaybackProgressCompanion(
            audiobookId: audiobookId,
            chapterIndex: chapterIndex,
            positionSeconds: positionSeconds,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String audiobookId,
            required int chapterIndex,
            required int positionSeconds,
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaybackProgressCompanion.insert(
            audiobookId: audiobookId,
            chapterIndex: chapterIndex,
            positionSeconds: positionSeconds,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaybackProgressTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaybackProgressTable,
    PlaybackProgressData,
    $$PlaybackProgressTableFilterComposer,
    $$PlaybackProgressTableOrderingComposer,
    $$PlaybackProgressTableAnnotationComposer,
    $$PlaybackProgressTableCreateCompanionBuilder,
    $$PlaybackProgressTableUpdateCompanionBuilder,
    (
      PlaybackProgressData,
      BaseReferences<_$AppDatabase, $PlaybackProgressTable,
          PlaybackProgressData>
    ),
    PlaybackProgressData,
    PrefetchHooks Function()>;
typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  required String id,
  required String audiobookId,
  required int chapterIndex,
  required int positionSeconds,
  required String note,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<String> id,
  Value<String> audiobookId,
  Value<int> chapterIndex,
  Value<int> positionSeconds,
  Value<String> note,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get audiobookId => $composableBuilder(
      column: $table.audiobookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookmarksTable,
    Bookmark,
    $$BookmarksTableFilterComposer,
    $$BookmarksTableOrderingComposer,
    $$BookmarksTableAnnotationComposer,
    $$BookmarksTableCreateCompanionBuilder,
    $$BookmarksTableUpdateCompanionBuilder,
    (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
    Bookmark,
    PrefetchHooks Function()> {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> audiobookId = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<int> positionSeconds = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarksCompanion(
            id: id,
            audiobookId: audiobookId,
            chapterIndex: chapterIndex,
            positionSeconds: positionSeconds,
            note: note,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String audiobookId,
            required int chapterIndex,
            required int positionSeconds,
            required String note,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarksCompanion.insert(
            id: id,
            audiobookId: audiobookId,
            chapterIndex: chapterIndex,
            positionSeconds: positionSeconds,
            note: note,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BookmarksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookmarksTable,
    Bookmark,
    $$BookmarksTableFilterComposer,
    $$BookmarksTableOrderingComposer,
    $$BookmarksTableAnnotationComposer,
    $$BookmarksTableCreateCompanionBuilder,
    $$BookmarksTableUpdateCompanionBuilder,
    (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
    Bookmark,
    PrefetchHooks Function()>;
typedef $$WikipediaCacheTableCreateCompanionBuilder = WikipediaCacheCompanion
    Function({
  required String cacheKey,
  required String query,
  required String title,
  required String extract,
  Value<String?> thumbnailUrl,
  Value<String?> pageUrl,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});
typedef $$WikipediaCacheTableUpdateCompanionBuilder = WikipediaCacheCompanion
    Function({
  Value<String> cacheKey,
  Value<String> query,
  Value<String> title,
  Value<String> extract,
  Value<String?> thumbnailUrl,
  Value<String?> pageUrl,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$WikipediaCacheTableFilterComposer
    extends Composer<_$AppDatabase, $WikipediaCacheTable> {
  $$WikipediaCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get query => $composableBuilder(
      column: $table.query, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extract => $composableBuilder(
      column: $table.extract, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pageUrl => $composableBuilder(
      column: $table.pageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$WikipediaCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $WikipediaCacheTable> {
  $$WikipediaCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get query => $composableBuilder(
      column: $table.query, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extract => $composableBuilder(
      column: $table.extract, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pageUrl => $composableBuilder(
      column: $table.pageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$WikipediaCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $WikipediaCacheTable> {
  $$WikipediaCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get extract =>
      $composableBuilder(column: $table.extract, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<String> get pageUrl =>
      $composableBuilder(column: $table.pageUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$WikipediaCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WikipediaCacheTable,
    WikipediaCacheData,
    $$WikipediaCacheTableFilterComposer,
    $$WikipediaCacheTableOrderingComposer,
    $$WikipediaCacheTableAnnotationComposer,
    $$WikipediaCacheTableCreateCompanionBuilder,
    $$WikipediaCacheTableUpdateCompanionBuilder,
    (
      WikipediaCacheData,
      BaseReferences<_$AppDatabase, $WikipediaCacheTable, WikipediaCacheData>
    ),
    WikipediaCacheData,
    PrefetchHooks Function()> {
  $$WikipediaCacheTableTableManager(
      _$AppDatabase db, $WikipediaCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WikipediaCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WikipediaCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WikipediaCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cacheKey = const Value.absent(),
            Value<String> query = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> extract = const Value.absent(),
            Value<String?> thumbnailUrl = const Value.absent(),
            Value<String?> pageUrl = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WikipediaCacheCompanion(
            cacheKey: cacheKey,
            query: query,
            title: title,
            extract: extract,
            thumbnailUrl: thumbnailUrl,
            pageUrl: pageUrl,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cacheKey,
            required String query,
            required String title,
            required String extract,
            Value<String?> thumbnailUrl = const Value.absent(),
            Value<String?> pageUrl = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WikipediaCacheCompanion.insert(
            cacheKey: cacheKey,
            query: query,
            title: title,
            extract: extract,
            thumbnailUrl: thumbnailUrl,
            pageUrl: pageUrl,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WikipediaCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WikipediaCacheTable,
    WikipediaCacheData,
    $$WikipediaCacheTableFilterComposer,
    $$WikipediaCacheTableOrderingComposer,
    $$WikipediaCacheTableAnnotationComposer,
    $$WikipediaCacheTableCreateCompanionBuilder,
    $$WikipediaCacheTableUpdateCompanionBuilder,
    (
      WikipediaCacheData,
      BaseReferences<_$AppDatabase, $WikipediaCacheTable, WikipediaCacheData>
    ),
    WikipediaCacheData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AudiobooksTableTableManager get audiobooks =>
      $$AudiobooksTableTableManager(_db, _db.audiobooks);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(_db, _db.playbackProgress);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$WikipediaCacheTableTableManager get wikipediaCache =>
      $$WikipediaCacheTableTableManager(_db, _db.wikipediaCache);
}
