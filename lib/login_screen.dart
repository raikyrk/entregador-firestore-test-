// login_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'main.dart'; 
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  String? _errorMessage;
  static const String currentHash = 'v0'; // Hash da versão atual

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarAtualizacao();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  
  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
    });

    final pin = _pinController.text.trim();
    if (pin.isEmpty || pin.length != 4) {
      setState(() {
        _errorMessage = 'Digite um código de 4 dígitos.';
      });
      return;
    }

    try {
      
      final doc = await FirebaseFirestore.instance
          .collection('entregadores')
          .doc(pin)
          .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'Código inválido. Tente novamente.';
        });
        return;
      }

      final data = doc.data()!;
      final nomeEntregador = data['nome']?.toString().trim();
      if (nomeEntregador == null || nomeEntregador.isEmpty) {
        setState(() {
          _errorMessage = 'Erro: Nome do entregador não encontrado.';
        });
        return;
      }

      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('entregador', nomeEntregador);

      if (!mounted) return;

      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de conexão. Tente novamente.';
      });
    }
  }

  
  Future<void> _verificarAtualizacao() async {
    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final checkUpdateEndpoint = dotenv.env['CHECK_UPDATE_ENDPOINT'] ?? '';
      final apkDownloadUrl = dotenv.env['APK_DOWNLOAD_URL'] ?? '';

      if (baseUrl.isEmpty || checkUpdateEndpoint.isEmpty || apkDownloadUrl.isEmpty) {
        return;
      }

      final url = Uri.parse('$baseUrl$checkUpdateEndpoint');
      final response = await http
          .get(url, headers: {
            'Cache-Control': 'no-cache',
          })
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body); 
      if (data['status'] != 'success') return;

      final sha256Checksum = (data['sha256Checksum'] ?? '').toString().toLowerCase();
      final apkUrl = data['urlApk'] ?? '$baseUrl$apkDownloadUrl';
      final ultimaVersao = data['ultimaVersao'] ?? 'desconhecida';

      if (sha256Checksum.isEmpty || sha256Checksum == currentHash) return;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope( 
          canPop: false,
          child: AlertDialog(
            title: const Text('Atualização Obrigatória'),
            content: Text('Nova versão ($ultimaVersao) disponível! Atualize agora.'),
            actions: [
              TextButton(
                onPressed: () async {
                  final downloadUrl = Uri.parse('$apkUrl?ts=${DateTime.now().millisecondsSinceEpoch}');
                  if (await canLaunchUrl(downloadUrl)) {
                    await launchUrl(downloadUrl, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Atualizar'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Erro silencioso
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Título
              const Text(
                'Login - Ao Gosto Carnes',
                style: TextStyle(
                  fontSize: 26,
                  color: Color(0xFFF28C38),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // Campo PIN
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, letterSpacing: 8),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    counterText: '',
                    hintText: '____',
                    hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  obscureText: true,
                ),
              ),

              // Mensagem de erro
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),

              // Botão Entrar
              AnimatedScaleButton(
                onPressed: _login,
                child: const Text(
                  'Entrar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}