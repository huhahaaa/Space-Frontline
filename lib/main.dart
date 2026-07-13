import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_menu.dart';
import 'screens/level_select.dart';
import 'screens/monsterpedia.dart';
import 'screens/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const DefendTheTowerApp());
}

class DefendTheTowerApp extends StatelessWidget {
  const DefendTheTowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const MainMenuScreen(),
        '/levelSelect': (_) => const LevelSelectScreen(),
        '/monsterpedia': (_) => const MonsterpediaScreen(),
        '/game': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int? startWave;
          String? backgroundName;
          if (args is Map) {
            startWave = args['startWave'] as int?;
            backgroundName = args['backgroundName'] as String?;
          } else if (args is int) {
            startWave = args;
          }
          return GameScreen(startWave: startWave, backgroundName: backgroundName);
        },
      },
    );
  }
}
