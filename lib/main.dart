import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/editor_page.dart';
import 'pages/notebook_page.dart';
import 'pages/packages_page.dart';
import 'pages/terminal_page.dart';

void main() => runApp(const SmapyApp());

class SmapyApp extends StatelessWidget {
  const SmapyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMAPY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color(0xFF101010),
        ),
        useMaterial3: true,
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
  int index = 0;

  final pages = const [
    HomePage(),
    EditorPage(),
    NotebookPage(),
    PackagesPage(),
    TerminalPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SMAPY',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() => index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.code),
            label: 'Editor',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Notebook',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Packages',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal),
            label: 'Terminal',
          ),
        ],
      ),
    );
  }
}
