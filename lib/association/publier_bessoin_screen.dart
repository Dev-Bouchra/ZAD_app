// lib/association/publier_bessoin_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mes_besoins.dart';

class ZadColors {
  static const Color darkNavy    = Color(0xFF1A2B4A);
  static const Color teal        = Color(0xFF2E7D7D);
  static const Color leafGreen   = Color(0xFF2E7D32);
  static const Color background  = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFCCD6E0);
  static const Color labelGrey   = Color(0xFF6B7A8D);
  static const Color cardBg      = Color(0xFFF5F7FA);
  static const Color textDark    = Color(0xFF1A2B4A);
}

class PublierBesoinScreen extends StatefulWidget {
  const PublierBesoinScreen({super.key});

  @override
  State<PublierBesoinScreen> createState() => _PublierBesoinScreenState();
}

class _PublierBesoinScreenState extends State<PublierBesoinScreen> {
  final _typeController     = TextEditingController();
  final _quantiteController = TextEditingController();
  final _notesController    = TextEditingController();

  String    _urgence   = 'Moyen';
  DateTime? _dateLimite;
  bool      _isLoading = false;

  @override
  void dispose() {
    _typeController.dispose();
    _quantiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onPublier() async {
    if (_typeController.text.trim().isEmpty) {
      _showSnack('Veuillez entrer le type de besoin', isError: true);
      return;
    }
    if (_quantiteController.text.trim().isEmpty) {
      _showSnack('Veuillez entrer la quantité estimée', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Non connecté');

      final assocDoc = await FirebaseFirestore.instance
          .collection('associations')
          .doc(user.uid)
          .get();

      String nomAssociation = 'Association';
      if (assocDoc.exists) {
        nomAssociation = assocDoc.data()?['nom'] ??
            assocDoc.data()?['name'] ??
            'Association';
      }

      await FirebaseFirestore.instance.collection('besoins').add({
        'associationId'  : user.uid,
        'associationNom' : nomAssociation,
        'typeBesoin'     : _typeController.text.trim(),
        'quantiteEstimee': _quantiteController.text.trim(),
        'niveauUrgence'  : _urgence,
        'dateLimite'     : _dateLimite != null
            ? Timestamp.fromDate(_dateLimite!)
            : null,
        'notes'    : _notesController.text.trim(),
        'createdAt': Timestamp.now(),
        'statut'   : 'actif',
      });

      if (mounted) {
        _showSnack('Besoin publié avec succès !');
        await Future.delayed(const Duration(milliseconds: 600));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MesBesoinsScreen()),
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : ZadColors.leafGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: ZadColors.leafGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateLimite = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZadColors.background,
      body: Column(
        children: [
          // ── Header simple sans overflow ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Publier un besoin',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // ── Formulaire ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Type de besoin'),
                  const SizedBox(height: 8),
                  _ZadTextField(
                      controller: _typeController,
                      hint: 'Ex : Pain, Repas...'),
                  const SizedBox(height: 16),

                  _FieldLabel('Quantité estimée'),
                  const SizedBox(height: 8),
                  _ZadTextField(
                    controller: _quantiteController,
                    hint: 'Quantité estimée...',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  _FieldLabel("Niveau d'urgence"),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Faible', 'Moyen', 'Haute'].map((u) {
                      final active = _urgence == u;
                      final color = u == 'Faible'
                          ? ZadColors.leafGreen
                          : u == 'Moyen'
                              ? const Color(0xFFFF9800)
                              : const Color(0xFFE53935);
                      return GestureDetector(
                        onTap: () => setState(() => _urgence = u),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? color : ZadColors.cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: active
                                ? null
                                : Border.all(color: ZadColors.inputBorder),
                          ),
                          child: Text(u,
                              style: TextStyle(
                                  color: active ? Colors.white : color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  _FieldLabel('Date limite'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: ZadColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: ZadColors.inputBorder, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: ZadColors.labelGrey, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _dateLimite != null
                                ? '${_dateLimite!.day}/${_dateLimite!.month}/${_dateLimite!.year}'
                                : 'Sélectionner une date',
                            style: TextStyle(
                              color: _dateLimite != null
                                  ? ZadColors.textDark
                                  : ZadColors.labelGrey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _FieldLabel('Notes supplémentaires'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: ZadColors.inputBorder, width: 1.2),
                    ),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 14, color: ZadColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Informations supplémentaires...',
                        hintStyle: TextStyle(
                            color: ZadColors.labelGrey.withOpacity(0.8),
                            fontSize: 13),
                        filled: true,
                        fillColor: ZadColors.background,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Bouton Publier ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onPublier,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZadColors.leafGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Publier le besoin',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ZadColors.darkNavy));
}

class _ZadTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _ZadTextField(
      {required this.controller, required this.hint, this.keyboardType});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: ZadColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: ZadColors.labelGrey.withOpacity(0.8), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: ZadColors.inputBorder, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: ZadColors.teal, width: 1.5),
            ),
          ),
        ),
      );
}