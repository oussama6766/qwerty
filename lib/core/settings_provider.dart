import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

enum GameTheme { neon, classic }

enum Language { en, ar }

class SettingsProvider extends ChangeNotifier {
  GameTheme _currentTheme = GameTheme.neon;
  Language _currentLanguage = Language.ar;

  int _xp = 0;
  int _level = 1;
  String _selectedSkin = 'default';

  SettingsProvider() {
    _loadSettings();
  }

  GameTheme get currentTheme => _currentTheme;
  Language get currentLanguage => _currentLanguage;
  int get xp => _xp;
  int get level => _level;
  String get selectedSkin => _selectedSkin;
  bool get isArabic => _currentLanguage == Language.ar;

  final Map<String, Color> skinColors = {
    'default': AppTheme.neonGreen,
    'lava': Colors.deepOrange,
    'cyber': Colors.cyanAccent,
    'classic': Colors.black87,
    'royal': Colors.amberAccent,
  };

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _xp = prefs.getInt('xp') ?? 0;
    _level = (_xp / 500).floor() + 1;
    _currentTheme = GameTheme.values[prefs.getInt('theme') ?? 0];
    _currentLanguage = Language.ar; // Force Arabic
    _selectedSkin = prefs.getString('skin') ?? 'default';
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('xp', _xp);
    await prefs.setInt('theme', _currentTheme.index);
    await prefs.setInt('lang', _currentLanguage.index);
    await prefs.setString('skin', _selectedSkin);
  }

  void setSelectedSkin(String skin) {
    _selectedSkin = skin;
    _saveSettings();
    notifyListeners();
  }

  void addXP(int amount) {
    _xp += amount;
    _level = (_xp / 500).floor() + 1;
    _saveSettings();
    notifyListeners();
  }

  void toggleTheme() {
    _currentTheme = _currentTheme == GameTheme.neon
        ? GameTheme.classic
        : GameTheme.neon;
    _saveSettings();
    notifyListeners();
  }

  String getText(String key) {
    final Map<String, Map<String, String>> localizedValues = {
      'play_offline': {'en': 'PLAY OFFLINE', 'ar': 'لعب بدون إنترنت'},
      'play_online': {'en': 'PLAY ONLINE', 'ar': 'لعب أونلاين'},
      'settings': {'en': 'SETTINGS', 'ar': 'الإعدادات'},
      'language': {'en': 'Language', 'ar': 'اللغة'},
      'theme': {'en': 'Theme', 'ar': 'المظهر'},
      'neon': {'en': 'Neon', 'ar': 'نيون'},
      'classic': {'en': 'Classic', 'ar': 'كلاسيك'},
      'create_room': {'en': 'Create Room', 'ar': 'إنشاء غرفة'},
      'join_room': {'en': 'Join Room', 'ar': 'انضمام لغرفة'},
      'waiting_host': {'en': 'Waiting...', 'ar': 'بانتظار المضيف...'},
      'you': {'en': 'YOU', 'ar': 'أنت'},
      'rival': {'en': 'RIVAL', 'ar': 'الخصم'},
      'time': {'en': 'TIME', 'ar': 'الوقت'},
      'play_again': {'en': 'PLAY AGAIN', 'ar': 'العب مجدداً'},
      'game_over': {'en': 'GAME OVER', 'ar': 'انتهت اللعبة'},
      'snake': {'en': 'SNAKE', 'ar': 'ثعبان'},
      'xp': {'en': 'XP', 'ar': 'خبرة'},
      'level': {'en': 'LVL', 'ar': 'مستوى'},
      'skins': {'en': 'SKINS', 'ar': 'المظاهر'},
      'matchmaking': {'en': 'QUICK MATCH', 'ar': 'بحث سريع'},
      'infinite': {'en': 'INFINITE', 'ar': 'لا نهائي'},
      'win': {'en': 'You Won!', 'ar': 'لقد فزت!'},
      'lose': {'en': 'You Lost!', 'ar': 'لقد خسرت!'},
      'draw': {'en': 'Draw', 'ar': 'تعادل'},
      'time_up': {'en': "Time's Up!", 'ar': 'انتهى الوقت!'},
      'wall_hit': {'en': 'Hit the Wall!', 'ar': 'اصطدمت بالجدار!'},
      'obstacle_hit': {'en': 'Hit an Obstacle!', 'ar': 'اصطدمت بعائق!'},
      'self_hit': {'en': 'Collision!', 'ar': 'اصطدمت بنفسك!'},
      'wall_pass_label': {'en': 'Wall Pass', 'ar': 'تخطي الجدران'},
      'powerups_label': {'en': 'Power-ups', 'ar': 'القوى الخاصة'},
      'obstacles_label': {'en': 'Obstacles', 'ar': 'العوائق'},
      'cancel': {'en': 'Cancel', 'ar': 'إلغاء'},
      'create': {'en': 'Create', 'ar': 'إنشاء'},
      'join': {'en': 'Join', 'ar': 'انضمام'},
      'submit_score': {'en': 'Submit Score', 'ar': 'تسجيل النتيجة'},
      'your_name': {'en': 'Your Name', 'ar': 'اسمك'},
      'score_submitted': {'en': 'Score submitted!', 'ar': 'تم تسجيل النتيجة!'},
      'controls': {'en': 'Controls', 'ar': 'التحكم'},
      'room_code_hint': {'en': 'Enter Room Code', 'ar': 'أدخل كود الغرفة'},
      'invalid_code': {'en': 'Invalid Code', 'ar': 'كود غير صالح'},
    };
    return localizedValues[key]?['ar'] ?? key;
  }
}
