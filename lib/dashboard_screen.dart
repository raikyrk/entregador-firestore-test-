// dashboard_screen.dart - DESIGN ULTIMATE & CLEAN
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File, FileMode, Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'main.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';
import 'deliveries_screen.dart';
import 'dart:io';
import 'constants/delivery_status.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Cache e Variáveis
  String? _cachedEntregadorName;
  Map<String, dynamic>? _cachedDeliveries;
  Map<String, String>? _cachedAverageTime;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Pulso mais lento e elegante
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    
    _loadCachedData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ==================== LÓGICA DE BACKEND (MANTIDA) ====================
  // (Mantive toda a lógica intacta para garantir funcionamento)

  Future<void> _loadCachedData() async {
    await _getEntregadorName();
    await _getDailyDeliveries();
    await _getAverageDeliveryTime();
    if (mounted) setState(() {});
  }

  Future<void> _writeLog(String message) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/entregador.log');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('$timestamp: $message\n', mode: FileMode.append);
    } catch (e) {
      print('Log Error: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('entregador');
    await _writeLog('Usuário deslogado');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _loadCachedData();
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Painel atualizado.', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Future<String> _getEntregadorName() async {
    if (_cachedEntregadorName != null) return _cachedEntregadorName!;
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('entregador') ?? 'Entregador';
    _cachedEntregadorName = name;
    return name;
  }

  Future<Map<String, dynamic>> _getDailyDeliveries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entregador = prefs.getString('entregador') ?? '';
      if (entregador.isEmpty) return {'completed': 0, 'pending': 0, 'total': 0};

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('pedidos')
          .where('entregador', isEqualTo: entregador)
          .where('status', whereIn: [
            DeliveryStatus.pendente,
            DeliveryStatus.emAndamento,
            DeliveryStatus.saiuParaEntrega,
          ]).get();

      final pendingCount = pendingSnapshot.docs.where((doc) {
        final ts = doc['timestamp_atribuicao'] as Timestamp?;
        if (ts == null) return false;
        return DateFormat('yyyy-MM-dd').format(ts.toDate()) == today;
      }).length;

      final completedSnapshot = await FirebaseFirestore.instance
          .collection('pedidos')
          .where('entregador', isEqualTo: entregador)
          .where('status', isEqualTo: DeliveryStatus.concluido)
          .get();

      final completedCount = completedSnapshot.docs.where((doc) {
        final ts = doc['data_conclusao'] as Timestamp?;
        if (ts == null) return false;
        return DateFormat('yyyy-MM-dd').format(ts.toDate()) == today;
      }).length;

      final result = {
        'completed': completedCount,
        'pending': pendingCount,
        'total': pendingCount + completedCount,
      };
      _cachedDeliveries = result;
      return result;
    } catch (e) {
      return {'completed': 0, 'pending': 0, 'total': 0};
    }
  }

  // === TEMPO MÉDIO (VERSÃO ROBUSTA E COM LOGS) ===
  Future<Map<String, String>> _getAverageDeliveryTime() async {
    print('DEBUG: Iniciando cálculo de tempo médio...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final entregador = prefs.getString('entregador') ?? '';
      
      if (entregador.isEmpty) {
        print('DEBUG: Entregador não identificado.');
        return {'averageTime': '0 min', 'difference': '0 min'};
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

      // Função auxiliar interna
      Future<double> calculateAverageForDate(String dateStr) async {
        // Cria o intervalo de data (Início e Fim do dia)
        final start = DateTime.parse('$dateStr 00:00:00');
        final end = DateTime.parse('$dateStr 23:59:59');

        // Busca TODOS os pedidos concluídos deste entregador
        // (Nota: Filtrar por data no cliente é mais seguro se não tiver index composto)
        final snapshot = await FirebaseFirestore.instance
            .collection('pedidos')
            .where('entregador', isEqualTo: entregador)
            .where('status', isEqualTo: DeliveryStatus.concluido) 
            .get();

        print('DEBUG: Encontrados ${snapshot.docs.length} pedidos concluídos no total (antes do filtro de data).');

        // Filtra os pedidos do dia específico
        final deliveries = snapshot.docs.where((doc) {
          final data = doc.data();
          
          // Verifica se tem data de conclusão
          if (!data.containsKey('data_conclusao') || data['data_conclusao'] == null) {
            return false;
          }

          final ts = data['data_conclusao'] as Timestamp;
          final date = ts.toDate();
          
          // Verifica se está dentro do dia
          return date.isAfter(start) && date.isBefore(end);
        }).toList();

        print('DEBUG: Para a data $dateStr, restaram ${deliveries.length} pedidos.');

        if (deliveries.isEmpty) return 0.0;

        double totalMinutos = 0.0;
        
        for (var doc in deliveries) {
          final data = doc.data();
          double minutosDoPedido = 0.0;

          // --- LÓGICA DE CONVERSÃO SEGURA ---
          if (data.containsKey('duracao_minutos') && data['duracao_minutos'] != null) {
            final valor = data['duracao_minutos'];
            if (valor is int) {
              minutosDoPedido = valor.toDouble();
            } else if (valor is double) {
              minutosDoPedido = valor;
            } else if (valor is String) {
              minutosDoPedido = double.tryParse(valor) ?? 0.0;
            }
          }
          // ----------------------------------
          
          print('DEBUG: Pedido ${doc.id} levou $minutosDoPedido min');
          totalMinutos += minutosDoPedido;
        }

        final media = totalMinutos / deliveries.length;
        print('DEBUG: Média para $dateStr: $media');
        return media;
      }

      // Executa para hoje e ontem
      final [todayAvg, yesterdayAvg] = await Future.wait([
        calculateAverageForDate(todayStr),
        calculateAverageForDate(yesterdayStr),
      ]);

      // Formatação da String (ex: 1h 20m ou 80 min)
      final avgStr = todayAvg >= 60
          ? '${(todayAvg / 60).floor()}h ${(todayAvg % 60).round()}m'
          : '${todayAvg.round()} min';

      // Cálculo da diferença
      final diff = todayAvg - yesterdayAvg;
      final diffStr = diff == 0
          ? '0 min'
          : diff >= 60
              ? '${diff > 0 ? '+' : '-'}${(diff.abs() / 60).floor()}h ${(diff.abs() % 60).round()}m'
              : '${diff > 0 ? '+' : '-'}${diff.abs().round()} min';

      final result = {'averageTime': avgStr, 'difference': diffStr};
      
      // Atualiza o cache
      _cachedAverageTime = result;
      
      return result;

    } catch (e, stack) {
      print('ERRO CRÍTICO NO CÁLCULO DE TEMPO: $e');
      print(stack);
      return {'averageTime': 'Erro', 'difference': '-'};
    }
  }
  // ==================== UI ULTIMATE ====================

  @override
  Widget build(BuildContext context) {
    // Paleta de Cores Premium
    const Color bgBase = Color(0xFFF9FAFB); // Cinza muito leve
    const Color orangePrimary = Color(0xFFFF6B00); // Laranja Vibrante (Estilo iFood/Rappi)
    const Color textDark = Color(0xFF1F2937);

    return Scaffold(
      backgroundColor: bgBase,
      // Sem AppBar padrão. Usaremos um SafeArea com design customizado.
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: orangePrimary,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Cabeçalho Minimalista
                const SizedBox(height: 10),
                _buildCustomHeader(textDark),
                
                const SizedBox(height: 32),
                
                // 2. O Grande Botão (Hero Section)
                _buildHeroScanner(orangePrimary),
                
                const SizedBox(height: 32),
                
                // 3. Label de Seção
                Text(
                  'Visão Geral',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textDark.withOpacity(0.8),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 4. Grid de Estatísticas (Cards Flutuantes)
                _buildStatsGrid(),
                
                const SizedBox(height: 20),
                
                // 5. Card de Performance Dark
                _buildPerformanceCard(),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bom trabalho,',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _cachedEntregadorName?.split(' ').first ?? 'Parceiro',
              style: TextStyle(
                fontSize: 32,
                color: textColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
              ),
            ),
          ],
        ),
        // Botão de Sair discreto e elegante
        _BouncyButton(
          onTap: () => _logout(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.logout_rounded, color: Colors.grey[400], size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroScanner(Color primaryColor) {
    return _BouncyButton(
      onTap: () async {
        await _writeLog('Botão Scanner Pressionado');
        if (!Platform.isAndroid && !Platform.isIOS) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disponível apenas no Mobile')));
          return;
        }
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScannerScreen()),
        );
        if (result == true || result == 'refresh') await _refreshDashboard();
      },
      child: Container(
        height: 280, // Card alto e imponente
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withRed(255).withGreen(140)], // Gradiente sutil
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 15), // Sombra colorida "Glow"
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Decorativo (Círculos abstratos)
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

            // Conteúdo Centralizado Real
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded, // Ícone moderno
                      size: 48,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Escanear Pedido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Toque para abrir a câmera',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final total = _cachedDeliveries?['total'] ?? 0;
    final completed = _cachedDeliveries?['completed'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCardClean(
            title: 'Total Hoje',
            value: '$total',
            icon: Icons.local_shipping_outlined,
            accentColor: const Color(0xFF3B82F6), // Azul
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveriesScreen(initialTabIndex: 0))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCardClean(
            title: 'Concluídas',
            value: '$completed',
            icon: Icons.check_circle_outline_rounded,
            accentColor: const Color(0xFF10B981), // Verde
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveriesScreen(initialTabIndex: 1))),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard() {
    final data = _cachedAverageTime ?? {'averageTime': '0 min', 'difference': '0 min'};
    final avgTime = data['averageTime']!;
    final difference = data['difference']!;
    final isImprovement = difference.startsWith('-') && difference != '0 min';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A), // Quase preto (Zinc 800)
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tempo Médio',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                avgTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isImprovement 
                  ? const Color(0xFF10B981).withOpacity(0.2) // Verde bg
                  : const Color(0xFFEF4444).withOpacity(0.2), // Vermelho bg
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isImprovement ? Icons.trending_down : Icons.trending_up,
                  color: isImprovement ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  difference.replaceAll('0 min', '--'),
                  style: TextStyle(
                    color: isImprovement ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==================== WIDGETS AUXILIARES ====================

// Card de Estatística Minimalista
class _StatCardClean extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _StatCardClean({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BouncyButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget de animação de toque (Bounce Effect)
class _BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncyButton({required this.child, required this.onTap});

  @override
  _BouncyButtonState createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<_BouncyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}