import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const NarrativaApp());
}

class NarrativaApp extends StatelessWidget {
  const NarrativaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.archivoBlackTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final Color mustardYellow = const Color.fromARGB(255, 255, 200, 1);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _topicController = TextEditingController();

  final List<Map<String, String>> creators = [
    {"name": "Khushi", "desc": "Fits the Flutter"},
    {"name": "Achal", "desc": "Presents the Presentations"},
    {"name": "Deepanshi", "desc": "Copies the Writes"},
    {"name": "Vanshvi", "desc": "idk who"},
  ];

  void _scrollToBuiltBy() {
    _scrollController.animateTo(
      MediaQuery.of(context).size.height,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Hero Section
            Container(
              height: screenHeight,
              width: double.infinity,
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hi. I am Narrativa.',
                      style: GoogleFonts.archivoBlack(
                        color: mustardYellow,
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Create stories with AI',
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _scrollToBuiltBy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mustardYellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: const Text('Meet the Creators'),
                    ),
                  ],
                ),
              ),
            ),
            // Built By Section
            Container(
              height: screenHeight,
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Built By',
                    style: GoogleFonts.archivoBlack(
                      color: Colors.black,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: creators.length,
                      itemBuilder: (context, index) {
                        return _creatorBox(creators[index]['name']!, creators[index]['desc']!);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _creatorBox(String name, String role) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: mustardYellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person, size: 40, color: Colors.black),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: Colors.black, fontSize: 18)),
        Text(
          role,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
