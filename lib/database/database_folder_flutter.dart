import 'dart:io';

import '../core/app_data_directory.dart';

/// Where the app keeps its database (see [appDataDirectory]).
Future<Directory> defaultDatabaseFolder() => appDataDirectory();
