import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../shared/zad_colors.dart';

// ─────────────────────────────────────────────
// SCREEN 13: CONFIRM COLLECTE
// MODIFIED: real Firestore data via donId
// ─────────────────────────────────────────────
class ConfirmCollecteScreen extends StatefulWidget {
  final String donId;

  const ConfirmCollecteScreen({super.key, required this.donId});

  @override
  State<ConfirmCollecteScreen> createState() =>
      _ConfirmCollecteScreenState();
}

class _ConfirmCollecteScreenState extends State<ConfirmCollecteScreen> {
  File? _confirmPhoto;
  bool _isLoading = true;
  bool _isConfirming = false;

  // ── بيانات real من Firestore ──
  String _productTitle = '';
  String _quantity = '';
  String _volunteerName = '';
  double _volunteerRating = 0.0;
  String _collecteHour = '';
  String _associationName = '';
  String _volunteerId = '';
  String _donorId = '';
  String _productIcon = '🍽️';

  @override
  void initState() {
    super.initState();
    _loadDonData();
  }

  String _getIcon(String? title) {
    if (title == null) return '🍽️';
    final t = title.toLowerCase();
    if (t.contains('pain') || t.contains('boulangerie')) return '🍞';
    if (t.contains('repas') || t.contains('plat')) return '🍲';
    if (t.contains('légume') || t.contains('fruit')) return '🥦';
    if (t.contains('pâtisserie') || t.contains('gâteau')) return '🍰';
    if (t.contains('conserve')) return '🥫';
    return '🍽️';
  }

  String _formatHour(dynamic timestamp) {
    if (timestamp == null) return '—';
    try {
      final dt = (timestamp as dynamic).toDate() as DateTime;
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Collecté à ${h}h$m';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _loadDonData() async {
    try {
      final donDoc = await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donId)
          .get();

      if (!donDoc.exists || !mounted) return;
      final d = donDoc.data()!;

      final String volunteerId = d['volunteerId'] as String? ?? '';
      double rating = 0.0;
      String volunteerName = d['volunteerName'] as String? ?? '';

      if (volunteerId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(volunteerId)
              .get();
          if (userDoc.exists) {
            final ud = userDoc.data()!;
            volunteerName = ud['name'] as String? ?? volunteerName;
            rating = (ud['rating'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _productTitle = d['title'] as String? ?? 'Don';
        _quantity = d['quantity']?.toString() ?? '—';
        _volunteerName = volunteerName.isEmpty ? 'Bénévole' : volunteerName;
        _volunteerRating = rating;
        _collecteHour = _formatHour(d['pickupConfirmedAt'] ?? d['updatedAt']);
        _associationName = d['associationName'] as String? ?? '—';
        _volunteerId = volunteerId;
        _donorId = d['donorId'] as String? ?? '';
        _productIcon = _getIcon(d['title'] as String?);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur loadDonData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickConfirmPhoto() async {
    final file = await showImagePickerSheet(
      context,
      title: 'Photo de confirmation',
    );
    if (file != null) setState(() => _confirmPhoto = file);
  }

  Future<void> _confirmerCollecte() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);

    try {
      await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donId)
          .update({
        'status': 'livre',
        'confirmedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // نقاط للبنيفول +10
      if (_volunteerId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_volunteerId)
            .update({
          'points': FieldValue.increment(10),
          'completedMissions': FieldValue.increment(1),
        });

        await FirebaseFirestore.instance
            .collection('users').doc(_volunteerId)
            .collection('notifications').add({
          'title': '🏆 +10 points gagnés !',
          'body': 'Merci ! "$_productTitle" a été confirmé par l\'association.',
          'type': 'points',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // إشعار للمتبرع
      if (_donorId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users').doc(_donorId)
            .collection('notifications').add({
          'title': '✅ Votre don est arrivé !',
          'body': '"$_productTitle" a été remis à $_associationName avec succès.',
          'type': 'livraison',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Collecte confirmée avec succès !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushNamed(context, '/evaluate');
      }
    } catch (e) {
      debugPrint('❌ Erreur confirmation: $e');
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: ZADColors.primary))
          : Column(
              children: [
                // ── Header ──
                Container(
                  color: ZADColors.headerBg,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                                color: ZADColors.primaryLight,
                                borderRadius: BorderRadius.circular(14)),
                            child: Center(
                                child: Text(_productIcon,
                                    style:
                                        const TextStyle(fontSize: 26))),
                          ),
                          const SizedBox(height: 10),
                          const Text('Confirmer la collecte',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          Text(
                            '$_productTitle · $_volunteerName',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // ── Résumé ──
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ZADColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('RÉSUMÉ DU DON',
                                    style: TextStyle(
                                        color: ZADColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 1)),
                              ),
                              const SizedBox(height: 16),
                              _SummaryRow(
                                  label: 'Produit',
                                  value: _productTitle),
                              _SummaryRow(
                                  label: 'Quantité', value: _quantity),
                              _SummaryRow(
                                  label: 'Bénévole',
                                  value: _volunteerRating > 0
                                      ? '$_volunteerName · ⭐${_volunteerRating.toStringAsFixed(1)}'
                                      : _volunteerName),
                              _SummaryRow(
                                  label: 'Heure', value: _collecteHour),
                              _SummaryRow(
                                label: 'Destination',
                                value: _associationName,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Photo de confirmation ──
                        if (_confirmPhoto != null) ...[
                          ImagePreviewBox(
                            imageFile: _confirmPhoto!,
                            onRemove: () =>
                                setState(() => _confirmPhoto = null),
                            onReplace: _pickConfirmPhoto,
                          ),
                        ] else ...[
                          GestureDetector(
                            onTap: _pickConfirmPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: ZADColors.primarySoft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: ZADColors.primaryLight
                                      .withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.camera_alt_outlined,
                                        color: ZADColors.primary,
                                        size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Photo de confirmation (optionnel)',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: ZADColors.textDark,
                                                fontSize: 14)),
                                        Text(
                                            'Prenez le bénévole avec le don',
                                            style: TextStyle(
                                                color: ZADColors.textLight,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: ZADColors.primary,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Text('Ajouter',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ── Points badge ──
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ZADColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    ZADColors.accent.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Text('🏆',
                                  style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    '$_volunteerName gagnera +10 pts et pourra évaluer votre don.\nVous pourrez aussi l\'évaluer !',
                                    style: const TextStyle(
                                        color: ZADColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ZADButton(
                          label: 'Confirmer la collecte',
                          icon: Icons.check_circle_outline,
                          onTap: () {
                            if (!_isConfirming) _confirmerCollecte();
                          },
                        ),
                        const SizedBox(height: 12),
                        ZADButton(
                          label: 'Signaler un problème',
                          icon: Icons.warning_amber_rounded,
                          onTap: () {},
                          color: ZADColors.danger,
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 1),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _SummaryRow(
      {required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: ZADColors.textMedium,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: ZADColors.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: ZADColors.divider),
      ],
    );
  }
}