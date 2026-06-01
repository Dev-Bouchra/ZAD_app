// lib/association/ajouter_beneficiaire_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ZadColors {
  static const Color darkNavy = Color(0xFF1A2B4A);
  static const Color teal = Color(0xFF2E7D7D);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFCCD6E0);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg = Color(0xFFF5F7FA);
  static const Color textDark = Color(0xFF1A2B4A);
}

class AjouterBeneficiaireScreen extends StatefulWidget {
  const AjouterBeneficiaireScreen({super.key});

  @override
  State<AjouterBeneficiaireScreen> createState() =>
      _AjouterBeneficiaireScreenState();
}

class _AjouterBeneficiaireScreenState extends State<AjouterBeneficiaireScreen> {
  final _nomController = TextEditingController();
  final _adresseController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _personnesController = TextEditingController();
  final _besoinAutreController = TextEditingController();
  final List<String> _besoinOptions = [
    'Repas chaud',
    'Pain',
    'Fruits & Légumes',
    'Produits laitiers',
    'Épicerie sèche',
    'Autre',
  ];
  final List<String> _selectedBesoins = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _telephoneController.dispose();
    _personnesController.dispose();
    _besoinAutreController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_nomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le nom complet')),
      );
      return;
    }

    if (_adresseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer l\'adresse / quartier')),
      );
      return;
    }

    if (_telephoneController.text.trim().isNotEmpty) {
      final phoneRegex = RegExp(r'^0[5-7][0-9]{8}$');
      if (!phoneRegex.hasMatch(_telephoneController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Numéro invalide. Format: 05XXXXXXXX / 06XXXXXXXX / 07XXXXXXXX',
            ),
          ),
        );
        return;
      }
    }

    if (_personnesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le nombre de personnes')),
      );
      return;
    }

    if (_selectedBesoins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un besoin alimentaire'),
        ),
      );
      return;
    }

    if (_selectedBesoins.contains('Autre') &&
        _besoinAutreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez préciser le besoin dans "Autre"'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté')),
        );
        return;
      }

      final besoins = _selectedBesoins.contains('Autre')
          ? _selectedBesoins.map((b) => b == 'Autre' ? _besoinAutreController.text.trim() : b).toList()
          : _selectedBesoins;

      await FirebaseFirestore.instance.collection('beneficiaires').add({
        'associationId': user.uid,
        'nom': _nomController.text.trim(),
        'adresse': _adresseController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'personnes': int.tryParse(_personnesController.text.trim()) ?? 0,
        'besoins': besoins,
        'statut': 'Actif',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Bénéficiaire ajouté avec succès')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZadColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Ajouter bénéficiaire',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: ZadColors.darkNavy,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Informations personnelles',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ZadColors.darkNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ZadTextField(
                    controller: _nomController,
                    hint: 'Nom complet',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _ZadTextField(
                    controller: _adresseController,
                    hint: 'Adresse / Quartier',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 12),
                  _ZadPhoneField(controller: _telephoneController),
                  const SizedBox(height: 12),
                  _ZadTextField(
                    controller: _personnesController,
                    hint: 'Nombre de personnes',
                    icon: Icons.people_outline,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        color: ZadColors.darkNavy,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Besoins alimentaires',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ZadColors.darkNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _besoinOptions.map((option) {
                      final isSelected = _selectedBesoins.contains(option);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedBesoins.remove(option);
                              if (option == 'Autre')
                                _besoinAutreController.clear();
                            } else {
                              _selectedBesoins.add(option);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ZadColors.leafGreen.withValues(alpha: 0.1)
                                : ZadColors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? ZadColors.leafGreen
                                  : ZadColors.inputBorder,
                              width: isSelected ? 1.5 : 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                option,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? ZadColors.leafGreen
                                      : ZadColors.darkNavy,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: ZadColors.leafGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedBesoins.contains('Autre')) ...[
                    const SizedBox(height: 12),
                    _ZadTextField(
                      controller: _besoinAutreController,
                      hint: 'Précisez le besoin...',
                      icon: Icons.edit_outlined,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZadColors.leafGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enregistrer le bénéficiaire',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZadTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;

  const _ZadTextField({
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: ZadColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: ZadColors.labelGrey.withValues(alpha: 0.8),
            fontSize: 14,
          ),
          prefixIcon: icon != null
              ? Icon(icon, color: ZadColors.labelGrey, size: 18)
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: ZadColors.inputBorder,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZadColors.teal, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ZadPhoneField extends StatelessWidget {
  final TextEditingController controller;
  const _ZadPhoneField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 14, color: ZadColors.textDark),
        decoration: InputDecoration(
          hintText: 'Téléphone (optionnel)',
          hintStyle: TextStyle(
            color: ZadColors.labelGrey.withValues(alpha: 0.8),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.phone_outlined,
            color: ZadColors.labelGrey,
            size: 18,
          ),
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: ZadColors.inputBorder,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZadColors.teal, width: 1.5),
          ),
        ),
      ),
    );
  }
}