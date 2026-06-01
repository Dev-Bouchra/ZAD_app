// lib/donateur/don_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../shared/zad_colors.dart';

class DonDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> don;

  const DonDetailsScreen({super.key, required this.don});

  String _getStatusLabel(String status) {
    switch (status) {
      case 'disponible': return 'En attente';
      case 'accepté':    return 'Accepté';
      case 'en_route':   return 'En route';
      case 'livré':      return 'Livré';
      case 'expiré':     return 'Expiré';
      case 'en cours':   return 'En cours';
      default:           return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'disponible': return ZADColors.warning;
      case 'accepté':    return ZADColors.primary;
      case 'en_route':   return ZADColors.primary;
      case 'en cours':   return ZADColors.primary;
      case 'livré':      return ZADColors.success;
      case 'expiré':     return ZADColors.danger;
      default:           return ZADColors.textLight;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '—';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return '—';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status    = don['status'] ?? 'disponible';
    final imageUrl  = don['imageUrl'] as String?;
    final isUrgent  = don['isUrgent'] == true;
    final title     = don['title'] ?? 'Don';
    final desc      = don['description'] ?? '—';
    final quantity  = don['quantity'] ?? '—';
    final address   = don['address'] ?? '—';
    final quartier  = don['quartier'] ?? '';
    final donorName = don['donorName'] ?? '—';
    final assocNom  = don['associationNom'] as String?;

    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);

    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            color: ZADColors.headerBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Détails du don',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ZADColors.danger,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('⚡ Urgent',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenu ──────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Image ──────────────────────────────────────────────────
                  if (imageUrl != null && imageUrl.isNotEmpty &&
                      !imageUrl.contains('placeholder'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : Container(
                                    height: 220,
                                    color: ZADColors.primarySoft,
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                        errorBuilder: (_, __, ___) => _NoImageBox(),
                      ),
                    )
                  else
                    _NoImageBox(),

                  const SizedBox(height: 16),

                  // ── Titre + statut ────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: ZADColors.textDark)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Infos détaillées ──────────────────────────────────────
                  _InfoCard(children: [
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: 'Donateur',
                      value: donorName,
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.description_outlined,
                      label: 'Description',
                      value: desc,
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.production_quantity_limits,
                      label: 'Quantité',
                      value: quantity,
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Adresse',
                      value: quartier.isNotEmpty
                          ? '$address — $quartier'
                          : address,
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Publié le',
                      value: _formatDate(don['createdAt']),
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.event_busy_outlined,
                      label: 'Expiration',
                      value: _formatDate(don['expiryDate']),
                    ),
                    if (assocNom != null) ...[
                      _Divider(),
                      _InfoRow(
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Association',
                        value: assocNom,
                      ),
                    ],
                  ]),

                  const SizedBox(height: 20),

                  // ── Badge urgent ──────────────────────────────────────────
                  if (isUrgent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: ZADColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: ZADColors.danger.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.flash_on,
                              color: ZADColors.danger, size: 20),
                          SizedBox(width: 8),
                          Text('Ce don est marqué comme urgent',
                              style: TextStyle(
                                  color: ZADColors.danger,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _NoImageBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: ZADColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              color: ZADColors.primary, size: 48),
          SizedBox(height: 8),
          Text('Pas de photo',
              style: TextStyle(
                  color: ZADColors.textMedium, fontSize: 13)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZADColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: ZADColors.textLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: ZADColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: ZADColors.divider);
  }
}
