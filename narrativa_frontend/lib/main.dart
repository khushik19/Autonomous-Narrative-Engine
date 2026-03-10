import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const NarrativaApp());



class NarrativaApp extends StatelessWidget {
  const NarrativaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.archivoBlackTextTheme(ThemeData.dark().textTheme),
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
            // --- PAGE 1: HERO SECTION + INPUT ---
            Container(
              height: screenHeight,
              width: double.infinity,
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Hi.\nI am Narrativa.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 80, 
                      color: Colors.white, 
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // TYPE YOUR TOPIC BOX
                  SizedBox(
                    width: 400,
                    child: TextField(
                      controller: _topicController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: "TYPE YOUR TOPIC...",
                        // Fixed withValues error by using opacity
                        hintStyle: TextStyle(color: Colors.white.withValues()),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: mustardYellow, width: 3),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // GENERATE BUTTON
                  ElevatedButton(
                    onPressed: () {
                      print("Generating for: ${_topicController.text}");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mustardYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                    child: const Text(
                      "GENERATE",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  IconButton(
                    onPressed: _scrollToBuiltBy,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 40),
                  ),
                ],
              ), // This is where the brackets were fixed!
            ),

            // --- PAGE 2: BUILT BY ---
            Container(
              constraints: BoxConstraints(minHeight: screenHeight),
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                final List<Map<String, String>> creators = [
                    {"name": "Khushi", "desc": "Fits the Flutter"},
                    {"name": "Achal", "desc": "Presents the Presentations"},
                    {"name": "Deepanshi", "desc": "Copies the Writes"},
                    {"name": "Vanshvi", "desc": "idk who"},
                  ];
                children: [
                  const Text(
                    "BUILT BY",
                    style: TextStyle(fontSize: 60, color: Colors.black),
                  ),
                  const SizedBox(height:60),
                  
                  Widget build(BuildContext context) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1, // Adjust based on _creatorBox height
                      ),
                      itemCount: creators.length,
                      itemBuilder: (context, index) {
                        return _creatorBox(
                          creators[index]["name"]!, 
                          creators[index]["desc"]!,
                        );
                      },
                    );
                  }

                  // GridView.builder(
                  //   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  //   crossAxisCount: 2, // Adjust as needed
                  //   childAspectRatio: 1, // Adjust as needed for image and text
                  //   ),
                  //   spacing: 80,
                  //   runSpacing: 80,
                  //   alignment: WrapAlignment.center,
                  //   children: [
                  //     _creatorBox("Khushi", "Fits the Flutter"),
                  //     _creatorBox("Achal", "Presents the Presentations"),
                  //     _creatorBox("Deepanshi", "Copies the Writes"),
                  //     _creatorBox("Vanshvi", "idk who"),
                  //   ],
                  // ),
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
        Container(
          width: 240,
          height: 180,
          decoration: BoxDecoration(
            color: mustardYellow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.person, size: 60, color: Colors.black),
        ),
        const SizedBox(height: 15),
        Text(name, style: const TextStyle(color: Colors.black, fontSize: 22)),
        Text(role, style: const TextStyle(color: Colors.black54, fontSize: 14)),
      ],
    );
  }
}