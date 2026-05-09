import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

import '../models/study_session.dart';

/// Creates a ZIP of all files in [session]'s directory, writes it to
/// the system temp folder, and returns the zip file path.
Future<String> buildSessionZip(StudySession session) async {
  final tmp = await getTemporaryDirectory();
  final zipPath = '${tmp.path}/${session.sessionId}.zip';

  final encoder = ZipFileEncoder();
  encoder.create(zipPath);

  final dir = Directory(session.directoryPath);
  if (dir.existsSync()) {
    for (final f in dir.listSync().whereType<File>()) {
      await encoder.addFile(f);
    }
  }
  encoder.close();
  return zipPath;
}
