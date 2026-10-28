import 'dart:async';
import 'package:flutter/material.dart';
import '../services/linux_launcher.dart';
import '../services/runtime_process.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final lines = <String>[];
  StreamSubscription<RuntimeOutput>? subscription;
  bool starting = false;
  bool connected = false;

  @override
  void initState() {
    super.initState();
    lines.add('SMAPY Terminal');
    lines.add('Linux runtime must be installed before commands can run.');
    subscription = RuntimeProcess.instance.output.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event.text.isNotEmpty) lines.add(event.text);
        if (event.type == 'exit') {
          lines.add('[process exited: ${event.exitCode}]');
          connected = false;
        }
      });
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> connect() async {
    if (starting || connected) return;
    setState(() {
      starting = true;
      lines.add('\$ starting Linux shell...');
    });
    try {
      final session = await LinuxLauncher.instance.start();
      if (!mounted) return;
      setState(() {
        connected = session.isRunning;
        lines.add(connected
            ? '[Linux shell started]'
            : '[Linux shell did not start]');
      });
    } catch (e) {
      if (mounted) {
        setState(() => lines.add('[Runtime unavailable] $e'));
      }
    } finally {
      if (mounted) setState(() => starting = false);
      _scrollToEnd();
    }
  }

  Future<void> sendCommand() async {
    final command = input.text.trim();
    if (command.isEmpty) return;
    input.clear();

    setState(() => lines.add('\$ $command'));

    if (!connected) {
      setState(() => lines.add(
          'No active shell. Tap Connect after installing the Linux runtime.'));
      return;
    }

    try {
      await LinuxLauncher.instance.sendInput('$command\n');
    } catch (e) {
      if (mounted) setState(() => lines.add('[Command error] $e'));
    }
    _scrollToEnd();
  }

  @override
  void dispose() {
    subscription?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('LINUX TERMINAL',
                    style: TextStyle(
                        color: Colors.white54, letterSpacing: 2)),
              ),
              OutlinedButton.icon(
                onPressed: starting || connected ? null : connect,
                icon: const Icon(Icons.link),
                label: Text(starting ? 'Connecting' : 'Connect'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF080808),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: ListView.builder(
                controller: scroll,
                itemCount: lines.length,
                itemBuilder: (_, i) => SelectableText(
                  lines[i],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('\$ ', style: TextStyle(fontFamily: 'monospace')),
              Expanded(
                child: TextField(
                  controller: input,
                  enabled: connected,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText: 'Enter command',
                    isDense: true,
                  ),
                  onSubmitted: (_) => sendCommand(),
                ),
              ),
              IconButton(
                onPressed: connected ? sendCommand : null,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
