import 'package:flutter/material.dart';\nimport '../services/runtime_manager.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 25),
        const Text('YOUR MOBILE WORKSTATION',
            style: TextStyle(color: Colors.white54, letterSpacing: 2)),
        const SizedBox(height: 18),
        const Text('Code without\ncompromise.',
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        const Text('Python development, built for your phone.',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.terminal, size: 30),
              SizedBox(height: 20),
              Text('print("Hello, SMAPY")',
                  style: TextStyle(fontFamily: 'monospace')),
              SizedBox(height: 20),
              Text('Python runtime setup pending',
                  style: TextStyle(color: Colors.white54)),
              SizedBox(height: 12),
              Text(
                'Runtime status',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 6),
              Text(
                runtimeMessage,
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: preparingRuntime ? null : prepareRuntime,
            icon: preparingRuntime
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(
              preparingRuntime ? 'Preparing runtime...' : 'Install Linux Runtime',
            ),
          ),
        ),
        const SizedBox(height: 25),
        const Text('DEVELOPMENT TOOLS',
            style: TextStyle(color: Colors.white54, letterSpacing: 2)),
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
