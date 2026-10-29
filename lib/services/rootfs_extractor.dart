import 'dart:io';

import 'package:archive/archive.dart';

class ExtractionResult {
  const ExtractionResult({
    required this.rootfsPath,
    required this.extractedFiles,
    required this.extractedDirectories,
    required this.totalBytes,
  });

  final String rootfsPath;
  final int extractedFiles;
  final int extractedDirectories;
  final int totalBytes;
}

class RootfsExtractor {
  RootfsExtractor._();

  static final RootfsExtractor instance = RootfsExtractor._();

  bool _safeName(String name) {
    if (name.isEmpty || name.startsWith('/') || name.contains('\\')) {
      return false;
    }
    return !name.split('/').any((part) => part == '..' || part == '.');
  }

  String _linkTarget(String name, String target) {
    if (target.isEmpty || target.contains('\u0000') || target.contains('\\')) {
      throw FormatException('Invalid symbolic link: $name');
    }

    final parent = name.split('/')..removeLast();

    if (!target.startsWith('/')) {
      final resolved = <String>[...parent];
      for (final part in target.split('/')) {
        if (part.isEmpty || part == '.') continue;
        if (part == '..') {
          if (resolved.isEmpty) {
            throw FormatException('Symbolic link escapes rootfs: $name');
          }
          resolved.removeLast();
        } else {
          resolved.add(part);
        }
      }
      return target;
    }

    final absolute = <String>[];
    for (final part in target.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (absolute.isNotEmpty) absolute.removeLast();
      } else {
        absolute.add(part);
      }
    }

    var common = 0;
    while (common < parent.length &&
        common < absolute.length &&
        parent[common] == absolute[common]) {
      common++;
    }

    return [
      ...List<String>.filled(parent.length - common, '..'),
      ...absolute.skip(common),
    ].join('/');
  }

  Future<ExtractionResult> extractTarGz({
    required String archivePath,
    required String destinationPath,
    void Function(int completed, int total)? onProgress,
    int maxEntries = 200000,
    int maxExpandedBytes = 4 * 1024 * 1024 * 1024,
  }) async {
    final archiveFile = File(archivePath);
    if (!await archiveFile.exists()) {
      throw const FileSystemException('Root filesystem archive does not exist.');
    }

    final destination = Directory(destinationPath);
    if (await destination.exists()) {
      throw FileSystemException('Destination already exists.', destinationPath);
    }

    final parent = destination.parent;
    await parent.create(recursive: true);
    final staging = Directory(
      '${parent.path}/.${destination.uri.pathSegments.last}.staging',
    );

    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    var files = 0;
    var directories = 0;
    var expandedBytes = 0;

    try {
      final compressed = await archiveFile.readAsBytes();
      final tarBytes = GZipDecoder().decodeBytes(compressed);
      final entries = TarDecoder().decodeBytes(tarBytes);

      if (entries.length > maxEntries) {
        throw const FormatException('Too many archive entries.');
      }

      final base = staging.absolute.path;
      final pendingLinks = <ArchiveFile>[];

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final originalName = entry.name;
        final isDirectory = originalName.endsWith('/');
        var name = originalName.replaceFirst(RegExp(r'/+$'), '');
        while (name == '.' || name.startsWith('./')) {
          if (name == '.') {
            name = '';
            break;
          }
          name = name.substring(2);
        }

        if (name.isEmpty) {
          onProgress?.call(i + 1, entries.length);
          continue;
        }
        if (!_safeName(name)) {
          throw FormatException('Unsafe archive path: $name');
        }

        final outputPath = '$base${Platform.pathSeparator}$name';
        if (!outputPath.startsWith('$base${Platform.pathSeparator}')) {
          throw FormatException('Path escapes staging: $name');
        }

        if (entry.isSymbolicLink) {
          pendingLinks.add(entry);
        } else if (entry.isFile) {
          final content = entry.content;
          if (content is! List<int>) {
            throw FormatException('Invalid file: $name');
          }

          expandedBytes += content.length;
          if (expandedBytes > maxExpandedBytes) {
            throw const FormatException('Expanded archive exceeds size limit.');
          }

          final output = File(outputPath);
          await output.parent.create(recursive: true);
          await output.writeAsBytes(content, flush: false);
          files++;
        } else if (isDirectory) {
          await Directory(outputPath).create(recursive: true);
          directories++;
        } else {
          throw FormatException('Unsupported archive entry: $name');
        }

        onProgress?.call(i + 1, entries.length);
      }

      // Create links last, so they cannot redirect extraction writes.
      for (final entry in pendingLinks) {
        var name = entry.name.replaceFirst(RegExp(r'/+$'), '');
        while (name.startsWith('./')) {
          name = name.substring(2);
        }
        if (name.isEmpty || !_safeName(name)) {
          throw FormatException('Unsafe symbolic link path: $name');
        }

        final rawTarget = entry.nameOfLinkedFile;
        final safeTarget = _linkTarget(name, rawTarget);
        final outputPath = '$base${Platform.pathSeparator}$name';

        await Directory(File(outputPath).parent.path).create(recursive: true);
        await Link(outputPath).create(safeTarget);
      }

      await staging.rename(destination.path);

      return ExtractionResult(
        rootfsPath: destination.path,
        extractedFiles: files,
        extractedDirectories: directories,
        totalBytes: expandedBytes,
      );
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }
}
