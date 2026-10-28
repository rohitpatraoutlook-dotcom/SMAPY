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
    if (name.isEmpty ||
        name.startsWith('/') ||
        name.contains('\\')) {
      return false;
    }

    return !name.split('/').any(
      (part) => part == '..' || part == '.',
    );
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
      throw const FileSystemException(
        'Root filesystem archive does not exist.',
      );
    }

    final destination = Directory(destinationPath);

    if (await destination.exists()) {
      throw FileSystemException(
        'Destination must not already exist.',
        destinationPath,
      );
    }

    final parent = destination.parent;
    await parent.create(recursive: true);

    final staging = Directory(
      '${parent.path}/.${destination.uri.pathSegments.last}.staging',
    );

    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }

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
        final name = entry.name.replaceFirst(RegExp(r'/+$'), '');

        if (name.isEmpty) {
          onProgress?.call(i + 1, entries.length);
          continue;
        }

        if (!_safeName(name)) {
          throw FormatException('Unsafe archive path: $name');
        }

        final outputPath =
            '$base${Platform.pathSeparator}$name';

        final output = File(outputPath);
        final directory = Directory(outputPath);

        if (!output.absolute.path.startsWith(
          '$base${Platform.pathSeparator}',
        )) {
          throw FormatException('Path escapes staging: $name');
        }

        if (entry.isSymbolicLink) {
          pendingLinks.add(entry);
          onProgress?.call(i + 1, entries.length);
          continue;
        }

        if (entry.isLink) {
          throw FormatException(
            'Hard links are not supported: $name',
          );
        }

        if (entry.isDirectory) {
          await directory.create(recursive: true);
          directories++;
        } else if (entry.isFile) {
          final content = entry.content;

          if (content is! List<int>) {
            throw FormatException('Invalid file: $name');
          }

          expandedBytes += content.length;

          if (expandedBytes > maxExpandedBytes) {
            throw const FormatException(
              'Expanded archive exceeds size limit.',
            );
          }

          await output.parent.create(recursive: true);
          await output.writeAsBytes(content, flush: false);
          files++;
        } else {
          throw FormatException(
            'Unsupported archive entry: $name',
          );
        }

        onProgress?.call(i + 1, entries.length);
      }

      // Create links only after ordinary files have been extracted.
      for (final entry in pendingLinks) {
        final name = entry.name.replaceFirst(RegExp(r'/+$'), '');
        final linkTarget = entry.name == name
            ? entry.name
            : entry.name;

        final target = entry.name == name
            ? entry.name
            : linkTarget;

        final outputPath =
            '$base${Platform.pathSeparator}$name';

        // Archive package versions expose the link target as linkName.
        throw FormatException('Symbolic link extraction requires API verification: $name');

        if (rawTarget.isEmpty || rawTarget.contains('\u0000')) {
          throw FormatException('Invalid symbolic link: $name');
        }

        // Reject relative links that escape the root filesystem.
        if (!rawTarget.startsWith('/')) {
          final segments = <String>[
            ...name.split('/')..removeLast(),
            ...rawTarget.split('/'),
          ];
          var depth = 0;

          for (final segment in segments) {
            if (segment.isEmpty || segment == '.') continue;
            if (segment == '..') {
              depth--;
            } else {
              depth++;
            }
            if (depth < 0) {
              throw FormatException(
                'Symbolic link escapes rootfs: $name',
              );
            }
          }
        }

        // Symbolic links are intentionally not created until validated.
      }

      await staging.rename(destination.path);

      return ExtractionResult(
        rootfsPath: destination.path,
        extractedFiles: files,
        extractedDirectories: directories,
        totalBytes: expandedBytes,
      );
    } catch (_) {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }
  }
}
