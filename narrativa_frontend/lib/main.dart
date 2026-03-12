import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────

class Bullet {
  double x, y;
  Bullet(this.x, this.y);
}

class Asteroid {
  double x, y, size, speedX, speedY;
  Asteroid(this.x, this.y, this.size, this.speedX, this.speedY);
}

class Particle {
  double x, y, vx, vy, life, maxLife, size;
  Color color;
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color)
      : maxLife = life;
}

// ─────────────────────────────────────────────
// ASTEROID GAME WIDGET
// ─────────────────────────────────────────────

class AsteroidGame extends StatefulWidget {
  final VoidCallback onGameEnd;
  const AsteroidGame({super.key, required this.onGameEnd});

  @override
  State<AsteroidGame> createState() => _AsteroidGameState();
}

class _AsteroidGameState extends State<AsteroidGame> {
  static const double shipY = 0.85;
  static const double bulletSpeed = 0.018;
  static const double asteroidSpawnRate = 1.8;
  static const double shipSpeed = 0.03;

  double shipX = 0.5;
  List<Bullet> bullets = [];
  List<Asteroid> asteroids = [];
  List<Particle> particles = [];
  int score = 0;
  int lives = 3;
  bool gameOver = false;
  bool generationDone = false;

  late Timer _gameLoop;
  late Timer _asteroidSpawner;
  final Random _rng = Random();
  bool _leftDown = false;
  bool _rightDown = false;
  bool _shootDown = false;
  double _shootCooldown = 0;

  static const List<Color> _burstColors = [
    Color.fromARGB(255, 255, 200, 1),
    Colors.orange,
    Colors.deepOrange,
    Colors.white,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), _tick);
    _asteroidSpawner = Timer.periodic(
      Duration(milliseconds: (asteroidSpawnRate * 1000).toInt()),
      (_) => _spawnAsteroid(),
    );
  }

  void _spawnAsteroid() {
    if (gameOver || generationDone) return;
    final size = 0.04 + _rng.nextDouble() * 0.05;
    final speedY = 0.004 + _rng.nextDouble() * 0.005;
    final speedX = (_rng.nextDouble() - 0.5) * 0.003;
    setState(() {
      asteroids.add(Asteroid(_rng.nextDouble(), 0, size, speedX, speedY));
    });
  }

  void _spawnBurst(double x, double y, double sizePx) {
    final count = 12 + _rng.nextInt(8);
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.004 + _rng.nextDouble() * 0.008;
      particles.add(Particle(
        x,
        y,
        cos(angle) * speed,
        sin(angle) * speed,
        0.6 + _rng.nextDouble() * 0.4,
        (sizePx * 0.15 + _rng.nextDouble() * sizePx * 0.2).clamp(3, 10),
        _burstColors[_rng.nextInt(_burstColors.length)],
      ));
    }
  }

  void _tick(Timer _) {
    if (gameOver || generationDone) return;
    setState(() {
      // Move ship
      if (_leftDown) shipX = (shipX - shipSpeed).clamp(0.05, 0.95);
      if (_rightDown) shipX = (shipX + shipSpeed).clamp(0.05, 0.95);

      // Shoot cooldown
      if (_shootDown && _shootCooldown <= 0) {
        bullets.add(Bullet(shipX, shipY - 0.05));
        _shootCooldown = 0.3;
      }
      if (_shootCooldown > 0) _shootCooldown -= 0.016;

      // Move bullets
      bullets = bullets
          .map((b) => Bullet(b.x, b.y - bulletSpeed))
          .where((b) => b.y > 0)
          .toList();

      // Move asteroids
      for (final a in asteroids) {
        a.x += a.speedX;
        a.y += a.speedY;
      }

      // Bullet-asteroid collisions
      final hitAsteroids = <Asteroid>{};
      final hitBullets = <Bullet>{};
      for (final b in bullets) {
        for (final a in asteroids) {
          final dx = (b.x - a.x).abs();
          final dy = (b.y - a.y).abs();
          if (dx < a.size && dy < a.size) {
            hitAsteroids.add(a);
            hitBullets.add(b);
            score++;
          }
        }
      }
      for (final a in hitAsteroids) {
        _spawnBurst(a.x, a.y, a.size * 300);
      }
      asteroids.removeWhere((a) => hitAsteroids.contains(a));
      bullets.removeWhere((b) => hitBullets.contains(b));

      // Update particles
      for (final p in particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.0002;
        p.life -= 0.025;
      }
      particles.removeWhere((p) => p.life <= 0);

      // Ship-asteroid collision
      for (final a in asteroids) {
        final dx = (shipX - a.x).abs();
        final dy = (shipY - a.y).abs();
        if (dx < a.size + 0.04 && dy < a.size + 0.02) {
          asteroids.remove(a);
          lives--;
          if (lives <= 0) gameOver = true;
          break;
        }
      }

      // Remove off-screen asteroids
      asteroids.removeWhere((a) => a.y > 1.1);
    });
  }

  @override
  void dispose() {
    _gameLoop.cancel();
    _asteroidSpawner.cancel();
    super.dispose();
  }

  void generationComplete() {
    setState(() => generationDone = true);
    _gameLoop.cancel();
    _asteroidSpawner.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final Color yellow = const Color.fromARGB(255, 255, 200, 1);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final isDown = event is KeyDownEvent;
        final isUp = event is KeyUpEvent;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _leftDown = isDown;
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _rightDown = isDown;
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.space) {
          _shootDown = isDown || (!isUp && _shootDown);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // ── Game canvas ──
            LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                children: [
                  // Stars
                  CustomPaint(
                    size: Size(w, h),
                    painter: _StarsPainter(),
                  ),

                  // Asteroids
                  for (final a in asteroids)
                    Positioned(
                      left: a.x * w - a.size * w / 2,
                      top: a.y * h - a.size * h / 2,
                      child: _AsteroidWidget(size: a.size * w),
                    ),

                  // Particles
                  for (final p in particles)
                    Positioned(
                      left: p.x * w - p.size / 2,
                      top: p.y * h - p.size / 2,
                      child: Opacity(
                        opacity: (p.life / p.maxLife).clamp(0.0, 1.0),
                        child: Container(
                          width: p.size,
                          height: p.size,
                          decoration: BoxDecoration(
                            color: p.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: p.color.withOpacity(0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Bullets
                  for (final b in bullets)
                    Positioned(
                      left: b.x * w - 3,
                      top: b.y * h,
                      child: Container(
                        width: 6,
                        height: 18,
                        decoration: BoxDecoration(
                          color: yellow,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: yellow.withOpacity(0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Ship
                  Positioned(
                    left: shipX * w - 24,
                    top: shipY * h - 24,
                    child: _ShipWidget(color: yellow),
                  ),

                  // HUD
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCORE: $score',
                          style: GoogleFonts.archivoBlack(
                            color: yellow,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            3,
                            (i) => Icon(
                              Icons.favorite,
                              color:
                                  i < lives ? Colors.red : Colors.grey[800],
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Generating label
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Generating...',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),

            // ── Controls ──
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GameButton(
                    icon: Icons.arrow_left_rounded,
                    onDown: () => _leftDown = true,
                    onUp: () => _leftDown = false,
                    color: yellow,
                  ),
                  const SizedBox(width: 16),
                  _GameButton(
                    icon: Icons.radio_button_checked,
                    label: 'FIRE',
                    onDown: () => _shootDown = true,
                    onUp: () => _shootDown = false,
                    color: yellow,
                  ),
                  const SizedBox(width: 16),
                  _GameButton(
                    icon: Icons.arrow_right_rounded,
                    onDown: () => _rightDown = true,
                    onUp: () => _rightDown = false,
                    color: yellow,
                  ),
                ],
              ),
            ),

            // ── Game Over overlay ──
            if (gameOver)
              Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GAME OVER',
                        style: GoogleFonts.archivoBlack(
                          color: Colors.red,
                          fontSize: 48,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score: $score',
                        style: GoogleFonts.archivoBlack(
                          color: yellow,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Still generating your presentation...',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Generation Done overlay ──
            if (generationDone)
              Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Your Presentation is Ready!',
                        style: GoogleFonts.archivoBlack(
                          color: yellow,
                          fontSize: 36,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Final score: $score',
                        style: GoogleFonts.archivoBlack(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: trigger PDF download
                            },
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: Text(
                              'Download PDF',
                              style: GoogleFonts.archivoBlack(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: yellow,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: trigger PPTX download
                            },
                            icon: const Icon(Icons.slideshow, size: 18),
                            label: Text(
                              'Download PPTX',
                              style: GoogleFonts.archivoBlack(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: widget.onGameEnd,
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
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
    );
  }
}

// ─────────────────────────────────────────────
// SHIP WIDGET
// ─────────────────────────────────────────────

class _ShipWidget extends StatelessWidget {
  final Color color;
  const _ShipWidget({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(48, 48),
      painter: _ShipPainter(color),
    );
  }
}

class _ShipPainter extends CustomPainter {
  final Color color;
  _ShipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.75)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// ASTEROID WIDGET
// ─────────────────────────────────────────────

class _AsteroidWidget extends StatelessWidget {
  final double size;
  const _AsteroidWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AsteroidPainter(),
    );
  }
}

class _AsteroidPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    const points = 8;
    for (int i = 0; i < points; i++) {
      final angle = (i / points) * 2 * pi;
      final jitter = 0.7 + (i % 3) * 0.15;
      final px = cx + cos(angle) * r * jitter;
      final py = cy + sin(angle) * r * jitter;
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// STARS BACKGROUND
// ─────────────────────────────────────────────

class _StarsPainter extends CustomPainter {
  final List<Offset> _stars = List.generate(
    80,
    (_) => Offset(Random().nextDouble(), Random().nextDouble()),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white54;
    for (final s in _stars) {
      canvas.drawCircle(
          Offset(s.dx * size.width, s.dy * size.height), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// GAME BUTTON
// ─────────────────────────────────────────────

class _GameButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final Color color;

  const _GameButton({
    required this.icon,
    required this.onDown,
    required this.onUp,
    required this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: label != null
            ? Center(
                child: Text(
                  label!,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              )
            : Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN LAYOUT
// ─────────────────────────────────────────────

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
  final GlobalKey<_AsteroidGameState> _gameKey = GlobalKey();

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  bool _showGame = false;

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
    setState(() => _showGame = true);
    // Replace this delay with your real generation call.
    // When done, call: _gameKey.currentState?.generationComplete();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) _gameKey.currentState?.generationComplete();
    });
  }

  void _onGameEnd() {
    setState(() => _showGame = false);
    // TODO: navigate to result / show generated file
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Main scrollable content ──
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // Page 1
                SizedBox(
                  height: screenHeight,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 32.0),
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
                              SizedBox(
                                width: screenWidth * 0.6,
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
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
                                            hintText:
                                                'Enter a story topic...',
                                            hintStyle: TextStyle(
                                                color: Colors.black45),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 18),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                bottomLeft:
                                                    Radius.circular(12),
                                              ),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                bottomLeft:
                                                    Radius.circular(12),
                                              ),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                bottomLeft:
                                                    Radius.circular(12),
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
                                          borderRadius:
                                              const BorderRadius.only(
                                            topRight: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 24),
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

                // Page 2: Built By
                SizedBox(
                  height: screenHeight,
                  width: double.infinity,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 60),
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
                                  Expanded(
                                      child: _creatorBox(
                                          creators[0]['name']!,
                                          creators[0]['desc']!)),
                                  const SizedBox(width: 30),
                                  Expanded(
                                      child: _creatorBox(
                                          creators[1]['name']!,
                                          creators[1]['desc']!)),
                                ],
                              ),
                              const SizedBox(height: 30),
                              Row(
                                children: [
                                  Expanded(
                                      child: _creatorBox(
                                          creators[2]['name']!,
                                          creators[2]['desc']!)),
                                  const SizedBox(width: 30),
                                  Expanded(
                                      child: _creatorBox(
                                          creators[3]['name']!,
                                          creators[3]['desc']!)),
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

          // ── Asteroid game overlay ──
          if (_showGame)
            Positioned.fill(
              child: AsteroidGame(
                key: _gameKey,
                onGameEnd: _onGameEnd,
              ),
            ),
        ],
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