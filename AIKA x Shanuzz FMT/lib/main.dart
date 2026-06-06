import 'package:flutter/material.dart';
import 'services/pocketbase_service.dart';
import 'widgets/moon_phase_loader.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final pbService = PocketBaseService();
  await pbService.initialize();
  runApp(MyApp(pbService: pbService));
}

class MyApp extends StatelessWidget {
  final PocketBaseService pbService;

  const MyApp({super.key, required this.pbService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIKA x Shanuzz FMT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF9A825),
          primary: const Color(0xFFF9A825),
          secondary: const Color(0xFF424242),
          surface: const Color(0xFFF5F5F5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9A825),
          foregroundColor: Color(0xFF424242),
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFF9A825),
          foregroundColor: Color(0xFF424242),
        ),
        useMaterial3: true,
      ),
      home: SplashScreen(pbService: pbService),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  final PocketBaseService pbService;

  const SplashScreen({super.key, required this.pbService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Brief delay so the splash screen shows
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    if (widget.pbService.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(pbService: widget.pbService),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(pbService: widget.pbService),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'AIKA x Shanuzz FMT',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const MoonPhaseLoader(),
          ],
        ),
      ),
    );
  }
}
