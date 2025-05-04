import 'package:flutter/material.dart';
import 'package:flutter_application_1/homScreen.dart';
import 'package:provider/provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setAutoTheme();
    });
  }

  void _setAutoTheme() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _themeMode = brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      title: 'YouTube Clone',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeNotifier.themeMode,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

// Import your full HomeScreen and VideoPlayerPage code from earlier here
// (Since you already posted the detailed HomeScreen and VideoPlayerPage in the previous message, simply keep them as-is and include them below this line.)

// -- Paste the complete HomeScreen and VideoPlayerPage code here --

