import 'dart:async';

import '../services/python_runtime.dart';
import 'notebook_model.dart';
import 'notebook_store.dart';

class NotebookController {
  NotebookController(this.document);

  final NotebookDocument document;

  int _executionCounter = 0;
  bool _disposed = false;
  final StreamController<NotebookDocument> _changes =
      StreamController<NotebookDocument>.broadcast();

  Stream<NotebookDocument> get changes => _changes.stream;

  bool get isDisposed => _disposed;

  void _notify() {
    if (!_disposed) _changes.add(document);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('Notebook controller has been disposed.');
    }
  }

  NotebookCell addCell({int? index, String source = ''}) {
    _ensureActive();

    final cell = NotebookCell(
      id: _cellId(),
      source: source,
    );

    final target = index == null
        ? document.cells.length
        : index.clamp(0, document.cells.length);

    document.cells.insert(target, cell);
    document.touch();
    _notify();
    return cell;
  }

  bool removeCell(String cellId) {
    _ensureActive();

    if (document.cells.length <= 1) return false;

    final oldLength = document.cells.length;
    document.cells.removeWhere((cell) => cell.id == cellId);
    final removed = document.cells.length != oldLength;

    if (removed) {
      document.touch();
      _notify();
    }
    return removed;
  }

  void updateSource(String cellId, String source) {
    _ensureActive();

    final cell = _findCell(cellId);
    cell.source = source;
    document.touch();
    _notify();
  }

  void moveCell(String cellId, int newIndex) {
    _ensureActive();

    final oldIndex = document.cells.indexWhere((cell) => cell.id == cellId);
    if (oldIndex < 0) throw StateError('Notebook cell not found.');

    final cell = document.cells.removeAt(oldIndex);
    final target = newIndex.clamp(0, document.cells.length);
    document.cells.insert(target, cell);

    document.touch();
    _notify();
  }

  Future<void> runCell(String cellId) async {
    _ensureActive();

    final cell = _findCell(cellId);
    if (cell.status == CellStatus.running) return;

    cell.status = CellStatus.running;
    cell.output = '';
    cell.error = '';
    cell.executionCount = ++_executionCounter;
    document.touch();
    _notify();

    try {
      final result = await PythonRuntime.instance.execute(cell.source);

      if (_disposed) return;

      cell.output = result.stdout;
      cell.error = result.stderr;

      if (result.status == PythonExecutionStatus.completed &&
          result.exitCode == 0) {
        cell.status = CellStatus.completed;
      } else {
        cell.status = CellStatus.failed;

        if (result.status == PythonExecutionStatus.timedOut) {
          cell.error = '${cell.error}\nExecution timed out.'.trim();
        } else if (result.exitCode != null && result.exitCode != 0) {
          cell.error =
              '${cell.error}\nProcess exited with code ${result.exitCode}.'
                  .trim();
        }
      }
    } catch (error) {
      if (_disposed) return;
      cell.status = CellStatus.failed;
      cell.error = error.toString();
    }

    document.touch();
    _notify();
    await save();
  }

  Future<void> runAll() async {
    _ensureActive();

    for (final cell in List<NotebookCell>.from(document.cells)) {
      if (_disposed) return;
      await runCell(cell.id);
    }
  }

  Future<void> save() async {
    _ensureActive();
    await NotebookStore.instance.save(document);
  }

  NotebookCell _findCell(String cellId) {
    return document.cells.firstWhere(
      (cell) => cell.id == cellId,
      orElse: () => throw StateError('Notebook cell not found: $cellId'),
    );
  }

  String _cellId() =>
      'cell_${DateTime.now().microsecondsSinceEpoch}_${_executionCounter++}';

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }
}
