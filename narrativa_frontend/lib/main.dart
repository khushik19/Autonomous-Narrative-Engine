import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// HOW TO INTEGRATE THE WEBSOCKET:
//
// No extra packages needed — uses dart:io WebSocket built in.
//
// Your backend should send JSON messages like:
//      {"type": "status", "index": 0}   ← drives the status tracker
//      {"type": "status", "index": 1}
//      ...
//      {"type": "done", "sources": ["https://...", "https://..."]}
//
// Change _wsUrl below to your real backend WebSocket URL.
// ─────────────────────────────────────────────

const String _wsUrl = 'ws://your-backend-url/ws/generate';

void main() {
  runApp(const NarrativaApp());
}

class NarrativaApp extends StatelessWidget {
  const NarrativaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.archivoBlackTextTheme(ThemeData.dark().textTheme),
      ),
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
// SOURCES SCREEN
// ─────────────────────────────────────────────

class SourcesScreen extends StatelessWidget {
  final List<String> sources;
  const SourcesScreen({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    const yellow = Color.fromARGB(255, 255, 200, 1);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '🔗 Sources Used',
          style: GoogleFonts.archivoBlack(color: yellow, fontSize: 18),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: sources.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white12),
        itemBuilder: (context, i) {
          final url = sources[i];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link, color: Color(0xFF64B5F6), size: 20),
            title: GestureDetector(
              onTap: () {
                // TODO: launch url (add url_launcher package)
              },
              child: Text(
                url,
                style: const TextStyle(
                  color: Color(0xFF64B5F6),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF64B5F6),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ASTEROID GAME WIDGET
// ─────────────────────────────────────────────

class AsteroidGame extends StatefulWidget {
  final VoidCallback onGameEnd;
  final List<String> sources;
  final Map<String, dynamic> payload;

  const AsteroidGame({
    super.key,
    required this.onGameEnd,
    required this.sources,
    required this.payload,
  });

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

  int _statusIndex = 0;
  static const List<String> _statusMessages = [
    '🔍 Inferring search queries...',
    '🌐 Scraping live web data...',
    '🧠 Synthesizing narrative...',
    '⚖️ Fact-checking claims...',
    '🎨 Generating visual assets...',
  ];

  List<String> _liveSources = [];

  late Timer _gameLoop;
  late Timer _asteroidSpawner;
  html.WebSocket? _socket;
  StreamSubscription? _wsSub;

  final Random _rng = Random();
  bool _leftDown = false;
  bool _rightDown = false;
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
    _liveSources = List.from(widget.sources);
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), _tick);
    _asteroidSpawner = Timer.periodic(
      Duration(milliseconds: (asteroidSpawnRate * 1000).toInt()),
      (_) => _spawnAsteroid(),
    );
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _socket = html.WebSocket(_wsUrl);

      _socket!.onOpen.listen((_) {
        // Send payload once connection is open
        _socket!.send(jsonEncode(widget.payload));
      });

      _wsSub = _socket!.onMessage.listen(
        (html.MessageEvent event) {
          if (!mounted) return;
          final data =
              jsonDecode(event.data as String) as Map<String, dynamic>;

          if (data['type'] == 'status') {
            setState(() => _statusIndex =
                (data['index'] as int).clamp(0, _statusMessages.length - 1));
          } else if (data['type'] == 'done') {
            final rawSources = data['sources'];
            if (rawSources is List) {
              setState(() =>
                  _liveSources = rawSources.map((e) => e.toString()).toList());
            }
            generationComplete();
          }
        },
      );

      _socket!.onError.listen((e) => debugPrint('WebSocket error: $e'));
      _socket!.onClose.listen((_) => debugPrint('WebSocket closed'));
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      // Game keeps running without status updates
    }
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
        x, y,
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
      if (_leftDown) shipX = (shipX - shipSpeed).clamp(0.05, 0.95);
      if (_rightDown) shipX = (shipX + shipSpeed).clamp(0.05, 0.95);

      // Auto-fire — always shoots, no button needed
      if (_shootCooldown <= 0) {
        bullets.add(Bullet(shipX, shipY - 0.05));
        _shootCooldown = 0.3;
      }
      if (_shootCooldown > 0) _shootCooldown -= 0.016;

      bullets = bullets
          .map((b) => Bullet(b.x, b.y - bulletSpeed))
          .where((b) => b.y > 0)
          .toList();

      for (final a in asteroids) {
        a.x += a.speedX;
        a.y += a.speedY;
      }

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
      for (final a in hitAsteroids) _spawnBurst(a.x, a.y, a.size * 300);
      asteroids.removeWhere((a) => hitAsteroids.contains(a));
      bullets.removeWhere((b) => hitBullets.contains(b));

      for (final p in particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.0002;
        p.life -= 0.025;
      }
      particles.removeWhere((p) => p.life <= 0);

      // Ship-asteroid collision — find hit outside loop then remove safely
      Asteroid? hitByShip;
      for (final a in asteroids) {
        final dx = (shipX - a.x).abs();
        final dy = (shipY - a.y).abs();
        if (dx < a.size + 0.04 && dy < a.size + 0.02) {
          hitByShip = a;
          break;
        }
      }
      if (hitByShip != null) {
        asteroids.remove(hitByShip);
        lives--;
        if (lives <= 0) gameOver = true;
      }
      asteroids.removeWhere((a) => a.y > 1.1);
    });
  }

  @override
  void dispose() {
    _gameLoop.cancel();
    _asteroidSpawner.cancel();
    _wsSub?.cancel();
    _socket?.close(1000);
    super.dispose();
  }

  void _replay() {
    _gameLoop.cancel();
    _asteroidSpawner.cancel();
    setState(() {
      bullets.clear();
      asteroids.clear();
      particles.clear();
      score = 0;
      lives = 3;
      shipX = 0.5;
      gameOver = false;
      _shootCooldown = 0;
    });
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), _tick);
    _asteroidSpawner = Timer.periodic(
      Duration(milliseconds: (asteroidSpawnRate * 1000).toInt()),
      (_) => _spawnAsteroid(),
    );
  }

  void generationComplete() {
    setState(() {
      generationDone = true;
      _statusIndex = _statusMessages.length - 1;
    });
    _gameLoop.cancel();
    _asteroidSpawner.cancel();
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color.fromARGB(255, 255, 200, 1);

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
        return KeyEventResult.ignored;
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // ── Game canvas ──────────────────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                children: [
                  CustomPaint(size: Size(w, h), painter: _StarsPainter()),

                  for (final a in asteroids)
                    Positioned(
                      left: a.x * w - a.size * w / 2,
                      top: a.y * h - a.size * h / 2,
                      child: _AsteroidWidget(size: a.size * w),
                    ),

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

                  Positioned(
                    left: shipX * w - 24,
                    top: shipY * h - 24,
                    child: const _ShipWidget(color: yellow),
                  ),

                  // HUD
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SCORE: $score',
                            style: GoogleFonts.archivoBlack(
                                color: yellow, fontSize: 18)),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            3,
                            (i) => Icon(Icons.favorite,
                                color:
                                    i < lives ? Colors.red : Colors.grey[800],
                                size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dynamic status tracker
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_statusMessages.length, (i) {
                          final isDone = i < _statusIndex;
                          final isActive = i == _statusIndex;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isDone)
                                  const Icon(Icons.check_circle,
                                      color: Colors.greenAccent, size: 13)
                                else if (isActive)
                                  const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5, color: yellow),
                                  )
                                else
                                  const Icon(Icons.circle_outlined,
                                      color: Colors.white24, size: 13),
                                const SizedBox(width: 7),
                                Text(
                                  _statusMessages[i],
                                  style: GoogleFonts.archivoBlack(
                                    color: isDone
                                        ? Colors.greenAccent
                                        : isActive
                                            ? Colors.white
                                            : Colors.white30,
                                    fontSize: 12,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
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
                  ),
                  const SizedBox(width: 16),
                  _GameButton(
                    icon: Icons.arrow_right_rounded,
                    onDown: () => _rightDown = true,
                    onUp: () => _rightDown = false,
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
                      Text('GAME OVER',
                          style: GoogleFonts.archivoBlack(
                              color: Colors.red, fontSize: 48)),
                      const SizedBox(height: 8),
                      Text('Score: $score',
                          style: GoogleFonts.archivoBlack(
                              color: yellow, fontSize: 24)),
                      const SizedBox(height: 24),
                      Text('Still generating your presentation...',
                          style: GoogleFonts.archivoBlack(
                              color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _replay,
                        icon: const Icon(Icons.replay, size: 18),
                        label: Text('Play Again',
                            style: GoogleFonts.archivoBlack(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: yellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Generation Done overlay ──
            if (generationDone)
              Container(
                color: const Color(0xEE000000),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '✓ Your Presentation is Ready!',
                          style: GoogleFonts.archivoBlack(
                              color: yellow, fontSize: 34),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text('Final score: $score',
                            style: GoogleFonts.archivoBlack(
                                color: Colors.white, fontSize: 18)),
                        const SizedBox(height: 28),

                        // Download buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: trigger PDF download
                              },
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: Text('Download PDF',
                                  style: GoogleFonts.archivoBlack(
                                      fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: yellow,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: trigger PPTX download
                              },
                              icon: const Icon(Icons.slideshow, size: 18),
                              label: Text('Download PPTX',
                                  style: GoogleFonts.archivoBlack(
                                      fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),

                        // Sources preview (max 3)
                        if (_liveSources.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: 460,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white12, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('🔗 Sources Used',
                                        style: GoogleFonts.archivoBlack(
                                            color: Colors.white,
                                            fontSize: 13)),
                                    const Spacer(),
                                    if (_liveSources.length > 3)
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SourcesScreen(
                                                sources: _liveSources),
                                          ),
                                        ),
                                        child: Text(
                                          'View all ${_liveSources.length} →',
                                          style: GoogleFonts.archivoBlack(
                                            color: Color(0xFF64B5F6),
                                            fontSize: 12,
                                            decoration: TextDecoration.underline,
                                            decorationColor: Color(0xFF64B5F6),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._liveSources.take(3).map((url) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 5),
                                      child: GestureDetector(
                                        onTap: () {
                                          // TODO: launch url
                                        },
                                        child: Text(
                                          url,
                                          style: GoogleFonts.archivoBlack(
                                            color: Color(0xFF64B5F6),
                                            fontSize: 12,
                                            decoration: TextDecoration.underline,
                                            decorationColor: Color(0xFF64B5F6),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )),
                                // "View all" inline if <= 3 sources too
                                if (_liveSources.length <= 3)
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SourcesScreen(
                                            sources: _liveSources),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'View full list →',
                                        style: GoogleFonts.archivoBlack(
                                          color: Color(0xFF64B5F6),
                                          fontSize: 12,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Color(0xFF64B5F6),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: widget.onGameEnd,
                          child: Text('Close',
                              style: GoogleFonts.archivoBlack(
                                  color: Colors.white38, fontSize: 13)),
                        ),
                      ],
                    ),
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
// SHIP
// ─────────────────────────────────────────────

class _ShipWidget extends StatelessWidget {
  final Color color;
  const _ShipWidget({required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(48, 48), painter: _ShipPainter(color));
}

class _ShipPainter extends CustomPainter {
  final Color color;
  _ShipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final glow = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.75)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// ASTEROID
// ─────────────────────────────────────────────

class _AsteroidWidget extends StatelessWidget {
  final double size;
  const _AsteroidWidget({required this.size});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _AsteroidPainter());
}

class _AsteroidPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final jitter = 0.7 + (i % 3) * 0.15;
      final px = cx + cos(angle) * r * jitter;
      final py = cy + sin(angle) * r * jitter;
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// STARS
// ─────────────────────────────────────────────

class _StarsPainter extends CustomPainter {
  final List<Offset> _stars =
      List.generate(80, (_) => Offset(Random().nextDouble(), Random().nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white54;
    for (final s in _stars) {
      canvas.drawCircle(Offset(s.dx * size.width, s.dy * size.height), 1, p);
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

  const _GameButton({
    required this.icon,
    required this.onDown,
    required this.onUp,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    const yellow = Color.fromARGB(255, 255, 200, 1);
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          color: yellow.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: yellow.withOpacity(0.4), width: 1.5),
        ),
        child: label != null
            ? Center(
                child: Text(label!,
                    style: GoogleFonts.archivoBlack(
                        color: yellow,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)))
            : const Icon(Icons.arrow_left_rounded, color: yellow, size: 22),
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
  static const yellow = Color.fromARGB(255, 255, 200, 1);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _topicController = TextEditingController();
  final GlobalKey<_AsteroidGameState> _gameKey = GlobalKey();

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  bool _showGame = false;
  bool _showPopup = false;
  bool _isDetailed = false;
  double _slideCount = 8;

  final List<Map<String, String>> creators = [
    {"name": "Khushi",    "desc": "Fits the Flutter",          "image": "assets/images/khushi.jpg"},
    {"name": "Achal",     "desc": "Presents the Presentations", "image": "assets/images/achal.jpg"},
    {"name": "Deepanshi", "desc": "Copies the Writes",          "image": "assets/images/deepanshi.jpg"},
    {"name": "Vanshvi",   "desc": "idk who",                    "image": "assets/images/vanshvi.jpg"},
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

  Map<String, dynamic> _buildPayload() => {
        "topic": _topicController.text.trim(),
        "deck_style": _isDetailed ? "detailed" : "concise",
        "num_slides": _slideCount.round(),
      };

  void _onGenerate() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    setState(() => _showPopup = true);
  }

  void _onLaunchGame() {
    setState(() {
      _showPopup = false;
      _showGame = true;
    });
  }

  void _onPopupClose() => setState(() => _showPopup = false);

  void _onGameEnd() => setState(() => _showGame = false);

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // ── Page 1 ──────────────────────────────────────
                SizedBox(
                  height: screenHeight,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Hi. I am Narrativa.',
                                style: GoogleFonts.archivoBlack(
                                  color: yellow,
                                  fontSize: 72,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 40),

                              ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: screenWidth * 0.6),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Topic + Generate
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _topicController,
                                              style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 15),
                                              onSubmitted: (_) =>
                                                  _onGenerate(),
                                              decoration:
                                                  const InputDecoration(
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
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(12),
                                                    bottomLeft:
                                                        Radius.circular(12),
                                                  ),
                                                  borderSide: BorderSide.none,
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(12),
                                                    bottomLeft:
                                                        Radius.circular(12),
                                                  ),
                                                  borderSide: BorderSide.none,
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(12),
                                                    bottomLeft:
                                                        Radius.circular(12),
                                                  ),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Material(
                                            color: yellow,
                                            borderRadius:
                                                const BorderRadius.only(
                                              topRight: Radius.circular(12),
                                              bottomRight:
                                                  Radius.circular(12),
                                            ),
                                            child: InkWell(
                                              onTap: _onGenerate,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topRight: Radius.circular(12),
                                                bottomRight:
                                                    Radius.circular(12),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 24),
                                                child: Center(
                                                  child: Text('Generate',
                                                      style: GoogleFonts.archivoBlack(
                                                          color: Colors.black,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Deck Style toggle
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withOpacity(0.06),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.white12, width: 1),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.style_outlined,
                                              color: Colors.white54,
                                              size: 16),
                                          const SizedBox(width: 10),
                                          const Text('Deck Style',
                                              style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13)),
                                          const Spacer(),
                                          Text(
                                            'Concise',
                                            style: TextStyle(
                                              color: !_isDetailed
                                                  ? yellow
                                                  : Colors.white38,
                                              fontSize: 13,
                                              fontWeight: !_isDetailed
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Switch(
                                            value: _isDetailed,
                                            onChanged: (val) => setState(
                                                () => _isDetailed = val),
                                            activeColor: yellow,
                                            activeTrackColor:
                                                yellow.withOpacity(0.3),
                                            inactiveThumbColor: yellow,
                                            inactiveTrackColor:
                                                yellow.withOpacity(0.3),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Detailed',
                                            style: TextStyle(
                                              color: _isDetailed
                                                  ? yellow
                                                  : Colors.white38,
                                              fontSize: 13,
                                              fontWeight: _isDetailed
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Slide count slider
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withOpacity(0.06),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.white12, width: 1),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.layers_outlined,
                                              color: Colors.white54,
                                              size: 16),
                                          const SizedBox(width: 10),
                                          const Text('Slides',
                                              style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                activeTrackColor: yellow,
                                                inactiveTrackColor:
                                                    yellow.withOpacity(0.2),
                                                thumbColor: yellow,
                                                overlayColor:
                                                    yellow.withOpacity(0.15),
                                                trackHeight: 3,
                                              ),
                                              child: Slider(
                                                value: _slideCount,
                                                min: 5,
                                                max: 15,
                                                divisions: 10,
                                                onChanged: (val) =>
                                                    setState(() =>
                                                        _slideCount = val),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 28,
                                            child: Text(
                                              '${_slideCount.round()}',
                                              style: const TextStyle(
                                                  color: yellow,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bounce arrow
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
                                    color: yellow.withOpacity(0.75),
                                    fontSize: 11,
                                    letterSpacing: 2.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: yellow,
                                    size: 34),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Page 2: Built By ─────────────────────────────
                SizedBox(
                  height: screenHeight,
                  width: double.infinity,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 9),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Built By',
                            style: GoogleFonts.archivoBlack(
                                color: Colors.black,
                                fontSize: 36,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 560,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: _creatorBox(creators[0]['name']!,
                                        creators[0]['desc']!, creators[0]['image']!)),
                                const SizedBox(width: 30),
                                Expanded(
                                    child: _creatorBox(creators[1]['name']!,
                                        creators[1]['desc']!, creators[1]['image']!)),
                              ]),
                              const SizedBox(height: 11),
                              Row(children: [
                                Expanded(
                                    child: _creatorBox(creators[2]['name']!,
                                        creators[2]['desc']!, creators[2]['image']!)),
                                const SizedBox(width: 30),
                                Expanded(
                                    child: _creatorBox(creators[3]['name']!,
                                        creators[3]['desc']!, creators[3]['image']!)),
                              ]),
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

          // ── Generating popup ──
          if (_showPopup)
            Positioned.fill(
              child: _GeneratingPopup(
                statusMessages: const [
                  'Inferring search queries...',
                  'Scraping live web data...',
                  'Synthesizing narrative...',
                  'Fact-checking claims...',
                  'Generating visual assets...',
                ],
                onPlayGame: _onLaunchGame,
              ),
            ),

          // ── Game overlay ──
          if (_showGame)
            Positioned.fill(
              child: AsteroidGame(
                key: _gameKey,
                onGameEnd: _onGameEnd,
                sources: const [],
                payload: _buildPayload(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _creatorBox(String name, String role, String imagePath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: yellow,
              borderRadius: BorderRadius.circular(15),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, size: 24, color: Colors.black),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(name,
            style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        Text(role,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// GENERATING POPUP
// ─────────────────────────────────────────────

class _GeneratingPopup extends StatefulWidget {
  final List<String> statusMessages;
  final VoidCallback onPlayGame;

  const _GeneratingPopup({
    required this.statusMessages,
    required this.onPlayGame,
  });

  @override
  State<_GeneratingPopup> createState() => _GeneratingPopupState();
}

class _GeneratingPopupState extends State<_GeneratingPopup> {
  int _statusIndex = 0;
  bool _waiting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _statusIndex < widget.statusMessages.length - 1) {
        setState(() => _statusIndex++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color.fromARGB(255, 255, 200, 1);

    return Container(
      color: Colors.black.withOpacity(0.82),
      child: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10, width: 1),
            boxShadow: [
              BoxShadow(
                color: yellow.withOpacity(0.08),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _waiting
                    ? 'Hang tight...'
                    : 'Cooking your presentation...',
                style: GoogleFonts.archivoBlack(color: yellow, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _waiting
                    ? "I'll let you know when it's ready."
                    : 'This usually takes 15–45 seconds.',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Status steps
              ...List.generate(widget.statusMessages.length, (i) {
                final isDone = i < _statusIndex;
                final isActive = i == _statusIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: isDone
                            ? const Icon(Icons.check_circle,
                                color: Colors.greenAccent, size: 18)
                            : isActive
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2, color: yellow)
                                : const Icon(Icons.circle_outlined,
                                    color: Colors.white24, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.statusMessages[i],
                        style: TextStyle(
                          color: isDone
                              ? Colors.greenAccent
                              : isActive
                                  ? Colors.white
                                  : Colors.white30,
                          fontSize: 13,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 32),

              if (!_waiting) ...[
                // Play game button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onPlayGame,
                    icon: const Icon(Icons.sports_esports, size: 18),
                    label: Text(
                      'Enjoy shooting the Asteroids till I cook!',
                      style: GoogleFonts.archivoBlack(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _waiting = true),
                  child: const Text(
                    "I'll wait here",
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ] else ...[
                // Waiting mode — just a small "changed my mind" link
                TextButton.icon(
                  onPressed: () => setState(() => _waiting = false),
                  icon: const Icon(Icons.sports_esports,
                      size: 15, color: Colors.white38),
                  label: const Text(
                    'Actually, let me play while I wait',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}