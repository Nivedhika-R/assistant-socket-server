import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../services/socket_service.dart';

class NavigatorPage extends StatefulWidget {
  const NavigatorPage({super.key});

  @override
  State<NavigatorPage> createState() => _NavigatorPageState();
}

class _NavigatorPageState extends State<NavigatorPage> {
  final _socket = SocketService();
  Uint8List? _imageBytes;
  final List<Offset> _currentStroke = [];
  final List<List<Map<String, dynamic>>> _allStrokes = [];
  String _mode = 'draw';
  double _strokeWidth = 4.0;
  Color _drawColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  void _initializeSocket() {
    print("Navigator: Initializing socket connection");
    _socket.connect('ws://localhost:8080');
    
    // Wait a bit for connection to establish, then send role
    Future.delayed(const Duration(milliseconds: 500), () {
      _socket.sendRole('navigator');
    });
    
    _socket.onImageReceived = (data) {
      // print("Navigator: Received image data: ${data.length} bytes");
      setState(() => _imageBytes = data);
    };
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  void _sendDrawings(Size size) {
    if (_currentStroke.isEmpty) {
      print("Navigator: No current stroke to send");
      return;
    }
    
    print("Navigator: Sending drawing with ${_currentStroke.length} points");
    print("Navigator: Mode: $_mode, Color: ${_colorToHex(_drawColor)}, Stroke: $_strokeWidth");
    
    // Convert current stroke to the format expected by socket
    final strokeData = _currentStroke.map((point) => {
      'x': point.dx / size.width,
      'y': point.dy / size.height,
      'mode': _mode,
      'color': _colorToHex(_drawColor),
      'strokeWidth': _strokeWidth,
    }).toList();
    
    // Add to all strokes for local display
    _allStrokes.add(strokeData);
    
    // Send via socket
    _socket.sendDrawingPoints(
      _currentStroke, 
      size.width, 
      size.height, 
      _mode,
      color: _colorToHex(_drawColor), 
      strokeWidth: _strokeWidth
    );
    
    // Clear current stroke but keep the drawing visible
    setState(() {
      _currentStroke.clear();
    });
  }

  void _clearAllDrawings() {
    print("Navigator: Clearing all drawings");
    _socket.sendClearCommand();
    setState(() {
      _allStrokes.clear();
      _currentStroke.clear();
    });
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigator View'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Drawing Tools Panel
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Draw Mode Button
                ElevatedButton.icon(
                  onPressed: () => setState(() => _mode = 'draw'),
                  icon: const Icon(Icons.brush),
                  label: const Text('Draw'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mode == 'draw' ? Colors.blue : Colors.grey[300],
                    foregroundColor: _mode == 'draw' ? Colors.white : Colors.black,
                  ),
                ),
                
                // Erase Mode Button
                ElevatedButton.icon(
                  onPressed: () => setState(() => _mode = 'erase'),
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Erase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mode == 'erase' ? Colors.red : Colors.grey[300],
                    foregroundColor: _mode == 'erase' ? Colors.white : Colors.black,
                  ),
                ),
                
                // Clear All Button
                ElevatedButton.icon(
                  onPressed: _clearAllDrawings,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                // Color Picker
                if (_mode == 'draw') ...[
                  PopupMenuButton<Color>(
                    icon: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _drawColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                    onSelected: (color) => setState(() => _drawColor = color),
                    itemBuilder: (context) => [
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                      Colors.yellow,
                      Colors.purple,
                      Colors.orange,
                    ]
                        .map((color) => PopupMenuItem(
                              value: color,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          
          // Stroke Width Slider (only for draw mode)
          if (_mode == 'draw')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text('Brush Size: '),
                  Expanded(
                    child: Slider(
                      value: _strokeWidth,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      label: _strokeWidth.round().toString(),
                      onChanged: (value) => setState(() => _strokeWidth = value),
                    ),
                  ),
                  Text('${_strokeWidth.round()}'),
                ],
              ),
            ),
          
          // Drawing Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onPanStart: (details) {
                  setState(() => _currentStroke.add(details.localPosition));
                },
                onPanUpdate: (details) {
                  setState(() => _currentStroke.add(details.localPosition));
                },
                onPanEnd: (_) => _sendDrawings(Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                )),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      // Camera feed background
                      if (_imageBytes != null)
                        Positioned.fill(
                          child: Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text(
                              'Waiting for camera feed...',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ),
                        ),
                      
                      // Drawing overlay
                      CustomPaint(
                        painter: _DrawPainter(
                          currentStroke: _currentStroke,
                          allStrokes: _allStrokes,
                          mode: _mode,
                          strokeWidth: _strokeWidth,
                          color: _drawColor,
                        ),
                        size: Size.infinite,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawPainter extends CustomPainter {
  final List<Offset> currentStroke;
  final List<List<Map<String, dynamic>>> allStrokes;
  final String mode;
  final double strokeWidth;
  final Color color;

  _DrawPainter({
    required this.currentStroke,
    required this.allStrokes,
    required this.mode,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all completed strokes
    for (final stroke in allStrokes) {
      if (stroke.isEmpty) continue;
      
      final paint = Paint()
        ..strokeWidth = (stroke.first['strokeWidth'] as double)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final strokeMode = stroke.first['mode'] as String;
      if (strokeMode == 'draw') {
        final colorHex = stroke.first['color'] as String;
        paint.color = _hexToColor(colorHex);
      } else {
        paint.color = Colors.white;
        paint.strokeWidth = (stroke.first['strokeWidth'] as double) * 2;
      }

      final path = Path();
      final firstPoint = stroke.first;
      path.moveTo(
        (firstPoint['x'] as double) * size.width,
        (firstPoint['y'] as double) * size.height,
      );
      
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(
          (stroke[i]['x'] as double) * size.width,
          (stroke[i]['y'] as double) * size.height,
        );
      }
      
      canvas.drawPath(path, paint);
    }

    // Draw current stroke being drawn
    if (currentStroke.isNotEmpty) {
      final paint = Paint()
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (mode == 'draw') {
        paint.color = color;
      } else {
        paint.color = Colors.white;
        paint.strokeWidth = strokeWidth * 2;
      }

      if (currentStroke.length > 1) {
        final path = Path();
        path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
        
        for (int i = 1; i < currentStroke.length; i++) {
          path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
        }
        
        canvas.drawPath(path, paint);
      }
    }
  }

  Color _hexToColor(String hex) {
    final hexColor = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  bool shouldRepaint(covariant _DrawPainter oldDelegate) => true;
}

