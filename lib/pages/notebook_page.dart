import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/python_runtime.dart';

class NotebookPage extends StatefulWidget {
  const NotebookPage({super.key});

  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  final cells = <TextEditingController>[
    TextEditingController(text: 'print("Hello from notebook")'),
  ];
  final outputs = <String>[];
  bool running = false;

  Future<File> get file async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory('${dir.path}/smapy-notebooks');
    await folder.create(recursive: true);
    return File('${folder.path}/notebook.json');
  }

  Future<void> save() async {
    final data = {
      'format': 'smapy-notebook',
      'version': 1,
      'cells': cells.map((c) => c.text).toList(),
    };
    await (await file).writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notebook saved locally')),
      );
    }
  }

  Future<void> load() async {
    try {
      final f = await file;
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final list = (data['cells'] as List).cast<String>();
      setState(() {
        for (final c in cells) {
          c.dispose();
        }
        cells
          ..clear()
          ..addAll(list.map((s) => TextEditingController(text: s)));
        outputs
          ..clear()
          ..addAll(List.filled(cells.length, ''));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e')),
        );
      }
    }
  }

  Future<void> runCell(int index) async {
    if (running) return;
    setState(() {
      running = true;
      while (outputs.length < cells.length) {
        outputs.add('');
      }
      outputs[index] = 'Running...';
    });
    try {
      final result = await PythonRuntime.instance.execute(cells[index].text);
      if (!mounted) return;
      setState(() {
        outputs[index] = [
          result.stdout,
          result.stderr,
          'Status: ${result.status.name}',
        ].where((s) => s.trim().isNotEmpty).join('\n');
      });
    } catch (e) {
      if (mounted) setState(() => outputs[index] = 'Runtime unavailable: $e');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  void dispose() {
    for (final c in cells) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('NOTEBOOK STUDIO',
                  style: TextStyle(color: Colors.white54, letterSpacing: 2)),
            ),
            IconButton(
              onPressed: load,
              icon: const Icon(Icons.folder_open),
              tooltip: 'Load notebook',
            ),
            IconButton(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save notebook',
            ),
          ],
        ),
        ...List.generate(cells.length, (i) => Card(
          color: const Color(0xFF101010),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('In [${i + 1}]'),
                    const Spacer(),
                    IconButton(
                      onPressed: () => runCell(i),
                      icon: const Icon(Icons.play_arrow),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          cells[i].dispose();
                          cells.removeAt(i);
                          if (i < outputs.length) outputs.removeAt(i);
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                TextField(
                  controller: cells[i],
                  minLines: 3,
                  maxLines: 12,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: const InputDecoration(hintText: 'Python code'),
                ),
                if (i < outputs.length && outputs[i].isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    color: Colors.black,
                    child: SelectableText(
                      outputs[i],
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
          ),
        )),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            cells.add(TextEditingController());
            outputs.add('');
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add code cell'),
        ),
        FilledButton(
          onPressed: running ? null : save,
          child: const Text('Save notebook'),
        ),
      ],
    );
  }
}
