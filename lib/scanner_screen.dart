import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/delivery_status.dart';

// --- SERVICE LAYER ---
class DeliveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> checkDuplicate(String id) async {
    try {
      final doc = await _firestore.collection('pedidos').doc(id).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final status = data['status']?.toString() ?? '';
      final entregador = data['entregador']?.toString() ?? '';
      return entregador.isNotEmpty &&
          entregador != '-' &&
          [DeliveryStatus.saiuParaEntrega, DeliveryStatus.concluido].contains(status);
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> assignDelivery(String id, String entregador) async {
    try {
      final docRef = _firestore.collection('pedidos').doc(id);
      final doc = await docRef.get();
      if (!doc.exists) return {'success': false, 'message': 'Pedido não encontrado'};
      
      await docRef.update({
        'entregador': entregador,
        'status': DeliveryStatus.saiuParaEntrega,
        'timestamp_atribuicao': FieldValue.serverTimestamp(),
      });
      return {'success': true, 'message': 'Sucesso'};
    } catch (_) {
      return null;
    }
  }
}

// --- UI SCREEN ---
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  MobileScannerController? _camCtrl;
  bool _processing = false;
  String? _entregador;
  Timer? _debounceTimer;
  String? _lastScannedId;
  late AnimationController _scanLineCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _scanLineAnim;
  late Animation<double> _pulseAnim;

  final Color primaryColor = const Color(0xFFF28C38);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    
    _scanLineCtrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _scanLineAnim = CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut);

    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _entregador = prefs.getString('entregador');
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final p = await Permission.camera.request();
    if (p.isGranted) {
      _camCtrl = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
      if (mounted) setState(() {});
    }
  }

  void _showStatus(String txt, {bool isError = false}) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(isError ? Icons.warning_amber_rounded : Icons.verified_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(txt, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.displayValue ?? '';
    final id = _extractId(raw);
    if (id == null || id == _lastScannedId) return;

    _lastScannedId = id;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () => _lastScannedId = null);

    await _processQRCode(id);
  }

  String? _extractId(String url) {
    try {
      final uri = Uri.tryParse(url);
      return uri?.queryParameters['id'] ?? url.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _processQRCode(String id) async {
    setState(() => _processing = true);
    
    final isDuplicate = await DeliveryService.checkDuplicate(id);
    if (isDuplicate) {
      _showStatus('Este pedido já está em rota!', isError: true);
      setState(() => _processing = false);
      return;
    }

    final result = await DeliveryService.assignDelivery(id, _entregador ?? '');
    if (result?['success'] == true) {
      _showStatus('Pedido Atribuído!');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } else {
      _showStatus('Erro ao processar QR Code', isError: true);
      setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    _camCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.75;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_camCtrl != null) MobileScanner(controller: _camCtrl!, onDetect: _onDetect),
          CustomPaint(size: Size(size.width, size.height), painter: ScannerOverlayPainter()),
          _buildHeader(),
          Center(
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.2 * _pulseAnim.value), width: 2),
                      ),
                    ),
                  ),
                  _buildCorners(scanAreaSize),
                  _buildScanLine(scanAreaSize),
                ],
              ),
            ),
          ),
          _buildBottomInfo(),
          if (_processing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('Scanner de Pedidos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_camCtrl?.torchEnabled == true ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
                  onPressed: () => _camCtrl?.toggleTorch(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanLine(double size) {
    return AnimatedBuilder(
      animation: _scanLineAnim,
      builder: (context, child) {
        return Positioned(
          top: _scanLineAnim.value * size,
          left: 0,
          right: 0,
          child: Container(
            height: 4,
            width: size,
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.6), blurRadius: 15, spreadRadius: 4)],
              gradient: LinearGradient(colors: [Colors.transparent, primaryColor, Colors.transparent]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCorners(double size) {
    return CustomPaint(
      size: Size(size, size),
      painter: CornerPainter(color: primaryColor),
    );
  }

  Widget _buildBottomInfo() {
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Alinhe o QR Code para bipar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white), strokeWidth: 6),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(15)),
                child: const Text('PROCESSANDO...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- CUSTOM PAINTERS ---

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    final scanAreaSize = size.width * 0.75;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: scanAreaSize, height: scanAreaSize);
    
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)), Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(40)))),
      paint,
    );
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CornerPainter extends CustomPainter {
  final Color color;
  CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    const radius = 40.0;
    const len = 30.0;

    canvas.drawPath(Path()..moveTo(0, len)..lineTo(0, radius)..arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius))..lineTo(len, 0), paint);
    canvas.drawPath(Path()..moveTo(size.width - len, 0)..lineTo(size.width - radius, 0)..arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius))..lineTo(size.width, len), paint);
    canvas.drawPath(Path()..moveTo(0, size.height - len)..lineTo(0, size.height - radius)..arcToPoint(Offset(radius, size.height), radius: const Radius.circular(radius))..lineTo(len, size.height), paint);
    canvas.drawPath(Path()..moveTo(size.width - len, size.height)..lineTo(size.width - radius, size.height)..arcToPoint(Offset(size.width, size.height - radius), radius: const Radius.circular(radius))..lineTo(size.width, size.height - len), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}