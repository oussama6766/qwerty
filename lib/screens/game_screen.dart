import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../game_logic/game_provider.dart';
import '../models/game_state.dart';
import '../core/theme.dart';
import '../core/settings_provider.dart';

class GameScreen extends StatefulWidget {
  final GameType gameType;
  final String? roomId;
  final bool isHost;
  final ControlMode controlMode;
  final bool enableWallPassing;
  final bool enablePowerUps;
  final bool enableObstacles;
  final int duration;

  const GameScreen({
    super.key,
    required this.gameType,
    this.roomId,
    this.isHost = true,
    required this.controlMode,
    required this.enableWallPassing,
    this.enablePowerUps = false,
    this.enableObstacles = false,
    required this.duration,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameProvider _gameProvider;

  @override
  void initState() {
    super.initState();
    _gameProvider = GameProvider();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _gameProvider.initGame(
      widget.gameType,
      onlineRoomId: widget.roomId,
      isHost: widget.isHost,
      startControlMode: widget.controlMode,
      startWallPassing: widget.enableWallPassing,
      startPowerUps: widget.enablePowerUps,
      startObstacles: widget.enableObstacles,
      startDuration: widget.duration,
      playerColor: settings.skinColors[settings.selectedSkin],
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _gameProvider,
      child: const GameScreenContent(),
    );
  }

  @override
  void dispose() {
    _gameProvider.dispose();
    super.dispose();
  }
}

class GameScreenContent extends StatelessWidget {
  const GameScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;

    return Scaffold(
      backgroundColor: isNeon ? Colors.black : AppTheme.classicBg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: game.controlMode == ControlMode.swipe
            ? (details) {
                if (details.delta.dy > 5) {
                  game.changeDirection(PlayerType.host, Direction.down);
                } else if (details.delta.dy < -5) {
                  game.changeDirection(PlayerType.host, Direction.up);
                }
              }
            : null,
        onHorizontalDragUpdate: game.controlMode == ControlMode.swipe
            ? (details) {
                if (details.delta.dx > 5) {
                  game.changeDirection(PlayerType.host, Direction.right);
                } else if (details.delta.dx < -5) {
                  game.changeDirection(PlayerType.host, Direction.left);
                }
              }
            : null,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const GameHUD(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isNeon ? Colors.black : AppTheme.classicBg,
                          border: Border.all(
                            color: isNeon
                                ? AppTheme.neonBlue.withValues(alpha: 0.5)
                                : AppTheme.classicSnake,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(isNeon ? 12 : 0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isNeon ? 10 : 0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cellSize =
                                  (constraints.maxWidth / GameProvider.columns <
                                      constraints.maxHeight / GameProvider.rows)
                                  ? constraints.maxWidth / GameProvider.columns
                                  : constraints.maxHeight / GameProvider.rows;

                              final boardWidth =
                                  cellSize * GameProvider.columns;
                              final boardHeight = cellSize * GameProvider.rows;

                              return Center(
                                child: CustomPaint(
                                  size: Size(boardWidth, boardHeight),
                                  painter: GamePainter(
                                    game,
                                    settings,
                                    cellSize,
                                    cellSize,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const GameControls(),
                ],
              ),

              if (game.isConnectionLagging)
                Positioned(
                  top: 60,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.red, size: 16),
                        const SizedBox(width: 5),
                        Text(
                          "اتصال ضعيف",
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (game.enablePowerUps)
                Positioned(
                  top: 80,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: PowerUpType.values
                        .where((t) => game.player1.hasPowerUp(t))
                        .map((t) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: _getPowerUpColor(t)),
                            ),
                            child: Text(
                              t.name.toUpperCase(),
                              style: TextStyle(
                                color: _getPowerUpColor(t),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),

              if (game.controlMode == ControlMode.joystick &&
                  game.isGameActive &&
                  !game.isGameOver)
                Positioned(
                  bottom: 40,
                  right: 40,
                  child: Opacity(
                    opacity: 0.5,
                    child: Joystick(
                      mode: JoystickMode.all,
                      listener: (details) {
                        if (details.y < -0.5) {
                          game.changeDirection(PlayerType.host, Direction.up);
                        } else if (details.y > 0.5) {
                          game.changeDirection(PlayerType.host, Direction.down);
                        } else if (details.x < -0.5) {
                          game.changeDirection(PlayerType.host, Direction.left);
                        } else if (details.x > 0.5) {
                          game.changeDirection(
                            PlayerType.host,
                            Direction.right,
                          );
                        }
                      },
                    ),
                  ),
                ),

              if (game.isGameActive &&
                  !game.isPlaying &&
                  game.startCountDown > 0)
                Center(
                  child: Text(
                    "${game.startCountDown}",
                    style: const TextStyle(
                      fontSize: 100,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              if (game.isWaitingForPlayer)
                Container(
                  color: isNeon
                      ? Colors.black87
                      : AppTheme.classicBg.withValues(alpha: 0.9),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: isNeon
                              ? AppTheme.neonGreen
                              : AppTheme.classicSnake,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          settings.getText('waiting_host'),
                          style: TextStyle(
                            color: isNeon
                                ? Colors.white
                                : AppTheme.classicSnake,
                            fontSize: 18,
                          ),
                        ),
                        if (game.currentRoomId != null)
                          Text(
                            "كود الغرفة: ${game.currentRoomId}",
                            style: TextStyle(
                              color: isNeon
                                  ? AppTheme.neonYellow
                                  : AppTheme.classicSnake,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              if (game.isGameActive && !game.isGameOver)
                Positioned(
                  bottom: 100,
                  left: 20,
                  child: Column(
                    children: [
                      if (game.player1Emoji != null)
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            game.player1Emoji!,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      const SizedBox(height: 10),
                      IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () => _showEmojiPicker(context, game),
                      ),
                    ],
                  ),
                ),

              if (game.player2Emoji != null)
                Positioned(
                  top: 150,
                  right: 50,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      game.player2Emoji!,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context, GameProvider game) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: GridView.count(
          crossAxisCount: 5,
          children: ["😎", "😈", "😂", "😡", "😱", "🍎", "🔥", "💨", "💀", "👑"]
              .map(
                (e) => InkWell(
                  onTap: () {
                    game.sendEmoji(e);
                    Navigator.pop(ctx);
                  },
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 30)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.turbo:
        return Colors.orange;
      case PowerUpType.ghost:
        return Colors.white;
      case PowerUpType.magnet:
        return Colors.blue;
    }
  }
}

class GameHUD extends StatelessWidget {
  const GameHUD({super.key});

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isNeon ? AppTheme.surface : AppTheme.classicBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildScoreCard(
            settings.getText('you'),
            game.player1.score,
            isNeon ? AppTheme.neonGreen : AppTheme.classicSnake,
            isNeon,
          ),
          Column(
            children: [
              Text(
                settings.getText('time'),
                style: TextStyle(
                  color: isNeon ? Colors.white54 : AppTheme.classicSnake,
                  fontSize: 10,
                ),
              ),
              Text(
                game.remainingTime == -1 ? "∞" : "${game.remainingTime}",
                style: TextStyle(
                  color: isNeon ? Colors.white : AppTheme.classicSnake,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          game.player2 != null
              ? _buildScoreCard(
                  game.currentGameType == GameType.online
                      ? settings.getText('rival')
                      : "البوت",
                  game.player2!.score,
                  isNeon ? AppTheme.neonRed : AppTheme.classicSnake,
                  isNeon,
                )
              : const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int score, Color color, bool isNeon) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          "$score",
          style: TextStyle(
            color: isNeon ? Colors.white : AppTheme.classicSnake,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class GameControls extends StatelessWidget {
  const GameControls({super.key});

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;
    if (!game.isGameActive && !game.isGameOver && !game.isWaitingForPlayer) {
      final isHost =
          game.currentGameType == GameType.offline ||
          (game.player1.type == PlayerType.host);
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: isHost
            ? ElevatedButton(
                onPressed: game.startMatchSequence,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isNeon
                      ? AppTheme.neonGreen
                      : AppTheme.classicSnake,
                ),
                child: Text(
                  settings.getText('create').toUpperCase(),
                  style: TextStyle(
                    color: isNeon ? Colors.black : AppTheme.classicBg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Text(settings.getText('waiting_host')),
      );
    }
    if (game.isGameOver) {
      final isHost =
          game.currentGameType == GameType.offline ||
          (game.player1.type == PlayerType.host);
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              game.winnerMessageKey != null
                  ? settings.getText(game.winnerMessageKey!)
                  : settings.getText('game_over'),
              style: TextStyle(
                color: isNeon ? AppTheme.neonRed : AppTheme.classicSnake,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (isHost)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: game.resetGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNeon
                          ? AppTheme.neonGreen
                          : AppTheme.classicSnake,
                    ),
                    child: Text(
                      settings.getText('play_again'),
                      style: TextStyle(
                        color: isNeon ? Colors.black : AppTheme.classicBg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () =>
                        _processXP(context, settings, game.player1.score),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                    ),
                    child: const Text(
                      "حفظ",
                      style: TextStyle(color: Colors.black, fontSize: 10),
                    ),
                  ),
                ],
              )
            else
              Text(settings.getText('waiting_host')),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _processXP(BuildContext context, SettingsProvider settings, int score) {
    settings.addXP(score);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("تم إضافة الخبرة!")));
  }
}

class GamePainter extends CustomPainter {
  final GameProvider game;
  final SettingsProvider settings;
  final double cellWidth;
  final double cellHeight;
  GamePainter(this.game, this.settings, this.cellWidth, this.cellHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final isNeon = settings.currentTheme == GameTheme.neon;
    final gridPaint = Paint()
      ..color = isNeon
          ? Colors.white.withValues(alpha: 0.05)
          : AppTheme.classicSnake.withValues(alpha: 0.1);
    for (int i = 0; i <= GameProvider.columns; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        gridPaint,
      );
    }
    for (int i = 0; i <= GameProvider.rows; i++) {
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        gridPaint,
      );
    }

    final obsPaint = Paint()
      ..color = isNeon ? Colors.grey : AppTheme.classicSnake;
    for (var obs in game.obstacles) {
      canvas.drawRect(
        Rect.fromLTWH(
          obs.x * cellWidth + 2,
          obs.y * cellHeight + 2,
          cellWidth - 4,
          cellHeight - 4,
        ),
        obsPaint,
      );
    }
    if (game.enablePowerUps) {
      for (var pu in game.boardPowerUps) {
        canvas.drawCircle(
          Offset(
            pu.position.x * cellWidth + cellWidth / 2,
            pu.position.y * cellHeight + cellHeight / 2,
          ),
          cellWidth / 2.5,
          Paint()..color = _getPUColor(pu.type),
        );
      }
    }
    if (game.food != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          game.food!.position.x * cellWidth + 2,
          game.food!.position.y * cellHeight + 2,
          cellWidth - 4,
          cellHeight - 4,
        ),
        Paint()..color = _getFoodColor(game.food!.type, isNeon),
      );
    }

    _drawSnake(canvas, game.player1, isNeon, game.interpolationProgress);
    if (game.player2 != null) {
      _drawSnake(canvas, game.player2!, isNeon, game.interpolationProgress);
    }
  }

  Color _getPUColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.turbo:
        return Colors.orange;
      case PowerUpType.ghost:
        return Colors.white;
      case PowerUpType.magnet:
        return Colors.blue;
    }
  }

  Color _getFoodColor(FoodType type, bool isNeon) {
    if (!isNeon) return AppTheme.classicFood;
    switch (type) {
      case FoodType.regular:
        return AppTheme.neonYellow;
      case FoodType.gold:
        return Colors.amber;
      case FoodType.rotten:
        return Colors.purpleAccent;
    }
  }

  void _drawSnake(Canvas canvas, Snake snake, bool isNeon, double progress) {
    if (!snake.isAlive) {
      return;
    }
    double opacity = snake.hasPowerUp(PowerUpType.ghost) ? 0.5 : 1.0;
    final paint = Paint()
      ..color = (isNeon ? snake.color : AppTheme.classicSnake).withValues(
        alpha: opacity,
      );

    for (int i = 0; i < snake.body.length; i++) {
      Position current = snake.body[i];
      double drawX = current.x.toDouble();
      double drawY = current.y.toDouble();

      if (game.isPlaying) {
        Position next;
        if (i == 0) {
          next = _getNextPos(current, snake.direction);
        } else {
          next = snake.body[i - 1];
        }

        double targetX = next.x.toDouble();
        double targetY = next.y.toDouble();

        if ((targetX - drawX).abs() > 1) {
          if (targetX < drawX) {
            targetX += GameProvider.columns;
          } else {
            drawX += GameProvider.columns;
          }
        }
        if ((targetY - drawY).abs() > 1) {
          if (targetY < drawY) {
            targetY += GameProvider.rows;
          } else {
            drawY += GameProvider.rows;
          }
        }

        drawX = drawX + (targetX - drawX) * progress;
        drawY = drawY + (targetY - drawY) * progress;
      }

      final rect = Rect.fromLTWH(
        drawX * cellWidth + 1,
        drawY * cellHeight + 1,
        cellWidth - 2,
        cellHeight - 2,
      );

      // Draw body segment
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(isNeon ? 8 : 4)),
        paint,
      );

      // Draw eyes on head
      if (i == 0) {
        final eyePaint = Paint()..color = Colors.white;
        final pupilPaint = Paint()..color = Colors.black;
        double eyeSize = cellWidth * 0.15;
        double pupilSize = eyeSize * 0.5;

        // Eye offsets based on direction
        Offset eye1, eye2;
        switch (snake.direction) {
          case Direction.up:
            eye1 = Offset(
              rect.left + rect.width * 0.25,
              rect.top + rect.height * 0.25,
            );
            eye2 = Offset(
              rect.right - rect.width * 0.25,
              rect.top + rect.height * 0.25,
            );
            break;
          case Direction.down:
            eye1 = Offset(
              rect.left + rect.width * 0.25,
              rect.bottom - rect.height * 0.25,
            );
            eye2 = Offset(
              rect.right - rect.width * 0.25,
              rect.bottom - rect.height * 0.25,
            );
            break;
          case Direction.left:
            eye1 = Offset(
              rect.left + rect.width * 0.25,
              rect.top + rect.height * 0.25,
            );
            eye2 = Offset(
              rect.left + rect.width * 0.25,
              rect.bottom - rect.height * 0.25,
            );
            break;
          case Direction.right:
            eye1 = Offset(
              rect.right - rect.width * 0.25,
              rect.top + rect.height * 0.25,
            );
            eye2 = Offset(
              rect.right - rect.width * 0.25,
              rect.bottom - rect.height * 0.25,
            );
            break;
        }

        canvas.drawCircle(eye1, eyeSize, eyePaint);
        canvas.drawCircle(eye2, eyeSize, eyePaint);
        canvas.drawCircle(eye1, pupilSize, pupilPaint);
        canvas.drawCircle(eye2, pupilSize, pupilPaint);
      }
    }
  }

  Position _getNextPos(Position p, Direction d) {
    int nx = p.x, ny = p.y;
    if (d == Direction.up) {
      ny--;
    } else if (d == Direction.down) {
      ny++;
    } else if (d == Direction.left) {
      nx--;
    } else if (d == Direction.right) {
      nx++;
    }

    if (game.enableWallPassing) {
      if (nx < 0) {
        nx = GameProvider.columns - 1;
      }
      if (nx >= GameProvider.columns) {
        nx = 0;
      }
      if (ny < 0) {
        ny = GameProvider.rows - 1;
      }
      if (ny >= GameProvider.rows) {
        ny = 0;
      }
    }
    return Position(nx, ny);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
