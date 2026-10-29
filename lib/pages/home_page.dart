import 'package:flutter/material.dart';
import '../services/runtime_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RuntimeManager _runtimeManager = RuntimeManager.instance;

  RuntimeSnapshot _snapshot = RuntimeManager.instance.snapshot;
  bool _preparingRuntime = false;

  String get _runtimeMessage => _snapshot.message;

  @override
  void initState() {
    super.initState();
    _initializeRuntime();
  }

  Future<void> _initializeRuntime() async {
    if (_preparingRuntime) return;

    setState(() {
      _preparingRuntime = true;
    });

    final result = await _runtimeManager.initialize();

    if (!mounted) return;
    setState(() {
      _snapshot = result;
      _preparingRuntime = false;
    });
  }

  Future<void> _prepareRuntime() async {
    if (_preparingRuntime) return;

    setState(() {
      _preparingRuntime = true;
    });

    final result = await _runtimeManager.installLinux();

    if (!mounted) return;
    setState(() {
      _snapshot = result;
      _preparingRuntime = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final linuxReady = _snapshot.isLinuxReady;

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 25),
        const Text(
          'YOUR MOBILE WORKSTATION',
          style: TextStyle(color: Colors.white54, letterSpacing: 2),
        ),
        const SizedBox(height: 18),
        const Text(
          'Code without\ncompromise.',
          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        const Text(
          'Python development, built for your phone.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.terminal, size: 30),
              const SizedBox(height: 20),
              const Text(
                'print("Hello, SMAPY")',
                style: TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 20),
              Text(
                linuxReady ? 'Linux runtime ready' : 'Linux runtime setup',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              const Text(
                'Runtime status',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                _runtimeMessage,
                style: const TextStyle(color: Colors.white54),
              ),
              if (_snapshot.androidVersion != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Android ${_snapshot.androidVersion}'
                  '${_snapshot.primaryAbi == null ? '' : ' • ${_snapshot.primaryAbi}'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _preparingRuntime ? null : _prepareRuntime,
            icon: _preparingRuntime
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(linuxReady ? Icons.check_circle : Icons.download),
            label: Text(
              _preparingRuntime
                  ? 'Preparing runtime...'
                  : linuxReady
                      ? 'Linux Runtime Ready'
                      : _snapshot.status == RuntimeStatus.failed
                          ? 'Retry Linux Installation'
                          : 'Install Linux Runtime',
            ),
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'DEVELOPMENT TOOLS',
          style: TextStyle(color: Colors.white54, letterSpacing: 2),
        ),
        const SizedBox(height: 14),
        const _Tile(Icons.code, 'Python Editor'),
        const _Tile(Icons.menu_book, 'Notebook Studio'),
        const _Tile(Icons.inventory_2, 'Package Vault'),
        const _Tile(Icons.terminal, 'Linux Terminal'),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      tileColor: const Color(0xFF101010),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 15,
    );
  }
}
