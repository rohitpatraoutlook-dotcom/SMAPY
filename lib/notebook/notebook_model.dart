import 'dart:convert';

enum CellStatus {
  idle,
  running,
  completed,
  failed,
}

class NotebookCell {
  NotebookCell({
    required this.id,
    this.source = '',
    this.output = '',
    this.error = '',
    this.executionCount,
    this.status = CellStatus.idle,
  });

  final String id;
  String source;
  String output;
  String error;
  int? executionCount;
  CellStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'output': output,
        'error': error,
        'executionCount': executionCount,
        'status': status.name,
      };

  factory NotebookCell.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'idle';

    return NotebookCell(
      id: json['id'] as String? ?? _newId(),
      source: json['source'] as String? ?? '',
      output: json['output'] as String? ?? '',
      error: json['error'] as String? ?? '',
      executionCount: json['executionCount'] is int
          ? json['executionCount'] as int
          : null,
      status: CellStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => CellStatus.idle,
      ),
    );
  }
}

class NotebookDocument {
  NotebookDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<NotebookCell>? cells,
    this.formatVersion = 1,
  }) : cells = cells ?? [NotebookCell(id: _newId())];

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final int formatVersion;
  final List<NotebookCell> cells;

  factory NotebookDocument.create({String title = 'Untitled Notebook'}) {
    final now = DateTime.now().toUtc();

    return NotebookDocument(
      id: _newId(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': 'smapy-notebook',
        'formatVersion': formatVersion,
        'id': id,
        'title': title,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'cells': cells.map((cell) => cell.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory NotebookDocument.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'smapy-notebook') {
      throw const FormatException('This is not a SMAPY notebook file.');
    }

    final version = json['formatVersion'];
    if (version != 1) {
      throw FormatException('Unsupported notebook format version: $version');
    }

    final rawCells = json['cells'];
    if (rawCells is! List) {
      throw const FormatException('Notebook cells are missing or invalid.');
    }

    final cells = rawCells.map((rawCell) {
      if (rawCell is! Map<String, dynamic>) {
        throw const FormatException('Invalid notebook cell.');
      }
      return NotebookCell.fromJson(rawCell);
    }).toList();

    return NotebookDocument(
      id: json['id'] as String? ?? _newId(),
      title: json['title'] as String? ?? 'Untitled Notebook',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      cells: cells,
      formatVersion: version as int,
    );
  }

  void touch() {
    updatedAt = DateTime.now().toUtc();
  }
}

String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

int _idCounter = 0;
