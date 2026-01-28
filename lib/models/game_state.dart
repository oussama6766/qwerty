import 'package:flutter/material.dart';

enum Direction { up, down, left, right }

enum PlayerType { host, guest }

enum GameType { offline, online }

enum FoodType { regular, gold, rotten }

enum PowerUpType { turbo, ghost, magnet }

class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class PowerUp {
  final Position position;
  final PowerUpType type;
  final DateTime spawnTime;

  PowerUp({
    required this.position,
    required this.type,
    required this.spawnTime,
  });
}

class Snake {
  final PlayerType type;
  List<Position> body;
  Direction direction;
  Color color;
  int score;
  bool isAlive;

  // Active power-ups with their expiration times
  Map<PowerUpType, DateTime> activePowerUps = {};

  Snake({
    required this.type,
    required this.body,
    required this.direction,
    required this.color,
    this.score = 0,
    this.isAlive = true,
  });

  Position get head => body.first;

  bool hasPowerUp(PowerUpType type) {
    if (!activePowerUps.containsKey(type)) return false;
    if (DateTime.now().isAfter(activePowerUps[type]!)) {
      activePowerUps.remove(type);
      return false;
    }
    return true;
  }
}

class Food {
  final Position position;
  final FoodType type;

  Food({required this.position, this.type = FoodType.regular});
}
