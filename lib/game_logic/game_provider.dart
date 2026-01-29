import 'dart:async';
import 'dart:math';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../core/theme.dart';
import '../core/multiplayer_service.dart';
import '../core/client.dart';

enum ControlMode { swipe, joystick }

class GameProvider extends ChangeNotifier {
  static const int rows = 30;
  static const int columns = 20;
  static const int baseTickMs = 100; // Reduced for ultra-smooth feel
  int _tickCount = 0;

  late Snake player1;
  Snake? player2;
  Food? food;
  List<PowerUp> boardPowerUps = [];
  List<Position> obstacles = [];

  Ticker? _ticker;
  Duration _lastTickTime = Duration.zero;
  double interpolationProgress = 0.0;

  Timer? _countDownTimer;
  Timer? _heartbeatTimer;
  Timer? _aiTimer;

  bool isPlaying = false;
  bool isGameActive = false;
  int remainingTime = 120;
  int initialDuration = 120;
  bool isGameOver = false;
  String? winnerMessageKey;

  final Queue<Direction> _inputBuffer = Queue();
  bool enableWallPassing = false;
  bool enablePowerUps = false;
  bool enableObstacles = false;
  ControlMode controlMode = ControlMode.swipe;

  GameType currentGameType = GameType.offline;
  int startCountDown = 3;

  MultiplayerService? _multiplayerService;
  String? currentRoomId;
  bool isWaitingForPlayer = false;
  bool isConnectionLagging = false;

  String? player1Emoji;
  String? player2Emoji;
  Timer? _emojiTimer1;
  Timer? _emojiTimer2;

  final List<Map<String, dynamic>> _opponentMoveBuffer = [];

  GameProvider();

  Future<void> initGame(
    GameType type, {
    String? onlineRoomId,
    bool isHost = true,
    required ControlMode startControlMode,
    required bool startWallPassing,
    required bool startPowerUps,
    required bool startObstacles,
    required int startDuration,
    Color? playerColor,
    bool skipWaiting = false,
    required TickerProvider vsync,
  }) async {
    currentGameType = type;
    controlMode = startControlMode;
    enableWallPassing = startWallPassing;
    enablePowerUps = startPowerUps;
    enableObstacles = startObstacles;
    initialDuration = startDuration;
    currentRoomId = onlineRoomId;
    isWaitingForPlayer = (type == GameType.online && !skipWaiting);

    player1 = Snake(
      type: isHost ? PlayerType.host : PlayerType.guest,
      body: isHost
          ? [const Position(5, 5), const Position(5, 4), const Position(5, 3)]
          : [
              const Position(15, 25),
              const Position(15, 26),
              const Position(15, 27),
            ],
      direction: isHost ? Direction.down : Direction.up,
      color: playerColor ?? (isHost ? AppTheme.neonGreen : AppTheme.neonRed),
      score: 0,
    );

    if (type == GameType.online) {
      player2 = Snake(
        type: isHost ? PlayerType.guest : PlayerType.host,
        body: isHost
            ? [
                const Position(15, 25),
                const Position(15, 26),
                const Position(15, 27),
              ]
            : [
                const Position(5, 5),
                const Position(5, 4),
                const Position(5, 3),
              ],
        direction: isHost ? Direction.up : Direction.down,
        color: (playerColor == AppTheme.neonRed)
            ? AppTheme.neonGreen
            : AppTheme.neonRed,
        score: 0,
      );
      remainingTime = startDuration;
      if (onlineRoomId != null) {
        _setupOnlineConnection(onlineRoomId, isHost);
        _saveLastRoom(onlineRoomId, isHost);
      }
    } else {
      player2 = Snake(
        type: PlayerType.guest,
        body: [
          const Position(15, 25),
          const Position(15, 26),
          const Position(15, 27),
        ],
        direction: Direction.up,
        color: AppTheme.neonRed,
        score: 0,
      );
      remainingTime = startDuration;
      isWaitingForPlayer = false;
      _spawnInitialElements();
    }

    isPlaying = false;
    isGameActive = false;
    isGameOver = false;
    winnerMessageKey = null;
    startCountDown = 3;
    _tickCount = 0;
    _inputBuffer.clear();
    interpolationProgress = 0.0;
    _ticker?.dispose();
    _ticker = vsync.createTicker(_handleTicker);
    notifyListeners();
  }

  void _saveLastRoom(String roomId, bool isHost) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_room_id', roomId);
    await prefs.setBool('is_host_last', isHost);
  }

  void _setupOnlineConnection(String roomId, bool isHost) {
    _multiplayerService = MultiplayerService(
      roomId: roomId,
      onOpponentMove: (pos, dir, score) {
        _opponentMoveBuffer.add({'p': pos, 'd': dir, 's': score});
        if (_opponentMoveBuffer.length > 5) {
          _opponentMoveBuffer.removeAt(0);
        }
      },
      onFullSync: (body, foodPos, score) {
        if (player2 != null) {
          player2!.body = List.from(body);
          player2!.score = score;
          food = Food(position: foodPos, type: food?.type ?? FoodType.regular);
          notifyListeners();
        }
      },
      onGameOver: (winner) => _endGame(
        winner.toLowerCase() == "host"
            ? (isHost ? "win" : "lose")
            : (isHost ? "lose" : "win"),
      ),
      onStartGame: () {
        if (!isGameActive) {
          startMatchSequence(isRemoteTrigger: true);
        }
      },
      onFoodSpawn: (foodPos, type) {
        food = Food(position: foodPos, type: type);
        notifyListeners();
      },
      onPowerUpSpawn: (puPos, type) {
        boardPowerUps.add(
          PowerUp(position: puPos, type: type, spawnTime: DateTime.now()),
        );
        notifyListeners();
      },
      onObstaclesSync: (obs) {
        obstacles = obs;
        notifyListeners();
      },
      onReplayRequest: () {
        resetGame(isRemoteTrigger: true);
      },
      onOpponentEaten: () {
        if (isHost) {
          _spawnFood();
        }
      },
      onOpponentEmoji: (emoji) {
        player2Emoji = emoji;
        notifyListeners();
        _emojiTimer2?.cancel();
        _emojiTimer2 = Timer(const Duration(seconds: 3), () {
          player2Emoji = null;
          notifyListeners();
        });
      },
      onConnectionChanged: (online) {
        isConnectionLagging = !online;
        notifyListeners();
      },
    );
    _multiplayerService!.isHost = isHost;
    _multiplayerService!.connect();
  }

  void _handleTicker(Duration elapsed) {
    if (!isPlaying || isGameOver) {
      return;
    }
    final int elapsedMs = elapsed.inMilliseconds - _lastTickTime.inMilliseconds;
    if (elapsedMs >= baseTickMs) {
      _lastTickTime = elapsed;
      interpolationProgress = 0.0;
      _updateGameLoop();
    } else {
      interpolationProgress = elapsedMs / baseTickMs;
      notifyListeners();
    }
  }

  void _updateGameLoop() {
    _tickCount++;
    if (_tickCount % 1 == 0 || player1.hasPowerUp(PowerUpType.turbo)) {
      if (_inputBuffer.isNotEmpty) {
        player1.direction = _inputBuffer.removeFirst();
      }
      _moveSnake(player1);

      if (currentGameType == GameType.offline && player2 != null) {
        _handleAI(player2!);
        _moveSnake(player2!);
      }

      if (currentGameType == GameType.online && _multiplayerService != null) {
        _multiplayerService!.broadcastMove(
          player1.head,
          player1.direction,
          player1.score,
        );
      }

      if (currentGameType == GameType.online &&
          player2 != null &&
          _opponentMoveBuffer.isNotEmpty) {
        final move = _opponentMoveBuffer.removeAt(0);
        player2!.body.insert(0, move['p']);
        player2!.direction = move['d'];
        player2!.score = move['s'];
        if (player2!.body.length > (move['s'] / 10) + 3) {
          player2!.body.removeLast();
        }
      }
    }
    _checkCollisions(player1);
    if (player2 != null && currentGameType == GameType.offline) {
      _checkCollisions(player2!);
    }
    if (enablePowerUps &&
        (_multiplayerService?.isHost ?? true) &&
        _tickCount % 100 == 0) {
      _spawnPowerUp();
    }
    notifyListeners();
  }

  void _handleAI(Snake bot) {
    if (food == null) {
      return;
    }
    Position head = bot.head;
    Position target = food!.position;

    List<Direction> possibleDirs = [
      Direction.up,
      Direction.down,
      Direction.left,
      Direction.right,
    ];

    Direction current = bot.direction;
    if (current == Direction.up) {
      possibleDirs.remove(Direction.down);
    }
    if (current == Direction.down) {
      possibleDirs.remove(Direction.up);
    }
    if (current == Direction.left) {
      possibleDirs.remove(Direction.right);
    }
    if (current == Direction.right) {
      possibleDirs.remove(Direction.left);
    }

    possibleDirs.removeWhere((dir) {
      int nx = head.x, ny = head.y;
      if (dir == Direction.up) {
        ny--;
      } else if (dir == Direction.down) {
        ny++;
      } else if (dir == Direction.left) {
        nx--;
      } else if (dir == Direction.right) {
        nx++;
      }

      if (!enableWallPassing) {
        if (nx < 0 || nx >= columns || ny < 0 || ny >= rows) {
          return true;
        }
      } else {
        if (nx < 0) {
          nx = columns - 1;
        }
        if (nx >= columns) {
          nx = 0;
        }
        if (ny < 0) {
          ny = rows - 1;
        }
        if (ny >= rows) {
          ny = 0;
        }
      }
      Position next = Position(nx, ny);
      return _isPositionOccupied(next) || obstacles.contains(next);
    });

    if (possibleDirs.isEmpty) {
      return;
    }

    possibleDirs.sort((a, b) {
      int distA = _getDist(head, a, target);
      int distB = _getDist(head, b, target);
      return distA.compareTo(distB);
    });

    bot.direction = possibleDirs.first;
  }

  int _getDist(Position from, Direction d, Position to) {
    int nx = from.x, ny = from.y;
    if (d == Direction.up) {
      ny--;
    } else if (d == Direction.down) {
      ny++;
    } else if (d == Direction.left) {
      nx--;
    } else if (d == Direction.right) {
      nx++;
    }

    if (enableWallPassing) {
      int dx = (nx - to.x).abs();
      int dy = (ny - to.y).abs();
      dx = min(dx, columns - dx);
      dy = min(dy, rows - dy);
      return dx + dy;
    }
    return (nx - to.x).abs() + (ny - to.y).abs();
  }

  void _moveSnake(Snake snake) {
    if (!snake.isAlive) {
      return;
    }
    Position head = snake.head;
    int nx = head.x, ny = head.y;
    switch (snake.direction) {
      case Direction.up:
        ny--;
        break;
      case Direction.down:
        ny++;
        break;
      case Direction.left:
        nx--;
        break;
      case Direction.right:
        nx++;
        break;
    }
    if (enableWallPassing) {
      if (nx < 0) {
        nx = columns - 1;
      }
      if (nx >= columns) {
        nx = 0;
      }
      if (ny < 0) {
        ny = rows - 1;
      }
      if (ny >= rows) {
        ny = 0;
      }
    }
    Position next = Position(nx, ny);
    if (snake.hasPowerUp(PowerUpType.magnet) && food != null) {
      if ((next.x - food!.position.x).abs() <= 1 &&
          (next.y - food!.position.y).abs() <= 1) {
        next = food!.position;
      }
    }
    snake.body.insert(0, next);
    if (food != null && next == food!.position) {
      if (currentGameType == GameType.online &&
          !(_multiplayerService?.isHost ?? true)) {
        _multiplayerService!.broadcastEaten();
        food = null;
      } else {
        _processEating(snake);
      }
    } else {
      if (snake.body.length > (snake.score / 10) + 3) {
        snake.body.removeLast();
      }
    }
  }

  void _processEating(Snake snake) {
    if (food!.type == FoodType.gold) {
      snake.score += 50;
    } else if (food!.type == FoodType.rotten) {
      snake.score = max(0, snake.score - 20);
      for (int i = 0; i < 5; i++) {
        if (snake.body.length > 3) {
          snake.body.removeLast();
        }
      }
    } else {
      snake.score += 10;
    }
    _spawnFood();
  }

  void _spawnFood() async {
    final random = Random();
    Position p;
    do {
      p = Position(random.nextInt(columns), random.nextInt(rows));
    } while (_isPositionOccupied(p));

    FoodType type = FoodType.regular;
    if (enablePowerUps) {
      int r = random.nextInt(100);
      if (r < 5) {
        type = FoodType.gold;
      } else if (r < 10) {
        type = FoodType.rotten;
      }
    }
    food = Food(position: p, type: type);
    if (currentGameType == GameType.online &&
        (_multiplayerService?.isHost ?? false)) {
      _multiplayerService!.broadcastFood(food!.position, food!.type);
    }
    notifyListeners();
  }

  void _startHeartbeat() {
    if (currentGameType == GameType.online &&
        (_multiplayerService?.isHost ?? false)) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (isPlaying && !isGameOver && food != null) {
          _multiplayerService!.broadcastFullSync(
            player1.body,
            food!.position,
            player1.score,
          );
        }
      });
    }
  }

  void startMatchSequence({bool isRemoteTrigger = false}) async {
    isWaitingForPlayer = false;
    if (isGameActive && startCountDown < 3) {
      return;
    }
    isGameActive = true;
    isPlaying = false;
    startCountDown = 3;
    notifyListeners();
    if (!isRemoteTrigger && (_multiplayerService?.isHost ?? false)) {
      _multiplayerService!.broadcastStart();
      if (enableObstacles) {
        _multiplayerService!.broadcastObstacles(obstacles);
      }
    }
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (startCountDown > 0) {
        startCountDown--;
        notifyListeners();
      } else {
        t.cancel();
        _startMoving();
      }
    });
  }

  void _startMoving() {
    isPlaying = true;
    _lastTickTime = Duration.zero;
    _ticker?.start();
    _startHeartbeat();
    _countDownTimer?.cancel();
    if (remainingTime != -1) {
      _countDownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (remainingTime > 0) {
          remainingTime--;
          notifyListeners();
        } else {
          _endGameTimeUp();
        }
      });
    }
  }

  void changeDirection(PlayerType player, Direction newDir) {
    if (_inputBuffer.length >= 3) {
      return;
    }
    Direction last = _inputBuffer.isEmpty
        ? player1.direction
        : _inputBuffer.last;
    if ((last == Direction.left && newDir == Direction.right) ||
        (last == Direction.right && newDir == Direction.left) ||
        (last == Direction.up && newDir == Direction.down) ||
        (last == Direction.down && newDir == Direction.up) ||
        last == newDir) {
      return;
    }
    _inputBuffer.add(newDir);
  }

  void _checkCollisions(Snake snake) {
    Position head = snake.head;
    if (!enableWallPassing &&
        (head.x < 0 || head.x >= columns || head.y < 0 || head.y >= rows)) {
      _killSnake(snake, "wall_hit");
      return;
    }
    if (obstacles.contains(head)) {
      _killSnake(snake, "obstacle_hit");
      return;
    }
    if (!snake.hasPowerUp(PowerUpType.ghost)) {
      for (int i = 1; i < snake.body.length; i++) {
        if (snake.body[i] == head) {
          _killSnake(snake, "self_hit");
          return;
        }
      }
    }
  }

  void _spawnPowerUp() {
    final random = Random();
    Position p;
    do {
      p = Position(random.nextInt(columns), random.nextInt(rows));
    } while (_isPositionOccupied(p));
    PowerUpType type =
        PowerUpType.values[random.nextInt(PowerUpType.values.length)];
    boardPowerUps.add(
      PowerUp(position: p, type: type, spawnTime: DateTime.now()),
    );
    if (currentGameType == GameType.online &&
        (_multiplayerService?.isHost ?? false)) {
      _multiplayerService!.broadcastPowerUp(p, type);
    }
    notifyListeners();
  }

  void _killSnake(Snake snake, String key) {
    if (!snake.isAlive) {
      return;
    }
    snake.isAlive = false;
    _endGame(snake == player1 ? key : "win");
  }

  void _endGame(String key) {
    if (isGameOver) {
      return;
    }
    isGameOver = true;
    winnerMessageKey = key;
    isPlaying = false;
    _ticker?.stop();
    _heartbeatTimer?.cancel();
    _countDownTimer?.cancel();
    notifyListeners();
  }

  void _endGameTimeUp() {
    if (currentGameType == GameType.offline) {
      _endGame("time_up");
    } else {
      _endGame(player1.score > (player2?.score ?? 0) ? "win" : "lose");
    }
  }

  bool _isPositionOccupied(Position p) =>
      player1.body.contains(p) ||
      (player2?.body.contains(p) ?? false) ||
      obstacles.contains(p);

  void resetGame({bool isRemoteTrigger = false}) async {
    if (!isRemoteTrigger && (_multiplayerService?.isHost ?? true)) {
      if (currentGameType == GameType.online) {
        _multiplayerService?.broadcastReplay();
      }
    }

    // We need a reference to the TickerProvider to re-initialize
    final TickerProvider vsync = _ticker! as TickerProvider;

    initGame(
      currentGameType,
      onlineRoomId: currentRoomId,
      isHost: _multiplayerService?.isHost ?? true,
      startControlMode: controlMode,
      startWallPassing: enableWallPassing,
      startPowerUps: enablePowerUps,
      startObstacles: enableObstacles,
      startDuration: initialDuration,
      skipWaiting: true,
      vsync: vsync,
    );
  }

  void sendEmoji(String emoji) {
    player1Emoji = emoji;
    notifyListeners();
    _emojiTimer1?.cancel();
    _emojiTimer1 = Timer(const Duration(seconds: 3), () {
      player1Emoji = null;
      notifyListeners();
    });
    if (currentGameType == GameType.online) {
      _multiplayerService?.broadcastEmoji(emoji);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _heartbeatTimer?.cancel();
    _countDownTimer?.cancel();
    _aiTimer?.cancel();
    _multiplayerService?.leave();
    super.dispose();
  }

  void _spawnInitialElements() {
    obstacles.clear();
    if (enableObstacles) {
      final random = Random();
      for (int i = 0; i < 8; i++) {
        Position p;
        do {
          p = Position(random.nextInt(columns), random.nextInt(rows));
        } while (_isPositionOccupied(p));
        obstacles.add(p);
      }
    }
    _spawnFood();
  }

  Future<bool> createRoomOnServer(
    String c,
    bool w,
    bool p,
    bool o,
    int d,
  ) async {
    try {
      await SupabaseService.client.from('game_rooms').insert({
        'room_code': c,
        'status': 'waiting',
        'allow_wall_passing': w,
        'allow_powerups': p,
        'allow_obstacles': o,
        'game_duration': d,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> joinRoomOnServer(String c) async {
    try {
      final d = await SupabaseService.client
          .from('game_rooms')
          .select()
          .eq('room_code', c)
          .eq('status', 'waiting')
          .maybeSingle();
      if (d != null) {
        await SupabaseService.client
            .from('game_rooms')
            .update({'status': 'ready'})
            .eq('room_code', c);
      }
      return d;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> performMatchmaking() async {
    try {
      final d = await SupabaseService.client
          .from('game_rooms')
          .select()
          .eq('status', 'waiting')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (d != null) {
        await SupabaseService.client
            .from('game_rooms')
            .update({'status': 'ready'})
            .eq('room_code', d['room_code']);
      }
