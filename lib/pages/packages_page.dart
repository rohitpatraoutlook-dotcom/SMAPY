import 'package:flutter/material.dart';

class PackagesPage extends StatelessWidget {
  const PackagesPage({super.key});

  static const packages = [
    ['Python', 'Interpreter runtime'],
    ['pip', 'Python package installer'],
    ['NumPy', 'Numerical computing'],
    ['Pandas', 'Data analysis'],
    ['Matplotlib', 'Charts and plotting'],
    ['Requests', 'HTTP requests'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('PACKAGE VAULT',
            style: TextStyle(color: Colors.white54, letterSpacing: 2)),
        const SizedBox(height: 8),
        const Text(
          'Package catalogue preview. Installation will be enabled after runtime integration.',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 16),
        ...packages.map((p) => Card(
          color: const Color(0xFF101010),
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(p[0]),
            subtitle: Text(p[1]),
            trailing: const Icon(Icons.lock_outline),
          ),
        )),
      ],
    );
  }
}
