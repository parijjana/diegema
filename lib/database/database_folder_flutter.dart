import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the app keeps its database (the app's documents folder).
Future<Directory> defaultDatabaseFolder() => getApplicationDocumentsDirectory();
