// dashboard_screen.dart - CORRIGIDO COM LOGS DETALHADOS
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File, FileMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'main.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';
import 'deliveries_screen.dart';
import 'dart:io';
import 'constants/delivery_status.dart'; // IMPORTANTE: Use os mesmos status

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Cache
  String? _cachedEntregadorName;
  Map<String, dynamic>? _cachedDeliveries;
  Map<String, String>? _cachedAverageTime;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _loadCachedData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    print('DASHBOARD: Iniciando carregamento de dados...');
    await _getEntregadorName();
    await _getDailyDeliveries();
    await _getAverageDeliveryTime();
    if (mounted) setState(() {});
    print('DASHBOARD: Dados carregados e UI atualizada.');
  }

  Future<void> _writeLog(String message) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/entregador.log');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('$timestamp: $message\n', mode: FileMode.append);
      print('LOG: $message'); // LOG NO CONSOLE
    } catch (e) {
      print('ERRO AO ESCREVER LOG: $e');
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
    await _writeLog('Atualização manual do dashboard iniciada');
    await _loadCachedData();
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Painel atualizado!'),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // === NOME DO ENTREGADOR ===
  Future<String> _getEntregadorName() async {
    if (_cachedEntregadorName != null) {
      print('DASHBOARD: Nome do entregador (cache): $_cachedEntregadorName');
      return _cachedEntregadorName!;
    }
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('entregador') ?? 'Entregador';
    _cachedEntregadorName = name;
    print('DASHBOARD: Nome do entregador carregado: $name');
    await _writeLog('Nome do entregador obtido: $name');
    return name;
  }

  // === ENTREGAS DO DIA (COM FILTRO POR DATA) ===
  Future<Map<String, dynamic>> _getDailyDeliveries() async {
    print('DASHBOARD: Buscando entregas do dia...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final entregador = prefs.getString('entregador') ?? '';
      if (entregador.isEmpty) {
        print('DASHBOARD: ERRO - Entregador não encontrado no SharedPreferences');
        return {'completed': 0, 'pending': 0, 'total': 0};
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      print('DASHBOARD: Data de hoje: $today | Entregador: $entregador');

      // === PENDENTES: atribuídas hoje ===
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('pedidos')
          .where('entregador', isEqualTo: entregador)
          .where('status', whereIn: [
            DeliveryStatus.pendente,
            DeliveryStatus.emAndamento,
            DeliveryStatus.saiuParaEntrega,
          ])
          .get();

      print('DASHBOARD: Total de documentos pendentes (sem filtro): ${pendingSnapshot.docs.length}');

      final pendingCount = pendingSnapshot.docs.where((doc) {
        final ts = doc['timestamp_atribuicao'] as Timestamp?;
        if (ts == null) {
          print('DASHBOARD: Pedido ${doc.id} sem timestamp_atribuicao');
          return false;
        }
        final date = DateFormat('yyyy-MM-dd').format(ts.toDate());
        final match = date == today;
        if (match) {
          print('DASHBOARD: Pedido PENDENTE ${doc.id} atribuído hoje: $date');
        }
        return match;
      }).length;

      // === CONCLUÍDAS: concluídas hoje ===
      final completedSnapshot = await FirebaseFirestore.instance
          .collection('pedidos')
          .where('entregador', isEqualTo: entregador)
          .where('status', isEqualTo: DeliveryStatus.concluido)
          .get();

      print('DASHBOARD: Total de documentos concluídos (sem filtro): ${completedSnapshot.docs.length}');

      final completedCount = completedSnapshot.docs.where((doc) {
        final ts = doc['data_conclusao'] as Timestamp?;
        if (ts == null) {
          print('DASHBOARD: Pedido ${doc.id} concluído, mas sem data_conclusao');
          return false;
        }
        final date = DateFormat('yyyy-MM-dd').format(ts.toDate());
        final match = date == today;
        if (match) {
          print('DASHBOARD: Pedido CONCLUÍDO ${doc.id} finalizado hoje: $date');
        }
        return match;
      }).length;

      final result = {
        'completed': completedCount,
        'pending': pendingCount,
        'total': pendingCount + completedCount,
      };

      print('DASHBOARD: RESULTADO FINAL → Pendentes: $pendingCount | Concluídas: $completedCount | Total: ${result['total']}');
      _cachedDeliveries = result;
      await _writeLog('Entregas do dia: $result');
      return result;
    } catch (e, stack) {
      print('DASHBOARD: ERRO CRÍTICO ao buscar entregas: $e');
      print(stack);
      return {'completed': 0, 'pending': 0, 'total': 0};
    }
  }

  // === TEMPO MÉDIO ===
  Future<Map<String, String>> _getAverageDeliveryTime() async {
    print('DASHBOARD: Calculando tempo médio...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final entregador = prefs.getString('entregador') ?? '';
      if (entregador.isEmpty) return {'averageTime': '0 min', 'difference': '0 min'};

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

      Future<double> calculateAverageForDate(String dateStr) async {
        final start = DateTime.parse('$dateStr 00:00:00');
        final end = DateTime.parse('$dateStr 23:59:59');

        final snapshot = await FirebaseFirestore.instance
            .collection('pedidos')
            .where('entregador', isEqualTo: entregador)
            .where('status', isEqualTo: DeliveryStatus.concluido)
            .get();

        final deliveries = snapshot.docs.where((doc) {
          final ts = doc['data_conclusao'] as Timestamp?;
          if (ts == null) return false;
          final date = ts.toDate();
          return date.isAfter(start) && date.isBefore(end);
        }).toList();

        if (deliveries.isEmpty) return 0.0;

        double total = 0.0;
        for (var d in deliveries) {
          total += (d['duracao_minutos']?.toDouble() ?? 0.0);
        }
        return total / deliveries.length;
      }

      final [todayAvg, yesterdayAvg] = await Future.wait([
        calculateAverageForDate(today),
        calculateAverageForDate(yesterday),
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
      print('DASHBOARD: Tempo médio → Hoje: $avgStr | Diferença: $diffStr');
      _cachedAverageTime = result;
      return result;
    } catch (e) {
      print('DASHBOARD: Erro no tempo médio: $e');
      return {'averageTime': '0 min', 'difference': '0 min'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.logout, color: Color(0xFFF28C38), size: 20),
          ),
          onPressed: () => _logout(context),
          tooltip: 'Sair',
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF28C38), Color(0xFFF5A623)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.motorcycle, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Ao Gosto Delivery',
              style: TextStyle(
                color: Color(0xFF374151),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: const Color(0xFFF28C38),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildQRCodeCard(),
              const SizedBox(height: 20),
              _buildStatsCards(),
              const SizedBox(height: 20),
              _buildAverageTimeCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Olá,', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                Text(
                  _cachedEntregadorName ?? 'Entregador',
                  style: const TextStyle(fontSize: 24, color: Color(0xFFF28C38), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text('Bom trabalho hoje!', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isRefreshing ? null : _refreshDashboard,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFF28C38), Color(0xFFF5A623)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFFF28C38).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: _isRefreshing
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF28C38).withOpacity(0.2), width: 1.5),
                ),
                child: const Icon(Icons.person_rounded, color: Color(0xFFF28C38), size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await _writeLog('Botão Escanear QR Code pressionado');
          if (!Platform.isAndroid && !Platform.isIOS) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Escaneamento não disponível nesta plataforma.')),
            );
            return;
          }

          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScannerScreen()),
          );

          if (result == true || result == 'refresh') {
            print('DASHBOARD: Scanner retornou sucesso → Atualizando dashboard');
            await _refreshDashboard();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF28C38), Color(0xFFF5A623)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFFF28C38).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3 * _pulseAnimation.value),
                          blurRadius: 20 + (10 * _pulseAnimation.value),
                          spreadRadius: 5 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 40),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text('Escanear QR Code', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Toque para iniciar uma nova entrega', style: TextStyle(fontSize: 14, color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, color: Color(0xFFF28C38), size: 20),
                    SizedBox(width: 8),
                    Text('Toque aqui', style: TextStyle(fontSize: 15, color: Color(0xFFF28C38), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final total = _cachedDeliveries?['total'] ?? 0;
    final completed = _cachedDeliveries?['completed'] ?? 0;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))
      ]),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Suas Entregas', style: TextStyle(fontSize: 20, color: Color(0xFF374151), fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () async {
                  await _writeLog('Botão Ver Entregas pressionado');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveriesScreen()));
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Ver todas'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFF28C38)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total hoje',
                  value: '$total',
                  icon: Icons.inventory_2_rounded,
                  backgroundColor: const Color(0xFFFFF5E6),
                  iconColor: const Color(0xFFF28C38),
                  valueColor: const Color(0xFFF28C38),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveriesScreen(initialTabIndex: 0))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Concluídas',
                  value: '$completed',
                  icon: Icons.check_circle_rounded,
                  backgroundColor: const Color(0xFFE7F6E9),
                  iconColor: const Color(0xFF16A34A),
                  valueColor: const Color(0xFF16A34A),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveriesScreen(initialTabIndex: 1))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required Color valueColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 28, color: valueColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAverageTimeCard() {
    final data = _cachedAverageTime ?? {'averageTime': '0 min', 'difference': '0 min'};
    final avgTime = data['averageTime']!;
    final difference = data['difference']!;
    final isImprovement = difference.startsWith('-') && difference != '0 min';
    final color = difference.startsWith('+')
        ? const Color(0xFFEF4444)
        : difference == '0 min'
            ? const Color(0xFF6B7280)
            : const Color(0xFF16A34A);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF28C38), Color(0xFFF5A623)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFF28C38).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tempo Médio', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Por entrega hoje', style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.timer_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(avgTime, style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold, height: 1)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.3), width: 1))),
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isImprovement ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    const Text('vs. ontem', style: TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Text(difference, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
