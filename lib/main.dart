import 'package:flutter/material.dart';

void main() {
  runApp(const SmapyApp());
}

class SmapyApp extends StatelessWidget {
  const SmapyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMAPY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
          surface: Color(0xFF111111),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const SmapyHome(),
    );
  }
}

class SmapyHome extends StatefulWidget {
  const SmapyHome({super.key});

  @override
  State<SmapyHome> createState() => _SmapyHomeState();
}

class _SmapyHomeState extends State<SmapyHome> {
  int selectedIndex = 0;

  static const pages = [
    'Workspace',
    'Notebooks',
    'Packages',
    'Terminal',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.code_rounded, size: 27),
            SizedBox(width: 10),
            Text(
              'SMAPY',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: [
            _workspace(),
            _placeholder(
              Icons.menu_book_outlined,
              'Your notebooks',
              'Your Python notebooks will appear here.',
            ),
            _placeholder(
              Icons.inventory_2_outlined,
              'Package vault',
              'Manage installed and offline packages.',
            ),
            _placeholder(
              Icons.terminal_rounded,
              'Terminal',
              'Linux terminal integration is planned for the next phase.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF080808),
        indicatorColor: Colors.white12,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Notebooks',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Packages',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal_rounded),
            label: 'Terminal',
          ),
        ],
      ),
    );
  }

  Widget _workspace() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const Text(
          'YOUR MOBILE WORKSTATION',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Code without\ncompromise.',
          style: TextStyle(
            fontSize: 37,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'A Python development environment, built for your phone.',
          style: TextStyle(
            color: Colors.white60,
            height: 1.6,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 21),
                  SizedBox(width: 10),
                  Text(
                    'PYTHON WORKSPACE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.circle, size: 8, color: Colors.white38),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'print("Hello, SMAPY")',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),
              const Text(
                'Runtime: Not connected yet',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Python engine will be integrated in Phase 2.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.code_rounded),
                  label: const Text('Open workspace'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'DEVELOPMENT TOOLS',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 14),
        _toolCard(
          Icons.menu_book_outlined,
          'Notebook Studio',
          'Code cells and Jupyter-compatible files',
          '01',
          () => setState(() => selectedIndex = 1),
        ),
        _toolCard(
          Icons.inventory_2_outlined,
          'Package Vault',
          'Your future offline package library',
          '02',
          () => setState(() => selectedIndex = 2),
        ),
        _toolCard(
          Icons.terminal_rounded,
          'Linux Terminal',
          'A local Linux environment is planned',
          '03',
          () => setState(() => selectedIndex = 3),
        ),
        const SizedBox(height: 22),
        const Center(
          child: Text(
            'SMAPY  •  BUILT FOR ANDROID',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolCard(
    IconData icon,
    String title,
    String subtitle,
    String number,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 23),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(
    IconData icon,
    String title,
    String description,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.white70),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
