// dashboard_screen.dart - PROFESSIONAL & ROBUST UI
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

  // Cache
  String? _cachedEntregadorName;
  Map<String, dynamic>? _cachedDeliveries;
  Map<String, String>? _cachedAverageTime;
  bool _isRefreshing = false;

  // Cores da Marca (Profissional)
  final Color primaryOrange = const Color(0xFFF28C38);
  final Color deepOrange = const Color(0xFFE65100);
  final Color darkText = const Color(0xFF1A202C);
  final Color greyBackground = const Color(0xFFF7F9FC);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutQuad),
    );
    
    _loadCachedData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // --- LÓGICA (MANTIDA IGUAL) ---
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
        content: const Text('Dados atualizados com sucesso.', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: darkText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
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

  Future<Map<String, String>> _getAverageDeliveryTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entregador = prefs.getString('entregador') ?? '';
      if (entregador.isEmpty) return {'averageTime': '0 min', 'difference': '0 min'};

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

      Future<double> calculateAverageForDate(String dateStr) async {
        final start = DateTime.parse('$dateStr 00:00:00');
        final end = DateTime.parse('$dateStr 23:59:59');

        final snapshot = await FirebaseFirestore.instance
            .collection('pedidos')
            .where('entregador', isEqualTo: entregador)
            .where('status', isEqualTo: DeliveryStatus.concluido) 
            .get();

        final deliveries = snapshot.docs.where((doc) {
          final data = doc.data();
          if (!data.containsKey('data_conclusao') || data['data_conclusao'] == null) return false;
          final ts = data['data_conclusao'] as Timestamp;
          final date = ts.toDate();
          return date.isAfter(start) && date.isBefore(end);
        }).toList();

        if (deliveries.isEmpty) return 0.0;

        double totalMinutos = 0.0;
        for (var doc in deliveries) {
          final data = doc.data();
          double minutosDoPedido = 0.0;
          if (data.containsKey('duracao_minutos') && data['duracao_minutos'] != null) {
            final valor = data['duracao_minutos'];
            if (valor is int) minutosDoPedido = valor.toDouble();
            else if (valor is double) minutosDoPedido = valor;
            else if (valor is String) minutosDoPedido = double.tryParse(valor) ?? 0.0;
          }
          totalMinutos += minutosDoPedido;
        }
        return totalMinutos / deliveries.length;
      }

      final [todayAvg, yesterdayAvg] = await Future.wait([
        calculateAverageForDate(todayStr),
        calculateAverageForDate(yesterdayStr),
      ]);

      final avgStr = todayAvg >= 60
          ? '${(todayAvg / 60).floor()}h ${(todayAvg % 60).round()}m'
          : '${todayAvg.round()} min';

      final diff = todayAvg - yesterdayAvg;
      final diffStr = diff == 0
          ? '0 min'
          : diff >= 60
              ? '${diff > 0 ? '+' : '-'}${(diff.abs() / 60).floor()}h ${(diff.abs() % 60).round()}m'
              : '${diff > 0 ? '+' : '-'}${diff.abs().round()} min';

      final result = {'averageTime': avgStr, 'difference': diffStr};
      _cachedAverageTime = result;
      return result;
    } catch (e) {
      return {'averageTime': '-', 'difference': '-'};
    }
  }

  // ==================== UI CONSTRUÇÃO ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: greyBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: primaryOrange,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: Column(
              children: [
                _buildHeader(),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      
                      // Scanner Principal
                      _buildMainScanner(),
                      
                      const SizedBox(height: 32),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Painel de Controle', 
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.w800, 
                              color: darkText,
                              letterSpacing: -0.5
                            )
                          ),
                          Icon(Icons.bar_chart_rounded, color: Colors.grey[400], size: 20),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Card de Navegação para Entregas (O MAIS IMPORTANTE)
                      _buildDeliveriesAccessCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Grid de Estatísticas
                      _buildStatsRow(),
                      
                      const SizedBox(height: 24),
                      
                      // Card de Performance Dark
                      _buildPerformanceCard(),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              
              const SizedBox(height: 4),
              Text(
                _cachedEntregadorName?.split(' ').first ?? 'Entregador',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: darkText,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          _BouncyButton(
            onTap: () => _logout(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: greyBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Icon(Icons.logout_rounded, color: Colors.grey[600], size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScanner() {
    return _BouncyButton(
      onTap: () async {
        await _writeLog('Botão Scanner Pressionado');
        if (!Platform.isAndroid && !Platform.isIOS) return;
        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
        if (result == true || result == 'refresh') await _refreshDashboard();
      },
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryOrange, deepOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primaryOrange.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Elementos decorativos de fundo (Círculos sutis)
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              left: 20,
              bottom: -60,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
              ),
            ),
            
            // Conteúdo
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      // Ícone seguro e profissional
                      child: Icon(Icons.qr_code_scanner, color: primaryOrange, size: 38),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Escaneia ai Lenda!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Toque para escanear',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveriesAccessCard() {
    // Card Branco Sólido com Sombra Forte - Estilo Profissional
    return _BouncyButton(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const DeliveriesScreen(initialTabIndex: 0)));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0), // Laranja bem claro
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.list_alt, color: deepOrange, size: 28), // Ícone Seguro
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Painel de Entregas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visualizar e gerenciar histórico',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = _cachedDeliveries?['total'] ?? 0;
    final completed = _cachedDeliveries?['completed'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Hoje',
            value: total.toString(),
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFF2196F3),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveriesScreen(initialTabIndex: 0))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'Concluídas',
            value: completed.toString(),
            icon: Icons.check_circle_outline,
            color: const Color(0xFF4CAF50),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkText,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkText.withOpacity(0.3),
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
              Text(
                'Tempo Médio',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500),
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
                  ? const Color(0xFF4CAF50).withOpacity(0.2) 
                  : const Color(0xFFF44336).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isImprovement 
                  ? const Color(0xFF4CAF50).withOpacity(0.3) 
                  : const Color(0xFFF44336).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isImprovement ? Icons.trending_down : Icons.trending_up,
                  color: isImprovement ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  difference.replaceAll('0 min', '--'),
                  style: TextStyle(
                    color: isImprovement ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                    fontWeight: FontWeight.bold,
                    fontSize: 14
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

// === WIDGETS REUTILIZÁVEIS ===

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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