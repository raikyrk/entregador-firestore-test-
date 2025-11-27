// main.dart - VERSÃO FINAL TURBINADA (atualização automática com estilo PRO)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  const AnimatedScaleButton({required this.onPressed, required this.child, super.key});

  @override
  State<AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onPressed(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_scale),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF28C38),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 5,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ao Gosto Carnes - Ent hibador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.black87)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF28C38),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 5,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFF28C38).withValues(alpha: 0.1), width: 1),
          ),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        ),
      ),
      home: const UpdateChecker(child: LoginScreen()),
    );
  }
}

class UpdateChecker extends StatefulWidget {
  final Widget child;
  const UpdateChecker({required this.child, super.key});
  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> with TickerProviderStateMixin {
  final _shorebird = ShorebirdCodePush();
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  bool _isChecking = true;
  bool _isDownloading = false;
  String _message = "Verificando atualizações...";

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
    _spinAnimation = Tween<double>(begin: 0, end: 1).animate(_spinController);
    _checkForUpdate();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    try {
      final hasUpdate = await _shorebird.isNewPatchAvailableForDownload();
      if (!hasUpdate) {
        if (mounted) setState(() => _isChecking = false);
        return;
      }

      setState(() {
        _isDownloading = true;
        _message = "Baixando nova versão...\nFica tranquilo, é rapidinho!";
      });

      await _shorebird.downloadUpdateIfAvailable();

      if (mounted) {
        setState(() => _message = "Tudo atualizado!\nReabra o app pra ver as novidades");
        await Future.delayed(const Duration(seconds: 2));
        _isChecking = false;
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking || _isDownloading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF28C38), Color(0xFFF5A623)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: _spinAnimation,
                  child: const Icon(Icons.autorenew_rounded, size: 90, color: Colors.white),
                ),
                const SizedBox(height: 40),
                Text(
                  _message,
                  style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (_isDownloading)
                  const SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 6),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}