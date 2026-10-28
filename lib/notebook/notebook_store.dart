import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'notebook_model.dart';

class NotebookStore {
  NotebookStore._();

  static final NotebookStore instance = NotebookStore._();

  Future<Directory> _directory() async {
    final appDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${appDirectory.path}/smapy-notebooks');
    await directory.create(recursive: true);
    return directory;
  }

  String _safeId(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid notebook ID.');
    }
    return id;
  }

  Future<File> _fileFor(String id) async {
    final directory = await _directory();
    return File('${directory.path}/${_safeId(id)}.smapy.json');
  }

  Future<void> save(NotebookDocument notebook) async {
    notebook.touch();

    final file = await _fileFor(notebook.id);
    final temporary = File('${file.path}.tmp');

    await temporary.writeAsString(notebook.encode(), flush: true);

    if (await file.exists()) {
      await file.delete();
    }

    await temporary.rename(file.path);
  }

  Future<NotebookDocument> load(String id) async {
    final file = await _fileFor(id);

    if (!await file.exists()) {
      throw FileSystemException('Notebook not found.', file.path);
    }

    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid notebook document.');
    }

    return NotebookDocument.fromJson(decoded);
  }

  Future<List<Map<String, dynamic>>> list() async {
    final directory = await _directory();
    final notebooks = <Map<String, dynamic>>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File ||
          !entity.path.endsWith('.smapy.json') ||
          entity.path.endsWith('.tmp')) {
        continue;
      }

      try {
        final decoded = jsonDecode(await entity.readAsString());

        if (decoded is Map<String, dynamic> &&
            decoded['format'] == 'smapy-notebook') {
          notebooks.add({
            'id': decoded['id'],
            'title': decoded['title'] ?? 'Untitled Notebook',
            'updatedAt': decoded['updatedAt'],
            'path': entity.path,
          });
        }
      } on FormatException {
        // Skip damaged files in the listing; do not delete user data.
      }
    }

    notebooks.sort((a, b) {
      final aDate = DateTime.tryParse(a['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return notebooks;
  }

  Future<void> delete(String id) async {
    final file = await _fileFor(id);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
