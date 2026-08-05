// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database_io.dart';

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
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
      'origin', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(BookIdentity.originLocal));
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _userCoverPathMeta =
      const VerificationMeta('userCoverPath');
  @override
  late final GeneratedColumn<String> userCoverPath = GeneratedColumn<String>(
      'user_cover_path', aliasedName, true,
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
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _pinOrderMeta =
      const VerificationMeta('pinOrder');
  @override
  late final GeneratedColumn<int> pinOrder = GeneratedColumn<int>(
      'pin_order', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _hiddenFromContinueMeta =
      const VerificationMeta('hiddenFromContinue');
  @override
  late final GeneratedColumn<bool> hiddenFromContinue = GeneratedColumn<bool>(
      'hidden_from_continue', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("hidden_from_continue" IN (0, 1))'),
      defaultValue: const Constant(false));
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
        origin,
        coverUrl,
        userCoverPath,
        isDownloaded,
        isPinned,
        pinOrder,
        hiddenFromContinue,
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
    if (data.containsKey('origin')) {
      context.handle(_originMeta,
          origin.isAcceptableOrUnknown(data['origin']!, _originMeta));
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('user_cover_path')) {
      context.handle(
          _userCoverPathMeta,
          userCoverPath.isAcceptableOrUnknown(
              data['user_cover_path']!, _userCoverPathMeta));
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
          _isDownloadedMeta,
          isDownloaded.isAcceptableOrUnknown(
              data['is_downloaded']!, _isDownloadedMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('pin_order')) {
      context.handle(_pinOrderMeta,
          pinOrder.isAcceptableOrUnknown(data['pin_order']!, _pinOrderMeta));
    }
    if (data.containsKey('hidden_from_continue')) {
      context.handle(
          _hiddenFromContinueMeta,
          hiddenFromContinue.isAcceptableOrUnknown(
              data['hidden_from_continue']!, _hiddenFromContinueMeta));
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
      origin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}origin'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      userCoverPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_cover_path']),
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      pinOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pin_order']),
      hiddenFromContinue: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}hidden_from_continue'])!,
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

  /// Where the book came from: `'librivox'` or `'local'`. See
  /// `core/utils/book_identity.dart`. Added in schema v2; defaults to
  /// `'local'` for both fresh installs and the v1->v2 backfill of rows
  /// whose true origin cannot be inferred.
  final String origin;
  final String? coverUrl;

  /// User-supplied cover art path (schema v2). Takes precedence over
  /// [coverUrl] / the procedural cover whenever set — see
  /// `ui_redesign_plan.md` Screen 2. Nothing writes this column yet; the
  /// column and DAO methods exist ahead of the UI that sets it.
  final String? userCoverPath;
  final bool isDownloaded;

  /// Pinned to the "Now Playing" default screen (schema v2). Max 5,
  /// enforced in [AppDatabase.pinBook] — never silently evicted.
  final bool isPinned;

  /// Stable sort key among pinned books, ascending. `null` when not
  /// pinned. Not a dense 0..4 sequence — gaps are fine, only relative
  /// order matters — so unpinning never has to renumber siblings.
  final int? pinOrder;

  /// Dismissed from the "continue listening" surface (schema v2). Does
  /// NOT delete the book or its [PlaybackProgress] row; it only affects
  /// [AppDatabase.getContinueListening]'s WHERE clause.
  final bool hiddenFromContinue;
  final DateTime createdAt;
  const Audiobook(
      {required this.id,
      required this.title,
      required this.author,
      required this.description,
      required this.source,
      required this.origin,
      this.coverUrl,
      this.userCoverPath,
      required this.isDownloaded,
      required this.isPinned,
      this.pinOrder,
      required this.hiddenFromContinue,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['description'] = Variable<String>(description);
    map['source'] = Variable<String>(source);
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || userCoverPath != null) {
      map['user_cover_path'] = Variable<String>(userCoverPath);
    }
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || pinOrder != null) {
      map['pin_order'] = Variable<int>(pinOrder);
    }
    map['hidden_from_continue'] = Variable<bool>(hiddenFromContinue);
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
      origin: Value(origin),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      userCoverPath: userCoverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(userCoverPath),
      isDownloaded: Value(isDownloaded),
      isPinned: Value(isPinned),
      pinOrder: pinOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(pinOrder),
      hiddenFromContinue: Value(hiddenFromContinue),
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
      origin: serializer.fromJson<String>(json['origin']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      userCoverPath: serializer.fromJson<String?>(json['userCoverPath']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      pinOrder: serializer.fromJson<int?>(json['pinOrder']),
      hiddenFromContinue: serializer.fromJson<bool>(json['hiddenFromContinue']),
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
      'origin': serializer.toJson<String>(origin),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'userCoverPath': serializer.toJson<String?>(userCoverPath),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'isPinned': serializer.toJson<bool>(isPinned),
      'pinOrder': serializer.toJson<int?>(pinOrder),
      'hiddenFromContinue': serializer.toJson<bool>(hiddenFromContinue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Audiobook copyWith(
          {String? id,
          String? title,
          String? author,
          String? description,
          String? source,
          String? origin,
          Value<String?> coverUrl = const Value.absent(),
          Value<String?> userCoverPath = const Value.absent(),
          bool? isDownloaded,
          bool? isPinned,
          Value<int?> pinOrder = const Value.absent(),
          bool? hiddenFromContinue,
          DateTime? createdAt}) =>
      Audiobook(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        description: description ?? this.description,
        source: source ?? this.source,
        origin: origin ?? this.origin,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        userCoverPath:
            userCoverPath.present ? userCoverPath.value : this.userCoverPath,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        isPinned: isPinned ?? this.isPinned,
        pinOrder: pinOrder.present ? pinOrder.value : this.pinOrder,
        hiddenFromContinue: hiddenFromContinue ?? this.hiddenFromContinue,
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
      origin: data.origin.present ? data.origin.value : this.origin,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      userCoverPath: data.userCoverPath.present
          ? data.userCoverPath.value
          : this.userCoverPath,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      pinOrder: data.pinOrder.present ? data.pinOrder.value : this.pinOrder,
      hiddenFromContinue: data.hiddenFromContinue.present
          ? data.hiddenFromContinue.value
          : this.hiddenFromContinue,
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
          ..write('origin: $origin, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('userCoverPath: $userCoverPath, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinOrder: $pinOrder, ')
          ..write('hiddenFromContinue: $hiddenFromContinue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      author,
      description,
      source,
      origin,
      coverUrl,
      userCoverPath,
      isDownloaded,
      isPinned,
      pinOrder,
      hiddenFromContinue,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Audiobook &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.description == this.description &&
          other.source == this.source &&
          other.origin == this.origin &&
          other.coverUrl == this.coverUrl &&
          other.userCoverPath == this.userCoverPath &&
          other.isDownloaded == this.isDownloaded &&
          other.isPinned == this.isPinned &&
          other.pinOrder == this.pinOrder &&
          other.hiddenFromContinue == this.hiddenFromContinue &&
          other.createdAt == this.createdAt);
}

class AudiobooksCompanion extends UpdateCompanion<Audiobook> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String> description;
  final Value<String> source;
  final Value<String> origin;
  final Value<String?> coverUrl;
  final Value<String?> userCoverPath;
  final Value<bool> isDownloaded;
  final Value<bool> isPinned;
  final Value<int?> pinOrder;
  final Value<bool> hiddenFromContinue;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AudiobooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.source = const Value.absent(),
    this.origin = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.userCoverPath = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinOrder = const Value.absent(),
    this.hiddenFromContinue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudiobooksCompanion.insert({
    required String id,
    required String title,
    required String author,
    required String description,
    this.source = const Value.absent(),
    this.origin = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.userCoverPath = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinOrder = const Value.absent(),
    this.hiddenFromContinue = const Value.absent(),
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
    Expression<String>? origin,
    Expression<String>? coverUrl,
    Expression<String>? userCoverPath,
    Expression<bool>? isDownloaded,
    Expression<bool>? isPinned,
    Expression<int>? pinOrder,
    Expression<bool>? hiddenFromContinue,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (source != null) 'source': source,
      if (origin != null) 'origin': origin,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (userCoverPath != null) 'user_cover_path': userCoverPath,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (isPinned != null) 'is_pinned': isPinned,
      if (pinOrder != null) 'pin_order': pinOrder,
      if (hiddenFromContinue != null)
        'hidden_from_continue': hiddenFromContinue,
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
      Value<String>? origin,
      Value<String?>? coverUrl,
      Value<String?>? userCoverPath,
      Value<bool>? isDownloaded,
      Value<bool>? isPinned,
      Value<int?>? pinOrder,
      Value<bool>? hiddenFromContinue,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AudiobooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      source: source ?? this.source,
      origin: origin ?? this.origin,
      coverUrl: coverUrl ?? this.coverUrl,
      userCoverPath: userCoverPath ?? this.userCoverPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isPinned: isPinned ?? this.isPinned,
      pinOrder: pinOrder ?? this.pinOrder,
      hiddenFromContinue: hiddenFromContinue ?? this.hiddenFromContinue,
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
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (userCoverPath.present) {
      map['user_cover_path'] = Variable<String>(userCoverPath.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (pinOrder.present) {
      map['pin_order'] = Variable<int>(pinOrder.value);
    }
    if (hiddenFromContinue.present) {
      map['hidden_from_continue'] = Variable<bool>(hiddenFromContinue.value);
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
          ..write('origin: $origin, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('userCoverPath: $userCoverPath, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinOrder: $pinOrder, ')
          ..write('hiddenFromContinue: $hiddenFromContinue, ')
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
  static const VerificationMeta _endPositionSecondsMeta =
      const VerificationMeta('endPositionSeconds');
  @override
  late final GeneratedColumn<int> endPositionSeconds = GeneratedColumn<int>(
      'end_position_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
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
  List<GeneratedColumn> get $columns => [
        id,
        audiobookId,
        chapterIndex,
        positionSeconds,
        endPositionSeconds,
        title,
        note,
        createdAt
      ];
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
    if (data.containsKey('end_position_seconds')) {
      context.handle(
          _endPositionSecondsMeta,
          endPositionSeconds.isAcceptableOrUnknown(
              data['end_position_seconds']!, _endPositionSecondsMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
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
      endPositionSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}end_position_seconds']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
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

  /// Clip end, in seconds. `null` means this row is a point bookmark, not
  /// a clip (schema v2).
  final int? endPositionSeconds;

  /// Short user-given name, distinct from the free-text [note] (schema
  /// v2). Defaults to `''` so existing/legacy rows never have a null
  /// title to render.
  final String title;
  final String note;
  final DateTime createdAt;
  const Bookmark(
      {required this.id,
      required this.audiobookId,
      required this.chapterIndex,
      required this.positionSeconds,
      this.endPositionSeconds,
      required this.title,
      required this.note,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['audiobook_id'] = Variable<String>(audiobookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['position_seconds'] = Variable<int>(positionSeconds);
    if (!nullToAbsent || endPositionSeconds != null) {
      map['end_position_seconds'] = Variable<int>(endPositionSeconds);
    }
    map['title'] = Variable<String>(title);
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
      endPositionSeconds: endPositionSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(endPositionSeconds),
      title: Value(title),
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
      endPositionSeconds: serializer.fromJson<int?>(json['endPositionSeconds']),
      title: serializer.fromJson<String>(json['title']),
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
      'endPositionSeconds': serializer.toJson<int?>(endPositionSeconds),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bookmark copyWith(
          {String? id,
          String? audiobookId,
          int? chapterIndex,
          int? positionSeconds,
          Value<int?> endPositionSeconds = const Value.absent(),
          String? title,
          String? note,
          DateTime? createdAt}) =>
      Bookmark(
        id: id ?? this.id,
        audiobookId: audiobookId ?? this.audiobookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        endPositionSeconds: endPositionSeconds.present
            ? endPositionSeconds.value
            : this.endPositionSeconds,
        title: title ?? this.title,
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
      endPositionSeconds: data.endPositionSeconds.present
          ? data.endPositionSeconds.value
          : this.endPositionSeconds,
      title: data.title.present ? data.title.value : this.title,
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
          ..write('endPositionSeconds: $endPositionSeconds, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, audiobookId, chapterIndex,
      positionSeconds, endPositionSeconds, title, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.audiobookId == this.audiobookId &&
          other.chapterIndex == this.chapterIndex &&
          other.positionSeconds == this.positionSeconds &&
          other.endPositionSeconds == this.endPositionSeconds &&
          other.title == this.title &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> id;
  final Value<String> audiobookId;
  final Value<int> chapterIndex;
  final Value<int> positionSeconds;
  final Value<int?> endPositionSeconds;
  final Value<String> title;
  final Value<String> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.audiobookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.endPositionSeconds = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    this.endPositionSeconds = const Value.absent(),
    this.title = const Value.absent(),
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
    Expression<int>? endPositionSeconds,
    Expression<String>? title,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (audiobookId != null) 'audiobook_id': audiobookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (endPositionSeconds != null)
        'end_position_seconds': endPositionSeconds,
      if (title != null) 'title': title,
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
      Value<int?>? endPositionSeconds,
      Value<String>? title,
      Value<String>? note,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return BookmarksCompanion(
      id: id ?? this.id,
      audiobookId: audiobookId ?? this.audiobookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      endPositionSeconds: endPositionSeconds ?? this.endPositionSeconds,
      title: title ?? this.title,
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
    if (endPositionSeconds.present) {
      map['end_position_seconds'] = Variable<int>(endPositionSeconds.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
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
          ..write('endPositionSeconds: $endPositionSeconds, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
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
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [audiobooks, chapters, playbackProgress, bookmarks];
}

typedef $$AudiobooksTableCreateCompanionBuilder = AudiobooksCompanion Function({
  required String id,
  required String title,
  required String author,
  required String description,
  Value<String> source,
  Value<String> origin,
  Value<String?> coverUrl,
  Value<String?> userCoverPath,
  Value<bool> isDownloaded,
  Value<bool> isPinned,
  Value<int?> pinOrder,
  Value<bool> hiddenFromContinue,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$AudiobooksTableUpdateCompanionBuilder = AudiobooksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> author,
  Value<String> description,
  Value<String> source,
  Value<String> origin,
  Value<String?> coverUrl,
  Value<String?> userCoverPath,
  Value<bool> isDownloaded,
  Value<bool> isPinned,
  Value<int?> pinOrder,
  Value<bool> hiddenFromContinue,
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

  ColumnFilters<String> get origin => $composableBuilder(
      column: $table.origin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userCoverPath => $composableBuilder(
      column: $table.userCoverPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pinOrder => $composableBuilder(
      column: $table.pinOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hiddenFromContinue => $composableBuilder(
      column: $table.hiddenFromContinue,
      builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get origin => $composableBuilder(
      column: $table.origin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userCoverPath => $composableBuilder(
      column: $table.userCoverPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pinOrder => $composableBuilder(
      column: $table.pinOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hiddenFromContinue => $composableBuilder(
      column: $table.hiddenFromContinue,
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

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get userCoverPath => $composableBuilder(
      column: $table.userCoverPath, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get pinOrder =>
      $composableBuilder(column: $table.pinOrder, builder: (column) => column);

  GeneratedColumn<bool> get hiddenFromContinue => $composableBuilder(
      column: $table.hiddenFromContinue, builder: (column) => column);

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
            Value<String> origin = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> userCoverPath = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<int?> pinOrder = const Value.absent(),
            Value<bool> hiddenFromContinue = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AudiobooksCompanion(
            id: id,
            title: title,
            author: author,
            description: description,
            source: source,
            origin: origin,
            coverUrl: coverUrl,
            userCoverPath: userCoverPath,
            isDownloaded: isDownloaded,
            isPinned: isPinned,
            pinOrder: pinOrder,
            hiddenFromContinue: hiddenFromContinue,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String author,
            required String description,
            Value<String> source = const Value.absent(),
            Value<String> origin = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> userCoverPath = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<int?> pinOrder = const Value.absent(),
            Value<bool> hiddenFromContinue = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AudiobooksCompanion.insert(
            id: id,
            title: title,
            author: author,
            description: description,
            source: source,
            origin: origin,
            coverUrl: coverUrl,
            userCoverPath: userCoverPath,
            isDownloaded: isDownloaded,
            isPinned: isPinned,
            pinOrder: pinOrder,
            hiddenFromContinue: hiddenFromContinue,
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
  Value<int?> endPositionSeconds,
  Value<String> title,
  required String note,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<String> id,
  Value<String> audiobookId,
  Value<int> chapterIndex,
  Value<int> positionSeconds,
  Value<int?> endPositionSeconds,
  Value<String> title,
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

  ColumnFilters<int> get endPositionSeconds => $composableBuilder(
      column: $table.endPositionSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<int> get endPositionSeconds => $composableBuilder(
      column: $table.endPositionSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<int> get endPositionSeconds => $composableBuilder(
      column: $table.endPositionSeconds, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

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
            Value<int?> endPositionSeconds = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarksCompanion(
            id: id,
            audiobookId: audiobookId,
            chapterIndex: chapterIndex,
            positionSeconds: positionSeconds,
            endPositionSeconds: endPositionSeconds,
            title: title,
            note: note,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String audiobookId,
            required int chapterIndex,
            required int positionSeconds,
            Value<int?> endPositionSeconds = const Value.absent(),
            Value<String> title = const Value.absent(),
            required String note,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarksCompanion.insert(
            id: id,
            audiobookId: audiobookId,
            chapterIndex: chapterIndex,
            positionSeconds: positionSeconds,
            endPositionSeconds: endPositionSeconds,
            title: title,
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
}
