import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../services/socket_service.dart';

late List<CameraDescription> _cameras;

enum SharingMode { none, camera, screen }

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late CameraController _controller;
  late SocketService _socket;
  Timer? _sendTimer;
  List<List<Map<String, dynamic>>> _allDrawingStrokes = [];
  bool _showDrawings = true;
  bool _isInitialized = false;
  Size _canvasSize = Size.zero;
  SharingMode _mode = SharingMode.none;

  @override
  void initState() {
    super.initState();
    _initCameraAndSocket();
  }

  Future<void> _initCameraAndSocket() async {
    print("User: Initializing camera and socket");
    try {
      _cameras = await availableCameras();
      _controller = CameraController(_cameras[0], ResolutionPreset.medium);
      await _controller.initialize();

      _socket = SocketService();
      _socket.connect('ws://172.26.102.151:8080');

      await Future.delayed(const Duration(milliseconds: 1000));
      _socket.sendRole('user');

      _socket.onDrawReceived = (points) => _processDrawingPoints(points);
      _socket.onClearReceived = () =>
          setState(() => _allDrawingStrokes.clear());

      setState(() => _isInitialized = true);

      print("User: Camera and socket initialization complete");
    } catch (e) {
      print("User: Initialization error: $e");
    }
  }

  void _startSharing(SharingMode mode) {
    _sendTimer?.cancel();
    setState(() => _mode = mode);

    _sendTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      try {
        if (_mode == SharingMode.camera && _controller.value.isInitialized) {
          final file = await _controller.takePicture();
          final bytes = await file.readAsBytes(); // Uint8List
          _socket.sendFrame(bytes);
        } else if (_mode == SharingMode.screen) {
          final fakeBytes = await _generateFakeScreenFrame();
          _socket.sendFrame(fakeBytes); // Uint8List
        }
      } catch (e) {
        debugPrint("Capture error: $e");
      }
    });
  }

  Future<Uint8List> _generateFakeScreenFrame() async {
    // Placeholder screen frame data
    return Uint8List.fromList(List<int>.filled(1000, 128));
  }

  void _stopSharing() {
    _sendTimer?.cancel();
    setState(() => _mode = SharingMode.none);
  }

  void _processDrawingPoints(List<Map<String, dynamic>> points) {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_canvasSize.width > 0 && _canvasSize.height > 0) {
          _processDrawingPoints(points);
        }
      });
      return;
    }

    final stroke = points.map((p) {
      return {
        'x': (p['x'] as double) * _canvasSize.width,
        'y': (p['y'] as double) * _canvasSize.height,
        'mode': p['mode'] ?? 'draw',
        'color': p['color'] ?? '#FF0000',
        'strokeWidth': (p['strokeWidth'] as num?)?.toDouble() ?? 4.0,
      };
    }).toList();

    setState(() => _allDrawingStrokes.add(stroke));
  }

  void _updateCanvasSize(Size size) {
    if (_canvasSize != size) {
      setState(() => _canvasSize = size);
      print("Canvas size updated: $_canvasSize");
    }
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    if (_controller.value.isInitialized) _controller.dispose();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Camera'),
        backgroundColor: Colors.green[800],
        actions: [
          IconButton(
            icon: Icon(_showDrawings ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showDrawings = !_showDrawings),
            tooltip: _showDrawings ? 'Hide Drawings' : 'Show Drawings',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateCanvasSize(Size(c.maxWidth, c.maxHeight));
          });

          return Stack(
            children: [
              if (_mode == SharingMode.camera && _isInitialized)
                Positioned.fill(child: CameraPreview(_controller))
              else
                const Positioned.fill(
                  child: Center(child: Text("Camera Preview Off")),
                ),

              if (_showDrawings)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DrawOverlayPainter(
                      allStrokes: _allDrawingStrokes,
                    ),
                    size: Size(c.maxWidth, c.maxHeight),
                  ),
                ),

              if (_allDrawingStrokes.isEmpty && _showDrawings)
                Positioned(
                  bottom: 100,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Navigator can draw on your screen to help guide you',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Camera"),
              onPressed: () => _startSharing(SharingMode.camera),
              style: ElevatedButton.styleFrom(
                backgroundColor: _mode == SharingMode.camera
                    ? Colors.green
                    : null,
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.screen_share),
              label: const Text("Screen"),
              onPressed: () => _startSharing(SharingMode.screen),
              style: ElevatedButton.styleFrom(
                backgroundColor: _mode == SharingMode.screen
                    ? Colors.orange
                    : null,
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text("Stop"),
              onPressed: _stopSharing,
              style: ElevatedButton.styleFrom(
                backgroundColor: _mode == SharingMode.none ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawOverlayPainter extends CustomPainter {
  final List<List<Map<String, dynamic>>> allStrokes;
  _DrawOverlayPainter({required this.allStrokes});

  @override
  void paint(Canvas c, Size size) {
    for (final stroke in allStrokes) {
      if (stroke.isEmpty) continue;

      final paint = Paint()
        ..strokeWidth = stroke.first['strokeWidth'] as double
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final String mode = stroke.first['mode'] as String;
      if (mode == 'draw') {
        paint.color = _hexToColor(stroke.first['color']).withOpacity(0.9);
      } else {
        paint.color = Colors.white.withOpacity(0.9);
        paint.strokeWidth *= 2;
      }

      if (stroke.length > 1) {
        final path = Path()..moveTo(stroke[0]['x'], stroke[0]['y']);
        for (var i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i]['x'], stroke[i]['y']);
        }
        c.drawPath(path, paint);
      } else {
        c.drawCircle(
          Offset(stroke[0]['x'], stroke[0]['y']),
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
      }
    }
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  bool shouldRepaint(covariant _DrawOverlayPainter old) =>
      allStrokes != old.allStrokes;
}
