// dashboard_screen.dart
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'controllers/delivery_controller.dart';
import 'deliveries_screen.dart';
import 'scanner_screen.dart';
import 'widgets/bouncy_button.dart';
import 'widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final Color primaryOrange = const Color(0xFFF28C38);
  final Color deepOrange = const Color(0xFFE65100);
  final Color darkText = const Color(0xFF1A202C);
  final Color greyBackground = const Color(0xFFF7F9FC);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: const Duration(milliseconds: 2500), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutQuad));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DeliveryController.instance,
      builder: (context, child) {
        final ctrl = DeliveryController.instance;

        return Scaffold(
          backgroundColor: greyBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                children: [
                  _buildHeader(ctrl.entregadorName),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        _buildMainScanner(context),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Painel de Controle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: darkText, letterSpacing: -0.5)),
                            Icon(Icons.bar_chart_rounded, color: Colors.grey[400], size: 20),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDeliveriesAccessCard(context),
                        const SizedBox(height: 16),
                        
                        // SE ESTIVER CARREGANDO, MOSTRA UM CARREGAMENTO EM CIMA DOS CARDS
                        if (ctrl.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: LinearProgressIndicator(color: Color(0xFFF28C38), backgroundColor: Colors.transparent)),
                          ),

                        _buildStatsRow(context, ctrl),
                        const SizedBox(height: 24),
                        _buildPerformanceCard(ctrl),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

Widget _buildHeader(String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v1.0.1', 
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w600, 
                  color: Colors.grey[500], 
                  letterSpacing: 0.5
                )
              ),
              const SizedBox(height: 4),
              Text(
                name.isNotEmpty ? name.split(' ').first : 'Carregando...',
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.w900, 
                  color: darkText, 
                  letterSpacing: -1
                ),
              ),
            ],
          ),
          // Removido o botão de logout. 
          // Mantemos um ícone decorativo ou apenas o espaço para manter o alinhamento.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, color: primaryOrange, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScanner(BuildContext context) {
    return BouncyButton(
      onTap: () {
        if (!Platform.isAndroid && !Platform.isIOS) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
      },
      child: Container(
        height: 200, width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primaryOrange, deepOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: primaryOrange.withValues(alpha: 0.4), blurRadius: 25, offset: const Offset(0, 12))],
        ),
        child: Stack(
          children: [
            Positioned(right: -40, top: -40, child: Container(width: 180, height: 180, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle))),
            Positioned(left: 20, bottom: -60, child: Container(width: 140, height: 140, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle))),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(scale: _pulseAnimation,
                    child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, spreadRadius: 2)]),
                      child: Icon(Icons.qr_code_scanner, color: primaryOrange, size: 38),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Escaneia ai Lenda!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Toque para escanear', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveriesAccessCard(BuildContext context) {
    return BouncyButton(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DeliveriesScreen(initialTabIndex: 0))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.list_alt, color: deepOrange, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Painel de Entregas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkText)),
                  const SizedBox(height: 4),
                  Text('Visualizar e gerenciar histórico', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, DeliveryController ctrl) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Total Hoje',
            value: ctrl.isLoading ? '...' : ctrl.totalHoje.toString(),
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFF2196F3),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveriesScreen(initialTabIndex: 0))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            label: 'Concluídas',
            value: ctrl.isLoading ? '...' : ctrl.concluidasHoje.toString(),
            icon: Icons.check_circle_outline,
            color: const Color(0xFF4CAF50),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveriesScreen(initialTabIndex: 1))),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(DeliveryController ctrl) {
    final difference = ctrl.diferencaTempoStr;
    final isImprovement = difference.startsWith('-') && difference != '0 min';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: darkText, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: darkText.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tempo Médio', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(ctrl.isLoading ? '...' : ctrl.tempoMedioStr, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
            ],
          ),
          if (!ctrl.isLoading)
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isImprovement ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : const Color(0xFFF44336).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isImprovement ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : const Color(0xFFF44336).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(isImprovement ? Icons.trending_down : Icons.trending_up, color: isImprovement ? const Color(0xFF4CAF50) : const Color(0xFFF44336), size: 18),
                  const SizedBox(width: 6),
                  Text(difference.replaceAll('0 min', '--'), style: TextStyle(color: isImprovement ? const Color(0xFF4CAF50) : const Color(0xFFF44336), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            )
        ],
      ),
    );
  }
}