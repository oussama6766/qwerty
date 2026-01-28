import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client.dart';
import '../models/game_state.dart';

class MultiplayerService {
  late RealtimeChannel _channel;
  final String roomId;
  final Function(Position remoteHead, Direction remoteDir, int score)
  onOpponentMove;
  final Function(List<Position> body, Position food, int score) onFullSync;
  final Function(String winner) onGameOver;
  final Function() onStartGame;
  final Function(Position foodPos, FoodType type) onFoodSpawn;
  final Function(Position puPos, PowerUpType type) onPowerUpSpawn;
  final Function() onReplayRequest;
  final Function() onOpponentEaten;
  final Function(String emoji) onOpponentEmoji;
  final Function(List<Position> obs) onObstaclesSync;
  final Function(bool isOnline) onConnectionChanged;

  bool isHost = false;
  Timer? _disconnectTimer;

  MultiplayerService({
    required this.roomId,
    required this.onOpponentMove,
    required this.onFullSync,
    required this.onGameOver,
    required this.onStartGame,
    required this.onFoodSpawn,
    required this.onPowerUpSpawn,
    required this.onReplayRequest,
    required this.onOpponentEaten,
    required this.onOpponentEmoji,
    required this.onObstaclesSync,
    required this.onConnectionChanged,
  });

  Future<void> connect() async {
    _channel = SupabaseService.client.channel('v3_$roomId');

    _channel
        .onBroadcast(
          event: 'm', // Movement (Format: "x,y,dir,score")
          callback: (p) {
            _resetDisconnectTimer();
            final parts = (p['d'] as String).split(',');
            if (parts.length < 4) {
              return;
            }
            onOpponentMove(
              Position(int.parse(parts[0]), int.parse(parts[1])),
              Direction.values[int.parse(parts[2])],
              int.parse(parts[3]),
            );
          },
        )
        .onBroadcast(
          event: 's', // Full Sync
          callback: (p) {
            final mainParts = (p['d'] as String).split('|');
            final header = mainParts[0].split(',');
            final foodPos = Position(
              int.parse(header[2]),
              int.parse(header[3]),
            );
            final List<Position> body = [];
            for (int i = 1; i < mainParts.length; i++) {
              final b = mainParts[i].split(',');
              body.add(Position(int.parse(b[0]), int.parse(b[1])));
            }
            onFullSync(body, foodPos, int.parse(header[4]));
          },
        )
        .onBroadcast(event: 'go', callback: (p) => onGameOver(p['w'] as String))
        .onBroadcast(event: 'sg', callback: (_) => onStartGame())
        .onBroadcast(
          event: 'fs',
          callback: (p) => onFoodSpawn(
            Position(p['x'] as int, p['y'] as int),
            FoodType.values[p['t'] as int],
          ),
        )
        .onBroadcast(
          event: 'ps',
          callback: (p) => onPowerUpSpawn(
            Position(p['x'] as int, p['y'] as int),
            PowerUpType.values[p['t'] as int],
          ),
        )
        .onBroadcast(
          event: 'os',
          callback: (p) {
            final List raw = p['o'] as List;
            onObstaclesSync(
              raw.map((e) => Position(e['x'] as int, e['y'] as int)).toList(),
            );
          },
        )
        .onBroadcast(
          event: 'rm',
          callback: (_) {
            if (!isHost) {
              onReplayRequest();
            }
          },
        )
        .onBroadcast(
          event: 'f',
          callback: (_) {
            if (isHost) {
              onOpponentEaten();
            }
          },
        )
        .onBroadcast(
          event: 'e',
          callback: (p) {
            if (p['s'] != (isHost ? 'h' : 'g')) {
              onOpponentEmoji(p['e'] as String);
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            onConnectionChanged(true);
          } else {
            onConnectionChanged(false);
            _startDisconnectTimer();
          }
        });
  }

  void _resetDisconnectTimer() {
    _disconnectTimer?.cancel();
    onConnectionChanged(true);
  }

  void _startDisconnectTimer() {
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(
      const Duration(seconds: 10),
      () => onGameOver(isHost ? "guest" : "host"),
    );
  }

  Future<void> broadcastMove(Position head, Direction dir, int score) async {
    await _channel.sendBroadcastMessage(
      event: 'm',
      payload: {'d': "${head.x},${head.y},${dir.index},$score"},
    );
  }

  Future<void> broadcastFullSync(
    List<Position> body,
    Position food,
    int score,
  ) async {
    String data = "${body[0].x},${body[0].y},${food.x},${food.y},$score";
    for (var p in body) {
      data += "|${p.x},${p.y}";
    }
    await _channel.sendBroadcastMessage(event: 's', payload: {'d': data});
  }

  Future<void> broadcastStart() async =>
      await _channel.sendBroadcastMessage(event: 'sg', payload: {});
  Future<void> broadcastFood(Position pos, FoodType type) async =>
      await _channel.sendBroadcastMessage(
        event: 'fs',
        payload: {'x': pos.x, 'y': pos.y, 't': type.index},
      );
  Future<void> broadcastPowerUp(Position pos, PowerUpType type) async =>
      await _channel.sendBroadcastMessage(
        event: 'ps',
        payload: {'x': pos.x, 'y': pos.y, 't': type.index},
      );
  Future<void> broadcastObstacles(List<Position> obs) async =>
      await _channel.sendBroadcastMessage(
        event: 'os',
        payload: {
          'o': obs.map((e) => {'x': e.x, 'y': e.y}).toList(),
        },
      );
  Future<void> broadcastEaten() async =>
      await _channel.sendBroadcastMessage(event: 'f', payload: {});
  Future<void> broadcastReplay() async =>
      await _channel.sendBroadcastMessage(event: 'rm', payload: {});
  Future<void> broadcastGameOver(String winner) async =>
      await _channel.sendBroadcastMessage(event: 'go', payload: {'w': winner});
  Future<void> broadcastEmoji(String emoji) async =>
      await _channel.sendBroadcastMessage(
        event: 'e',
        payload: {'s': isHost ? 'h' : 'g', 'e': emoji},
      );

  Future<void> leave() async {
    _disconnectTimer?.cancel();
    await SupabaseService.client.removeChannel(_channel);
  }
}
