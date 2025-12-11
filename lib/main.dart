// main.dart - VERSÃO FINAL (Auth Check + Shorebird + Splash Screen)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importante para o login
import 'firebase_options.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart'; // Importante para ir direto ao painel

// ==========================================
// WIDGET UTILITÁRIO (Botão com Animação)
// ==========================================
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

// ==========================================
// MAIN APP
// ==========================================
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
      title: 'Ao Gosto Delivery',
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
            side: BorderSide(color: const Color(0xFFF28C38).withOpacity(0.1), width: 1),
          ),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        ),
      ),
      // AQUI MUDOU: Chamamos o AppBootstrap em vez do Login direto
      home: const AppBootstrap(),
    );
  }
}

// ==========================================
// TELA DE INICIALIZAÇÃO (SPLASH + UPDATE + AUTH)
// ==========================================
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> with TickerProviderStateMixin {
  final _shorebird = ShorebirdCodePush();
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  
  bool _isDownloading = false;
  String _message = "Iniciando sistema...";

  @override
  void initState() {
    super.initState();
    // Animação bonita do ícone girando
    _spinController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
    _spinAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.linear)
    );
    
    // Começa a mágica
    _initializeApp();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // 1. Verifica Atualizações (Shorebird)
    await _checkShorebirdUpdates();

    // 2. Verifica Login (SharedPreferences)
    if (mounted) {
      await _checkLoginAndNavigate();
    }
  }

  Future<void> _checkShorebirdUpdates() async {
    try {
      setState(() => _message = "Verificando atualizações...");
      
      final hasUpdate = await _shorebird.isNewPatchAvailableForDownload();
      if (hasUpdate) {
        setState(() {
          _isDownloading = true;
          _message = "Baixando nova versão...\nÉ rapidinho!";
        });

        await _shorebird.downloadUpdateIfAvailable();

        setState(() => _message = "Atualizado com sucesso!");
        await Future.delayed(const Duration(seconds: 1)); // Delay para ler a msg
      }
    } catch (e) {
      // Se der erro no update, segue a vida (não trava o app)
      print("Erro Shorebird: $e");
    }
  }

  Future<void> _checkLoginAndNavigate() async {
    setState(() => _message = "Verificando credenciais...");
    
    // Delay mínimo para a animação não ser "piscada" (opcional, remove sensação de bug)
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final prefs = await SharedPreferences.getInstance();
      final entregador = prefs.getString('entregador');

      if (!mounted) return;

      if (entregador != null && entregador.isNotEmpty) {
        // === USUÁRIO LOGADO -> DASHBOARD ===
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        // === NÃO LOGADO -> LOGIN ===
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      // Erro de disco? Vai pro login por segurança
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF28C38), Color(0xFFF5A623)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone Giratório
            RotationTransition(
              turns: _spinAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            
            // Texto de Status
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _message,
                key: ValueKey(_message),
                style: const TextStyle(
                  fontSize: 18, 
                  color: Colors.white, 
                  fontWeight: FontWeight.w600, 
                  height: 1.4,
                  letterSpacing: 0.5
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Barra de Progresso (só se estiver baixando)
            if (_isDownloading)
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}