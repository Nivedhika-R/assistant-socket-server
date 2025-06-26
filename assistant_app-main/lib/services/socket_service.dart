import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';

class SocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _role;

  // Callbacks for receiving data
  Function(Uint8List)? onImageReceived;
  Function(List<Map<String, dynamic>>)? onDrawReceived;
  Function()? onClearReceived;

  void connect(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      print("Connecting to WebSocket: $url");

      _channel!.stream.listen(
        (data) {
          
          if (data is Uint8List) {
            onImageReceived?.call(data);
          } else if (data is String) {
            
            // Handle role confirmation
            if (data.startsWith('ROLE_CONFIRMED:')) {
              final role = data.split(':')[1];
              print("Role confirmed: $role");
              _role = role;
              return;
            }
            
            try {
              final decoded = jsonDecode(data);
              print("Decoded JSON: $decoded");
              
              if (decoded['type'] == 'drawing') {
                final points = (decoded['points'] as List)
                    .map<Map<String, dynamic>>((p) => {
                          'x': (p['x'] as num).toDouble(),
                          'y': (p['y'] as num).toDouble(),
                          'mode': p['mode']?.toString() ?? 'draw',
                          'color': p['color']?.toString() ?? '#FF0000',
                          'strokeWidth': (p['strokeWidth'] as num?)?.toDouble() ?? 4.0,
                        })
                    .toList();
                print("Parsed drawing points: ${points.length} points");
                onDrawReceived?.call(points);
              } else if (decoded['type'] == 'clear') {
                onClearReceived?.call();
              }
            } catch (e) {
              print(e);
            }
          }
        },
        onError: (error) {
          print("WebSocket error: $error");
          _isConnected = false;
        },
        onDone: () {
          print("WebSocket connection closed");
          _isConnected = false;
        },
      );
    } catch (e) {
      print("Failed to connect to WebSocket: $e");
      _isConnected = false;
    }
  }

  void sendRole(String role) {
    if (_isConnected && _channel != null) {
      final message = "ROLE:$role";
      print("Sending role: $message");
      _channel!.sink.add(message);
      _role = role;
    } else {
      print("Cannot send role - not connected");
    }
  }

  void sendFrame(Uint8List bytes) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(bytes);
    } else {
      print("Cannot send frame - not connected");
    }
  }

  void sendDrawingPoints(
    List<Offset> points,
    double width,
    double height,
    String mode, {
    String color = '#FF0000',
    double strokeWidth = 4.0,
  }) {
    if (!_isConnected || _channel == null) {
      print("Cannot send drawing - not connected");
      return;
    }

    if (points.isEmpty) {
      print("No points to send");
      return;
    }

    try {
      final normalized = points
          .map((p) => {
                'x': p.dx / width,
                'y': p.dy / height,
                'mode': mode,
                'color': color,
                'strokeWidth': strokeWidth,
              })
          .toList();

      final message = {
        'type': 'drawing',
        'points': normalized,
        'from': _role ?? 'unknown',
      };

      final jsonMessage = jsonEncode(message);
      print("Sending drawing message: $jsonMessage");
      _channel!.sink.add(jsonMessage);
      print("Drawing sent successfully - ${points.length} points");
    } catch (e) {
      print("Failed to send drawing points: $e");
    }
  }

  void sendClearCommand() {
    if (!_isConnected || _channel == null) {
      print("Cannot send clear command - not connected");
      return;
    }

    try {
      final message = jsonEncode({
        'type': 'clear',
        'from': _role ?? 'unknown',
      });
      print("Sending clear command: $message");
      _channel!.sink.add(message);
    } catch (e) {
      print("Failed to send clear command: $e");
    }
  }

  bool get isConnected => _isConnected;
  String? get role => _role;

  void dispose() {
    print("Disposing WebSocket connection");
    _isConnected = false;
    _channel?.sink.close();
  }
}

// Helper function to convert Color to hex string
String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
}

// Helper function to convert hex string to Color
Color hexToColor(String hex) {
  final hexColor = hex.replaceAll('#', '');
  return Color(int.parse('FF$hexColor', radix: 16));
}