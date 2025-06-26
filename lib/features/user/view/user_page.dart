import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../services/socket_service.dart';

late List<CameraDescription> _cameras;

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

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    print("User: Initializing camera and socket");
    try {
      _cameras = await availableCameras();
      _controller = CameraController(_cameras[0], ResolutionPreset.medium);
      await _controller.initialize();

      _socket = SocketService();
      _socket.connect('ws://localhost:8080');
      
      // Wait for connection to establish, then send role
      await Future.delayed(const Duration(milliseconds: 1000));
      _socket.sendRole('user');
      
      // Set up drawing data callback
      _socket.onDrawReceived = (points) {
        print("User: Received drawing with ${points.length} points");
        print("User: Canvas size: $_canvasSize");
        
        if (points.isEmpty) {
          print("User: Ignoring empty points");
          return;
        }

        // Only process if we have valid canvas size
        if (_canvasSize.width <= 0 || _canvasSize.height <= 0) {
          print("User: Canvas size not ready, delaying processing");
          // Retry after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_canvasSize.width > 0 && _canvasSize.height > 0) {
              _processDrawingPoints(points);
            }
          });
          return;
        }
        
        _processDrawingPoints(points);
      };

      _socket.onClearReceived = () {
        print("User: Received clear command");
        setState(() {
          _allDrawingStrokes.clear();
        });
      };

      // Start sending camera frames
      _sendTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
        try {
          if (_controller.value.isInitialized) {
            final file = await _controller.takePicture();
            final bytes = await file.readAsBytes();
            _socket.sendFrame(bytes);
          }
        } catch (e) {
          debugPrint("Capture error: $e");
        }
      });

      setState(() {
        _isInitialized = true;
      });
      
      print("User: Camera and socket initialization complete");
    } catch (e) {
      print("User: Initialization error: $e");
    }
  }

  void _processDrawingPoints(List<Map<String, dynamic>> points) {
    setState(() {
      // Convert received normalized coordinates to screen coordinates
      final screenPoints = points.map((p) {
        final screenX = (p['x'] as double) * _canvasSize.width;
        final screenY = (p['y'] as double) * _canvasSize.height;
        
        print("User: Converting normalized (${p['x']}, ${p['y']}) to screen ($screenX, $screenY)");
        
        return {
          'x': screenX,
          'y': screenY,
          'mode': p['mode'] ?? 'draw',
          'color': p['color'] ?? '#FF0000',
          'strokeWidth': (p['strokeWidth'] as num?)?.toDouble() ?? 4.0,
        };
      }).toList();
      
      _allDrawingStrokes.add(screenPoints);
      print("User: Added stroke to display. Total strokes: ${_allDrawingStrokes.length}");
    });
  }

  // Method to update canvas size
  void _updateCanvasSize(Size size) {
    if (_canvasSize != size) {
      print("User: Canvas size updated from $_canvasSize to $size");
      setState(() {
        _canvasSize = size;
      });
    }
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    if (_controller.value.isInitialized) {
      _controller.dispose();
    }
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Camera'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showDrawings ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showDrawings = !_showDrawings),
            tooltip: _showDrawings ? 'Hide Drawings' : 'Show Drawings',
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              print("User: Debug info - Total strokes: ${_allDrawingStrokes.length}");
              print("User: Canvas size: $_canvasSize");
              print("User: Socket connected: ${_socket.isConnected}");
              print("User: Socket role: ${_socket.role}");
              
              for (int i = 0; i < _allDrawingStrokes.length; i++) {
                if (_allDrawingStrokes[i].isNotEmpty) {
                  final firstPoint = _allDrawingStrokes[i].first;
                  print("User: Stroke $i first point: (${firstPoint['x']}, ${firstPoint['y']})");
                }
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Update canvas size when layout changes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateCanvasSize(Size(constraints.maxWidth, constraints.maxHeight));
          });
          
          return Stack(
            children: [
              // Camera Preview
              if (_isInitialized && _controller.value.isInitialized)
                Positioned.fill(child: CameraPreview(_controller))
              else
                const Center(child: CircularProgressIndicator()),
              
              // Drawing Overlay
              if (_showDrawings)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DrawOverlayPainter(
                      allStrokes: _allDrawingStrokes,
                    ),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                ),
              
              // Status indicator
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _socket.isConnected ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _socket.isConnected ? 'Connected' : 'Disconnected',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${_socket.role ?? 'unknown'}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Strokes: ${_allDrawingStrokes.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Size: ${_canvasSize.width.toInt()}x${_canvasSize.height.toInt()}',
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Helper text when no drawings
              if (_allDrawingStrokes.isEmpty && _showDrawings)
                Positioned(
                  bottom: 100,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
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
    );
  }
}

class _DrawOverlayPainter extends CustomPainter {
  final List<List<Map<String, dynamic>>> allStrokes;

  _DrawOverlayPainter({
    required this.allStrokes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print("DrawOverlayPainter: Painting ${allStrokes.length} strokes on canvas size: $size");
    
    for (int strokeIndex = 0; strokeIndex < allStrokes.length; strokeIndex++) {
      final stroke = allStrokes[strokeIndex];
      if (stroke.isEmpty) {
        print("DrawOverlayPainter: Skipping empty stroke $strokeIndex");
        continue;
      }
      
      print("DrawOverlayPainter: Drawing stroke $strokeIndex with ${stroke.length} points");
      
      final paint = Paint()
        ..strokeWidth = (stroke.first['strokeWidth'] as double)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final mode = stroke.first['mode'] as String;
      if (mode == 'draw') {
        final colorHex = stroke.first['color'] as String;
        paint.color = _hexToColor(colorHex).withOpacity(0.9);
        print("DrawOverlayPainter: Draw mode - color: $colorHex");
      } else {
        paint.color = Colors.white.withOpacity(0.9);
        paint.strokeWidth = (stroke.first['strokeWidth'] as double) * 2;
        print("DrawOverlayPainter: Erase mode");
      }

      // Draw the stroke
      if (stroke.length > 1) {
        final path = Path();
        final firstPoint = stroke[0];
        final startX = firstPoint['x'] as double;
        final startY = firstPoint['y'] as double;
        
        // Clamp coordinates to canvas bounds
        final clampedStartX = startX.clamp(0.0, size.width);
        final clampedStartY = startY.clamp(0.0, size.height);
        
        path.moveTo(clampedStartX, clampedStartY);
        
        print("DrawOverlayPainter: Starting path at ($clampedStartX, $clampedStartY)");
        
        for (int i = 1; i < stroke.length; i++) {
          final point = stroke[i];
          final x = (point['x'] as double).clamp(0.0, size.width);
          final y = (point['y'] as double).clamp(0.0, size.height);
          path.lineTo(x, y);
        }
        
        canvas.drawPath(path, paint);
        print("DrawOverlayPainter: Drew path with ${stroke.length} points");
      } else if (stroke.length == 1) {
        // Draw a single point as a small circle
        final point = stroke[0];
        final x = (point['x'] as double).clamp(0.0, size.width);
        final y = (point['y'] as double).clamp(0.0, size.height);
        canvas.drawCircle(
          Offset(x, y),
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        print("DrawOverlayPainter: Drew single point at ($x, $y)");
      }
    }
  }

  Color _hexToColor(String hex) {
    final hexColor = hex.replaceAll('#', '');
    if (hexColor.length == 6) {
      return Color(int.parse('FF$hexColor', radix: 16));
    }
    return Colors.red; // Fallback color
  }

  @override
  bool shouldRepaint(covariant _DrawOverlayPainter oldDelegate) {
    final shouldRepaint = allStrokes != oldDelegate.allStrokes;
    if (shouldRepaint) {
      print("DrawOverlayPainter: Repainting due to stroke changes");
    }
    return shouldRepaint;
  }
}