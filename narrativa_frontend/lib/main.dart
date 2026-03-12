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
      theme: ThemeData.dark(),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  final Color mustardYellow = const Color.fromARGB(255, 255, 200, 1);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _topicController = TextEditingController();

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final List<Map<String, String>> creators = [
    {"name": "Khushi", "desc": "Fits the Flutter"},
    {"name": "Achal", "desc": "Presents the Presentations"},
    {"name": "Deepanshi", "desc": "Copies the Writes"},
    {"name": "Vanshvi", "desc": "idk who"},
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _topicController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBuiltBy() {
    _scrollController.animateTo(
      MediaQuery.of(context).size.height,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutQuart,
    );
  }

  void _onGenerate() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    // TODO: hook up generation logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generating story for: $topic')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // ── Page 1 ──────────────────────────────────────────────────
            SizedBox(
              height: screenHeight,
              width: double.infinity,
              child: Stack(
                children: [
                  // Centered main content
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hi. I am Narrativa.',
                            style: GoogleFonts.archivoBlack(
                              color: mustardYellow,
                              fontSize: 72,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),

                          // Input + Generate row
                          SizedBox(
                            width: screenWidth * 0.6,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _topicController,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 15,
                                      ),
                                      onSubmitted: (_) => _onGenerate(),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter a story topic...',
                                        hintStyle: TextStyle(
                                          color: Colors.black45,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 18,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: mustardYellow,
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: _onGenerate,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Generate',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bouncing arrow at bottom center
                  Positioned(
                    bottom: 36,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _scrollToBuiltBy,
                      child: AnimatedBuilder(
                        animation: _bounceAnimation,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _bounceAnimation.value),
                          child: child,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'MEET THE CREATORS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: mustardYellow.withOpacity(0.75),
                                fontSize: 11,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: mustardYellow,
                              size: 34,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Page 2: Built By ─────────────────────────────────────────
            SizedBox(
              height: screenHeight,
              width: double.infinity,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 60,
                ),
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
                    SizedBox(
                      width: 560,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: _creatorBox(creators[0]['name']!, creators[0]['desc']!)),
                              const SizedBox(width: 30),
                              Expanded(child: _creatorBox(creators[1]['name']!, creators[1]['desc']!)),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Expanded(child: _creatorBox(creators[2]['name']!, creators[2]['desc']!)),
                              const SizedBox(width: 30),
                              Expanded(child: _creatorBox(creators[3]['name']!, creators[3]['desc']!)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _creatorBox(String name, String role) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 107,
          width: double.infinity,
          decoration: BoxDecoration(
            color: mustardYellow,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.person, size: 24, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          role,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}