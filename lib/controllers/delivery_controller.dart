import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/delivery_status.dart';

class DeliveryController extends ChangeNotifier {
  static final DeliveryController instance = DeliveryController._internal();
  DeliveryController._internal();

  String entregadorName = '';
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> pendingDeliveries = [];
  List<Map<String, dynamic>> completedDeliveries = [];

  int totalHoje = 0;
  int concluidasHoje = 0;
  int pendentesHoje = 0;
  double ganhosPendentes = 0.0;
  double ganhosConcluidos = 0.0;
  String tempoMedioStr = '0 min';
  String diferencaTempoStr = '0 min';

  late DateTime startDate;
  late DateTime endDate;

  StreamSubscription? _pendingSub;
  StreamSubscription? _completedSub;

  Future<void> initialize() async {
    // Começa sempre como true para não mostrar lixo na tela
    isLoading = true; 
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    entregadorName = prefs.getString('entregador') ?? '';
    
    if (entregadorName.isEmpty) {
      isLoading = false;
      errorMessage = 'Entregador não logado';
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    _listenToStreams();
  }

  void setDateRange(DateTime start, DateTime end) {
    startDate = DateTime(start.year, start.month, start.day);
    endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    isLoading = true; // Volta a carregar ao mudar a data
    notifyListeners();
    _listenToCompleted();
  }

  void _listenToStreams() {
    final firestore = FirebaseFirestore.instance;
    _pendingSub?.cancel();
    
    _pendingSub = firestore.collection('pedidos')
        .where('entregador', isEqualTo: entregadorName)
        .where('status', whereIn: [
          DeliveryStatus.pendente, 
          DeliveryStatus.emAndamento, 
          DeliveryStatus.saiuParaEntrega
        ])
        .snapshots().listen((snapshot) {
          pendingDeliveries = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['is_completed'] = false;
            data['taxa_entrega'] = (data['pagamento']?['taxa_entrega'] ?? 0).toDouble();
            return data;
          }).toList();
          
          _calculateMetrics();
          isLoading = false; 
          notifyListeners(); 
    });

    _listenToCompleted();
  }

  void _listenToCompleted() {
    final firestore = FirebaseFirestore.instance;
    _completedSub?.cancel();

    _completedSub = firestore.collection('pedidos')
        .where('entregador', isEqualTo: entregadorName)
        .where('status', isEqualTo: DeliveryStatus.concluido)
        .snapshots().listen((snapshot) {
          
          final List<Map<String, dynamic>> filteredList = [];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final ts = data['data_conclusao'] as Timestamp?;
            if (ts == null) continue;
            
            final date = ts.toDate();
            if (date.isAfter(startDate) && date.isBefore(endDate)) {
              data['id'] = doc.id;
              data['is_completed'] = true;
              data['taxa_entrega'] = (data['pagamento']?['taxa_entrega'] ?? 0).toDouble();
              filteredList.add(data);
            }
          }

          completedDeliveries = filteredList;
          _calculateMetrics();
          isLoading = false; 
          notifyListeners(); 
    });
  }

  void _calculateMetrics() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    pendentesHoje = pendingDeliveries.where((d) {
      final ts = d['timestamp_atribuicao'] as Timestamp?;
      return ts != null && ts.toDate().isAfter(todayStart);
    }).length;

    ganhosPendentes = pendingDeliveries.fold(0.0, (sum, item) => sum + (item['taxa_entrega'] as double));

    List<Map<String, dynamic>> todayCompleted = [];
    List<Map<String, dynamic>> yesterdayCompleted = [];
    ganhosConcluidos = 0.0;

    for (var d in completedDeliveries) {
      final ts = d['data_conclusao'] as Timestamp?;
      if (ts == null) continue;
      final date = ts.toDate();
      ganhosConcluidos += (d['taxa_entrega'] as double);

      if (date.isAfter(todayStart)) {
        todayCompleted.add(d);
      } else if (date.isAfter(yesterdayStart) && date.isBefore(todayStart)) {
        yesterdayCompleted.add(d);
      }
    }

    concluidasHoje = todayCompleted.length;
    totalHoje = pendentesHoje + concluidasHoje;

    double todayAvg = 0.0;
    if (todayCompleted.isNotEmpty) {
      double totalMin = todayCompleted.fold(0.0, (sum, doc) => sum + ((doc['duracao_minutos'] ?? 0) as num).toDouble());
      todayAvg = totalMin / todayCompleted.length;
    }

    double yesterdayAvg = 0.0;
    if (yesterdayCompleted.isNotEmpty) {
      double totalMin = yesterdayCompleted.fold(0.0, (sum, doc) => sum + ((doc['duracao_minutos'] ?? 0) as num).toDouble());
      yesterdayAvg = totalMin / yesterdayCompleted.length;
    }

    tempoMedioStr = todayAvg >= 60 ? '${(todayAvg / 60).floor()}h ${(todayAvg % 60).round()}m' : '${todayAvg.round()} min';

    final diff = todayAvg - yesterdayAvg;
    diferencaTempoStr = diff == 0 ? '0 min' : diff >= 60 
        ? '${diff > 0 ? '+' : '-'}${(diff.abs() / 60).floor()}h ${(diff.abs() % 60).round()}m' 
        : '${diff > 0 ? '+' : '-'}${diff.abs().round()} min';
  }

  Future<void> markAsCompleted(String id) async {
    final docRef = FirebaseFirestore.instance.collection('pedidos').doc(id);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final atribuicao = data['timestamp_atribuicao'] as Timestamp?;
    if (atribuicao == null) return;
    final duracao = DateTime.now().difference(atribuicao.toDate());
    await docRef.update({
      'status': DeliveryStatus.concluido,
      'data_conclusao': FieldValue.serverTimestamp(),
      'duracao_minutos': duracao.inMinutes.toDouble(),
    });
  }

  Future<void> returnToProcessing(String id) async {
    await FirebaseFirestore.instance.collection('pedidos').doc(id).update({
      'status': 'processando',
      'entregador': null,
      'timestamp_atribuicao': FieldValue.delete(),
    });
  }

  void logout() {
    _pendingSub?.cancel();
    _completedSub?.cancel();
    pendingDeliveries.clear();
    completedDeliveries.clear();
    entregadorName = '';
    notifyListeners();
  }
}