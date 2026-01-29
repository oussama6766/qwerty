import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/settings_provider.dart';
import '../screens/game_screen.dart';
import '../screens/skins_screen.dart';
import '../models/game_state.dart';
import '../game_logic/game_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  ControlMode _myControlMode = ControlMode.swipe;
  final _joinCodeController = TextEditingController();
  final _createCodeController = TextEditingController();
  bool _offlineWallPass = false;

  @override
  void initState() {
    super.initState();
    _checkAutoRejoin();
  }

  void _checkAutoRejoin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRoom = prefs.getString('last_room_id');
    final isHost = prefs.getBool('is_host_last') ?? false;

    if (lastRoom != null) {
      final room = await Supabase.instance.client
          .from('game_rooms')
          .select()
          .eq('room_code', lastRoom)
          .maybeSingle();
      if (room != null && room['status'] != 'finished' && context.mounted) {
        _showRejoinDialog(lastRoom, isHost, room);
      } else {
        await prefs.remove('last_room_id');
      }
    }
  }

  void _showRejoinDialog(String code, bool isHost, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          "مباراة جارية",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "هل تود العودة للمباراة السابقة؟ كود: $code",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    gameType: GameType.online,
                    roomId: code,
                    isHost: isHost,
                    controlMode: _myControlMode,
                    enableWallPassing: data['allow_wall_passing'] as bool,
                    enablePowerUps: (data['allow_powerups'] as bool?) ?? false,
                    enableObstacles:
                        (data['allow_obstacles'] as bool?) ?? false,
                    duration: data['game_duration'] as int,
                  ),
                ),
              );
            },
            child: const Text("العودة"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isNeon ? Colors.black : AppTheme.classicBg,
      body: Container(
        decoration: isNeon
            ? BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [const Color(0xFF1A1A1A), Colors.black],
                ),
              )
            : null,
        child: Stack(
          children: [
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  _buildLevelBox(settings, isNeon),
                  const SizedBox(width: 15),
                  _buildXPBar(settings, isNeon),
                ],
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 150),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('matchmaking'),
                        color: Colors.orangeAccent,
                        icon: Icons.flash_on,
                        isNeon: isNeon,
                        onPressed: () => _startMatchmaking(context, settings),
                      ),
                      const SizedBox(height: 15),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('play_offline'),
                        color: AppTheme.neonGreen,
                        icon: Icons.person,
                        isNeon: isNeon,
                        onPressed: () => _showOfflineOptions(context, settings),
                      ),
                      const SizedBox(height: 15),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('create_room'),
                        color: AppTheme.neonBlue,
                        icon: Icons.add_circle_outline,
                        isNeon: isNeon,
                        onPressed: () =>
                            _showCreateRoomDialog(context, settings),
                      ),
                      const SizedBox(height: 15),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('join_room'),
                        color: AppTheme.neonYellow,
                        icon: Icons.login,
                        isNeon: isNeon,
                        onPressed: () => _showJoinRoomDialog(context, settings),
                      ),
                      const SizedBox(height: 15),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('skins'),
                        color: Colors.purpleAccent,
                        icon: Icons.palette,
                        isNeon: isNeon,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SkinsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      IconButton(
                        icon: Icon(
                          Icons.settings,
                          color: isNeon
                              ? Colors.white54
                              : AppTheme.classicSnake,
                        ),
                        onPressed: () => _showSettingsDialog(context, settings),
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

  Widget _buildLevelBox(SettingsProvider s, bool isNeon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: isNeon
            ? AppTheme.neonBlue.withValues(alpha: 0.1)
            : Colors.black12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNeon ? AppTheme.neonBlue : AppTheme.classicSnake,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            s.getText('level'),
            style: TextStyle(
              color: isNeon ? AppTheme.neonBlue : AppTheme.classicSnake,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "${s.level}",
            style: TextStyle(
              color: isNeon ? Colors.white : AppTheme.classicSnake,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPBar(SettingsProvider s, bool isNeon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${s.xp % 500} / 500 ${s.getText('xp')}",
                style: TextStyle(
                  color: isNeon ? Colors.white70 : AppTheme.classicSnake,
                  fontSize: 12,
                ),
              ),
              Text(
                "المجموع: ${s.xp}",
                style: TextStyle(
                  color: isNeon ? Colors.white38 : AppTheme.classicSnake,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (s.xp % 500) / 500,
              backgroundColor: isNeon ? Colors.white10 : Colors.black12,
              color: isNeon ? AppTheme.neonGreen : AppTheme.classicSnake,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveButton(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isNeon,
  }) {
    return SizedBox(
      width: 280,
      child: isNeon
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                shadowColor: color.withValues(alpha: 0.5),
                elevation: 10,
                backgroundColor: Colors.transparent,
              ),
              onPressed: onPressed,
              icon: Icon(icon, color: color),
              label: Text(label, style: const TextStyle(fontSize: 16)),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onPressed,
              icon: Icon(icon, color: color),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  void _showOfflineOptions(BuildContext context, SettingsProvider s) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: s.currentTheme == GameTheme.neon
              ? AppTheme.surface
              : AppTheme.classicBg,
          title: Text(
            s.getText('play_offline'),
            style: TextStyle(
              color: s.currentTheme == GameTheme.neon
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.getText('wall_pass_label'),
                style: TextStyle(
                  color: s.currentTheme == GameTheme.neon
                      ? Colors.white
                      : Colors.black,
                ),
              ),
              Switch(
                value: _offlineWallPass,
                onChanged: (v) => setState(() => _offlineWallPass = v),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      gameType: GameType.offline,
                      controlMode: _myControlMode,
                      enableWallPassing: _offlineWallPass,
                      enablePowerUps: false,
                      enableObstacles: true,
                      duration: -1,
                    ),
                  ),
                );
              },
              child: Text(s.getText('create')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startMatchmaking(
    BuildContext context,
    SettingsProvider s,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final p = GameProvider();
    final result = await p.performMatchmaking();

    if (!context.mounted) return;
    Navigator.pop(context);

    if (result != null) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            gameType: GameType.online,
            roomId: result['room_code'] as String,
            isHost: false,
            controlMode: _myControlMode,
            enableWallPassing: result['allow_wall_passing'] as bool,
            enablePowerUps: (result['allow_powerups'] as bool?) ?? false,
            enableObstacles: (result['allow_obstacles'] as bool?) ?? false,
            duration: result['game_duration'] as int,
          ),
        ),
      );
    } else {
      String code = (1000 + Random().nextInt(9000)).toString();
      bool ok = await p.createRoomOnServer(code, false, false, false, 120);
      if (ok && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(
              gameType: GameType.online,
              roomId: code,
              isHost: true,
              controlMode: _myControlMode,
              enableWallPassing: false,
              enablePowerUps: false,
              enableObstacles: false,
              duration: 120,
            ),
          ),
        );
      }
    }
  }

  void _showCreateRoomDialog(BuildContext context, SettingsProvider s) {
    bool tempW = false, tempP = false, tempO = false, loading = false;
    int tempD = 120;
    _createCodeController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: s.currentTheme == GameTheme.neon
              ? AppTheme.surface
              : AppTheme.classicBg,
          title: Text(s.getText('create_room')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const CircularProgressIndicator()
                else ...[
                  // Removed manual code TextField
                  _buildToggle(
                    s.getText('wall_pass_label'),
                    tempW,
                    (v) => setState(() => tempW = v),
                    s,
                  ),
                  _buildToggle(
                    s.getText('powerups_label'),
                    tempP,
                    (v) => setState(() => tempP = v),
                    s,
                  ),
                  _buildToggle(
                    s.getText('obstacles_label'),
                    tempO,
                    (v) => setState(() => tempO = v),
                    s,
                  ),
                  DropdownButton<int>(
                    value: tempD,
                    dropdownColor: s.currentTheme == GameTheme.neon
                        ? AppTheme.surface
                        : AppTheme.classicBg,
                    items: [60, 120, -1]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              v == -1 ? s.getText('infinite') : "$v ثانية",
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => tempD = v!),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.getText('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() => loading = true);
                final p = GameProvider();

                // Always generate random 4-digit code
                String code = (1000 + Random().nextInt(9000)).toString();

                bool ok = await p.createRoomOnServer(
                  code,
                  tempW,
                  tempP,
                  tempO,
                  tempD,
                );

                // If creation fails (e.g. code taken), try one more time with a random code
                if (!ok) {
                  code = (1000 + Random().nextInt(9000)).toString();
                  ok = await p.createRoomOnServer(
                    code,
                    tempW,
                    tempP,
                    tempO,
                    tempD,
                  );
                }

                if (ok && context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        gameType: GameType.online,
                        roomId: code,
                        isHost: true,
                        controlMode: _myControlMode,
                        enableWallPassing: tempW,
                        enablePowerUps: tempP,
                        enableObstacles: tempO,
                        duration: tempD,
                      ),
                    ),
                  );
                } else if (context.mounted) {
                  setState(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.getText('room_creation_failed'))),
                  );
                }
              },
              child: Text(s.getText('create')),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context, SettingsProvider s) {
    _joinCodeController.clear();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: s.currentTheme == GameTheme.neon
              ? AppTheme.surface
              : AppTheme.classicBg,
          title: Text(s.getText('join_room')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                TextField(
                  controller: _joinCodeController,
                  decoration: InputDecoration(
                    hintText: s.getText('room_code_hint'),
                  ),
                  style: TextStyle(
                    color: s.currentTheme == GameTheme.neon
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.getText('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = _joinCodeController.text;
                if (code.isEmpty) return;
                setState(() => loading = true);
                final room = await Supabase.instance.client
                    .from('game_rooms')
                    .select()
                    .eq('room_code', code)
                    .eq('status', 'waiting')
                    .maybeSingle();
                if (room != null && context.mounted) {
                  await Supabase.instance.client
                      .from('game_rooms')
                      .update({'status': 'ready'})
                      .eq('room_code', code);
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        gameType: GameType.online,
                        roomId: code,
                        isHost: false,
                        controlMode: _myControlMode,
                        enableWallPassing: room['allow_wall_passing'] as bool,
                        enablePowerUps:
                            (room['allow_powerups'] as bool?) ?? false,
                        enableObstacles:
                            (room['allow_obstacles'] as bool?) ?? false,
                        duration: room['game_duration'] as int,
                      ),
                    ),
                  );
                } else if (context.mounted) {
                  setState(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.getText('invalid_code'))),
                  );
                }
              },
              child: Text(s.getText('join')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String l, bool v, Function(bool) c, SettingsProvider s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l,
          style: TextStyle(
            color: s.currentTheme == GameTheme.neon
                ? Colors.white
                : Colors.black,
            fontSize: 12,
          ),
        ),
        Switch(value: v, onChanged: c),
      ],
    );
  }

  void _showSettingsDialog(BuildContext context, SettingsProvider s) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, ss) => AlertDialog(
          backgroundColor: s.currentTheme == GameTheme.neon
              ? AppTheme.surface
              : AppTheme.classicBg,
          title: Text(s.getText('settings')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(s.getText('theme')),
                trailing: Text(
                  s.currentTheme == GameTheme.neon
                      ? s.getText('neon')
                      : s.getText('classic'),
                ),
                onTap: () {
                  s.toggleTheme();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(s.getText('controls')),
                trailing: Text(
                  _myControlMode == ControlMode.swipe ? "سحب" : "عصا تحكم",
                ),
                onTap: () {
                  if (mounted) {
                    ss(() {
                      _myControlMode = _myControlMode == ControlMode.swipe
                          ? ControlMode.joystick
                          : ControlMode.swipe;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
