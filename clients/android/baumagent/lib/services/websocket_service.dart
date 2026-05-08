import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

class WebSocketService {
  Stream<WsFrame> stream(String baseUrl, String taskId, String token) async* {
    final wsUrl = baseUrl
        .replaceFirst(RegExp(r'^http'), 'ws')
        .replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$wsUrl/ws/tasks/$taskId/logs?token=$token');

    int delaySeconds = 1;

    while (true) {
      WebSocketChannel? channel;
      try {
        channel = WebSocketChannel.connect(uri);
        await channel.ready;
        delaySeconds = 1;

        await for (final raw in channel.stream) {
          final frame = WsFrame.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
          yield frame;
          if (frame.type == 'done' || frame.type == 'error') return;
        }
        return;
      } catch (_) {
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds = (delaySeconds * 2).clamp(1, 30);
      } finally {
        await channel?.sink.close();
      }
    }
  }
}
