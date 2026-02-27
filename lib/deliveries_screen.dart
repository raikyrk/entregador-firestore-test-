// deliveries_screen.dart 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;

import 'dashboard_screen.dart';
import 'scanner_screen.dart';
import 'controllers/delivery_controller.dart';
import 'widgets/delivery_card.dart';
import 'widgets/draggable_floating_button.dart';

@immutable
class DeliveriesScreen extends StatefulWidget {
  final int initialTabIndex;

  const DeliveriesScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color primary = Color(0xFFF28C38);
  static const Color dark = Color(0xFF1A202C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final ctrl = DeliveryController.instance;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: ctrl.startDate, end: ctrl.endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2028, 12, 31),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primary),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: child,
          ),
        ),
      ),
    );

    if (picked != null) {
      ctrl.setDateRange(picked.start, picked.end);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Escuta o Controller Central
    return ListenableBuilder(
      listenable: DeliveryController.instance,
      builder: (context, child) {
        final ctrl = DeliveryController.instance;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: primary, size: 20),
              ),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              ),
            ),
            title: const Text(
              'Entregas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dark, letterSpacing: -0.5),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(colors: [primary, Color(0xFFFF9A56)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                  tabs: const [Tab(text: 'Em Andamento'), Tab(text: 'Concluídos')],
                ),
              ),
            ),
          ),
          body: Stack(
            children: [
              ctrl.isLoading
                  ? Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(primary)),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabecalho com Infos
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.white, Colors.grey[50]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Olá, ${ctrl.entregadorName.split(' ').first}',
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dark, letterSpacing: -0.5),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _tabController.index == 0
                                                ? 'Entregas pendentes'
                                                : 'De: ${DateFormat('dd/MM').format(ctrl.startDate)} até ${DateFormat('dd/MM').format(ctrl.endDate)}',
                                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_tabController.index == 1)
                                      Tooltip(
                                        message: 'Filtrar datas',
                                        child: InkWell(
                                          onTap: () => _selectDate(context),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                                            child: Icon(Icons.calendar_today_rounded, size: 20, color: Colors.grey[700]),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        icon: Icons.local_shipping_rounded,
                                        iconColor: const Color(0xFF4299E1),
                                        title: 'Total na Lista',
                                        value: '${_tabController.index == 0 ? ctrl.pendingDeliveries.length : ctrl.completedDeliveries.length}',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        icon: Icons.payments_rounded,
                                        iconColor: const Color(0xFF48BB78),
                                        title: 'A Receber (Lista)',
                                        value: 'R\$ ${NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2).format(_tabController.index == 0 ? ctrl.ganhosPendentes : ctrl.ganhosConcluidos)}',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Listas de Pedidos
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                ctrl.pendingDeliveries.isEmpty
                                    ? _buildEmptyState(icon: Icons.inventory_2_outlined, title: 'Nenhuma entrega pendente', subtitle: 'Você está em dia!')
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: ctrl.pendingDeliveries.length,
                                        itemBuilder: (_, i) => DeliveryCard(
                                          delivery: ctrl.pendingDeliveries[i],
                                          completed: false,
                                          index: i,
                                          onComplete: () => ctrl.markAsCompleted(ctrl.pendingDeliveries[i]['id']),
                                          onReturn: () => ctrl.returnToProcessing(ctrl.pendingDeliveries[i]['id']),
                                        ),
                                      ),
                                ctrl.completedDeliveries.isEmpty
                                    ? _buildEmptyState(icon: Icons.check_circle_outline, title: 'Nenhuma entrega no período', subtitle: 'Selecione outras datas.')
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: ctrl.completedDeliveries.length,
                                        itemBuilder: (_, i) => DeliveryCard(
                                          delivery: ctrl.completedDeliveries[i],
                                          completed: true,
                                          index: i,
                                          onComplete: () {}, 
                                          onReturn: () => ctrl.returnToProcessing(ctrl.completedDeliveries[i]['id']),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

              // Botão de Escanear
              DraggableFloatingButton(
                initialOffset: Offset(size.width - 80, size.height - 140 - kBottomNavigationBarHeight),
                onPressed: () async {
                  if (!(Platform.isAndroid || Platform.isIOS)) return;
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 12), Text('Pedido escaneado!')]),
                        backgroundColor: const Color(0xFF48BB78), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatCard({required IconData icon, required Color iconColor, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dark, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4))]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: Icon(icon, color: Colors.grey[400], size: 56)),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dark)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}