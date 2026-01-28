import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/client.dart';
import 'core/settings_provider.dart';
import 'screens/menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        // GameProvider سنبقيه محلياً في GameScreen كما هو، أو نجعله هنا إذا أردنا مشاركة الحالة.
        // لكن SettingsProvider يجب أن يكون هنا.
      ],
      child: const SnakeGameApp(),
    ),
  );
}

class SnakeGameApp extends StatelessWidget {
  const SnakeGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Snake Rivals',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme, // سنقوم بتحديث AppTheme ليدعم التبديل
          home: const MenuScreen(),
          // دعم اتجاه النصوص من اليمين لليسار (العربية)
          builder: (context, child) {
            return Directionality(
              textDirection: settings.isArabic
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child!,
            );
          },
        );
      },
    );
  }
}
