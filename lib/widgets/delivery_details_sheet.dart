import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> delivery;

  const DeliveryDetailsSheet({super.key, required this.delivery});

  // Cores utilizadas no layout
  static const Color primary = Color(0xFFF28C38);
  static const Color success = Color(0xFF48BB78);
  static const Color danger = Color(0xFFE53E3E);
  static const Color info = Color(0xFF4299E1);
  static const Color dark = Color(0xFF1A202C);

  // Método estático para facilitar a chamada do modal de qualquer lugar
  static void show(BuildContext context, Map<String, dynamic> delivery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeliveryDetailsSheet(delivery: delivery),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Verificação de segurança para o telefone do cliente
    final String? rawPhone = delivery['cliente']?['telefone']?.toString();
    final bool hasValidPhone = rawPhone != null &&
        rawPhone != 'N/A' &&
        rawPhone.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.description_outlined, color: primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido #${delivery['id'] ?? '---'}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: dark,
                          ),
                        ),
                        Text(
                          delivery['timestamp_atribuicao'] != null
                              ? DateFormat('dd/MM/yyyy às HH:mm').format(
                                  (delivery['timestamp_atribuicao'] as Timestamp).toDate())
                              : 'Data não disponível',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    icon: Icons.location_on_outlined,
                    iconColor: danger,
                    title: 'Endereço de Entrega',
                    content: '${delivery['endereco']?['rua'] ?? 'N/A'}, ${delivery['endereco']?['numero'] ?? 'S/N'}\n'
                        '${delivery['endereco']?['bairro'] ?? 'N/A'}\n'
                        '${delivery['endereco']?['cidade'] ?? 'N/A'}',
                  ),
                  if (delivery['endereco']?['cep']?.toString().trim().isNotEmpty ?? false)
                    _buildDetailSection(
                      icon: Icons.pin_drop_outlined,
                      iconColor: info,
                      title: 'CEP',
                      content: delivery['endereco']?['cep'],
                    ),
                  _buildDetailSection(
                    icon: Icons.phone_outlined,
                    iconColor: success,
                    title: 'Contato',
                    content: rawPhone ?? 'N/A',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          onPressed: () => _showMapOptions(context, delivery),
                          icon: Icons.map_outlined,
                          label: 'Ver Mapa',
                          color: info,
                        ),
                      ),
                      // Correção do erro aqui: Removido o spread problemático
                      if (hasValidPhone) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            onPressed: () async {
                              final phone = rawPhone!.replaceAll(RegExp(r'\D'), '');
                              final formatted = phone.startsWith('55') ? phone : '55$phone';
                              final uri = Uri.parse('tel:+$formatted');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Não foi possível discar')),
                                  );
                                }
                              }
                            },
                            icon: Icons.phone,
                            label: 'Ligar',
                            color: success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(fontSize: 15, color: dark, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }

  void _showMapOptions(BuildContext context, Map<String, dynamic> deliveryData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Escolha o aplicativo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dark)),
            const SizedBox(height: 24),
            _buildMapOptionCard(context, 'Google Maps', Icons.map, const Color(0xFF4285F4), () => _openGoogleMaps(context, deliveryData)),
            const SizedBox(height: 12),
            _buildMapOptionCard(context, 'Waze', Icons.navigation, const Color(0xFF33CCFF), () => _openWaze(context, deliveryData)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMapOptionCard(
    BuildContext ctx,
    String title,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: dark)),
                  Text('Abrir navegação', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(BuildContext context, Map<String, dynamic> d) async {
    final addr = _buildAddressString(d);
    if (addr.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Endereço incompleto')));
      return;
    }
    final enc = Uri.encodeComponent(addr);
    final nav = Uri.parse('google.navigation:q=$enc');
    final fallback = Uri.parse('https://www.google.com/maps/search/?api=1&query=$enc');
    try {
      if (await canLaunchUrl(nav)) {
        await launchUrl(nav, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _openWaze(BuildContext context, Map<String, dynamic> d) async {
    final addr = _buildAddressString(d);
    if (addr.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Endereço incompleto')));
      return;
    }
    final enc = Uri.encodeComponent(addr);
    final waze = Uri.parse('waze://?q=$enc&navigate=yes');
    final fallback = Uri.parse('https://www.waze.com/ul?q=$enc');
    try {
      if (await canLaunchUrl(waze)) {
        await launchUrl(waze, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context);
  }

  String _buildAddressString(Map<String, dynamic> d) {
    final e = d['endereco'] ?? {};
    final rua = e['rua']?.toString().trim() ?? '';
    final num = e['numero']?.toString().trim() ?? '';
    final bairro = e['bairro']?.toString().trim() ?? '';
    final cidade = e['cidade']?.toString().trim() ?? '';
    final cep = e['cep']?.toString().trim() ?? '';

    if (rua.isEmpty && bairro.isEmpty && cidade.isEmpty) return '';

    final ruaLinha = num.isNotEmpty ? '$rua, $num' : rua;
    final buffer = <String>[];

    if (ruaLinha.isNotEmpty) buffer.add(ruaLinha);
    if (bairro.isNotEmpty) buffer.add(bairro);
    if (cidade.isNotEmpty) buffer.add(cidade);
    if (cep.isNotEmpty) buffer.add(cep);

    return buffer.join(', ');
  }
}