import 'package:flutter/material.dart';
import '../services/python_runtime.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final code = TextEditingController(
    text: 'print("Hello, SMAPY")\n',
  );

  String output = 'Ready.';
  bool running = false;

  Future<void> runCode() async {
    if (running) return;

    setState(() {
      running = true;
      output = 'Starting Python runtime...';
    });

    try {
      final result = await PythonRuntime.instance.execute(code.text);

      if (!mounted) return;
      setState(() {
        output = [
          if (result.stdout.trim().isNotEmpty) result.stdout.trimRight(),
          if (result.stderr.trim().isNotEmpty) result.stderr.trimRight(),
          'Status: ${result.status.name}',
          if (result.exitCode != null) 'Exit code: ${result.exitCode}',
        ].join('\n');

        if (output.isEmpty) output = 'Program finished without output.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => output = 'Python runtime unavailable:\n$e');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'PYTHON EDITOR',
          style: TextStyle(
            color: Colors.white54,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: code,
          minLines: 12,
          maxLines: 28,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            height: 1.5,
          ),
          decoration: const InputDecoration(
            hintText: '# Write Python code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: running ? null : runCode,
          icon: running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(running ? 'Running...' : 'Run Python'),
        ),
        const SizedBox(height: 22),
        const Text(
          'OUTPUT',
          style: TextStyle(
            color: Colors.white54,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: SelectableText(
            output,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
