import 'dart:io';

/// Outside Flutter (the `diegema-sync` CLI) there is no default: the CLI
/// always opens the database by path.
Future<Directory> defaultDatabaseFolder() =>
    throw UnsupportedError('no default database folder outside the app');
