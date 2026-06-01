// 📄 lib/donateur/ajouter_offre_screen.dart
// ✅ مع إضافة حقل "Points requis pour débloquer" + إدخال يدوي لأي رقم (بدون خيار Gratuit)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'mes_offres_screen.dart';
import 'offre_manager.dart';
import '../shared/zad_colors.dart';

class AjouterOffreScreen extends StatefulWidget {
  const AjouterOffreScreen({super.key});

  @override
  State<AjouterOffreScreen> createState() => _AjouterOffreScreenState();
}

class _AjouterOffreScreenState extends State<AjouterOffreScreen> {
  final _titleController       = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valeurController      = TextEditingController();
  final _autreOffreController  = TextEditingController();
  final _requiredPointsController = TextEditingController();

  String    _selectedType   = 'reduction';
  String    _selectedIcon   = '🍕';
  String    _donorType      = '';
  DateTime? _expiryDate;
  int       _quantity       = 50;
  bool      _isIllimite     = false;
  bool      _showAutreField = false;
  bool      _isLoading      = false;

  // ✅ النقاط المطلوبة لفتح العرض (القيمة الافتراضية 10 بدلاً من 0)
  int _requiredPoints = 10;
  
  // ✅ خيارات سريعة للنقاط (بدون 0 - بدون Gratuit)
  final List<int> _pointsPresets = [10, 20, 30, 50, 100, 200, 500];

  final List<Map<String, String>> _typeOptions = [
    {'value': 'reduction', 'label': '💰 Pourcentage',    'icon': '🏷️'},
    {'value': 'gratuit',   'label': '🎁 Produit gratuit', 'icon': '🎁'},
  ];

  List<Map<String, String>> get _iconOptions {
    switch (_donorType) {
      case 'Restaurant':
        return [
          {'value': '🍕', 'label': 'Fast-food'},
          {'value': '🍲', 'label': 'Repas'},
          {'value': '🥤', 'label': 'Boissons'},
        ];
      case 'Boulangerie':
        return [
          {'value': '🍞', 'label': 'Pain'},
        ];
      case 'Commerce de produits alimentaires':
        return [
          {'value': '🥤', 'label': 'Boisson'},
          {'value': '🍞', 'label': 'Pain'},
          {'value': '🥫', 'label': 'Conserve'},
          {'value': '🍪', 'label': 'Biscuit'},
          {'value': '🧃', 'label': 'Jus'},
          {'value': '🎁', 'label': 'Autre'},
        ];
      default:
        return [
          {'value': '🍕', 'label': 'Fast-food'},
          {'value': '🍲', 'label': 'Repas'},
          {'value': '🥤', 'label': 'Boissons'},
          {'value': '🍞', 'label': 'Pain'},
        ];
    }
  }

  Future<void> _loadDonorType() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _donorType = data['donorType'] ?? '';
          if (_iconOptions.isNotEmpty) {
            _selectedIcon = _iconOptions.first['value']!;
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement type: $e");
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: ZADColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  void _updateRequiredPoints(String value) {
    int? parsed = int.tryParse(value);
    if (parsed != null && parsed >= 1) {
      setState(() {
        _requiredPoints = parsed;
      });
    } else if (value.isEmpty) {
      setState(() {
        _requiredPoints = 10;
        _requiredPointsController.text = '10';
      });
    }
  }

  Future<void> _publierOffre() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Veuillez entrer un titre');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Veuillez entrer une description');
      return;
    }
    if (_selectedType == 'reduction' && _valeurController.text.trim().isEmpty) {
      _showError('Veuillez entrer la valeur du pourcentage');
      return;
    }
    if (_selectedIcon == '🎁' && _autreOffreController.text.trim().isEmpty) {
      _showError('Veuillez préciser le type d\'offre');
      return;
    }
    if (_requiredPoints < 1) {
      _showError('Veuillez entrer un nombre de points valide (minimum 1)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalIcon = _selectedIcon;
      if (_selectedIcon == '🎁' && _autreOffreController.text.isNotEmpty) {
        finalIcon = _autreOffreController.text;
      }

      String valeurAffichee = '';
      if (_selectedType == 'reduction' && _valeurController.text.isNotEmpty) {
        valeurAffichee = '${_valeurController.text}%';
      } else {
        valeurAffichee = 'Gratuit';
      }

      await OffreManager.instance.ajouterOffre({
        'title':          _titleController.text.trim(),
        'description':    _descriptionController.text.trim(),
        'type':           _selectedType,
        'valeur':         valeurAffichee,
        'expiry': _expiryDate != null
            ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
            : 'Indéfiniment',
        'restants':       _isIllimite ? -1 : _quantity,
        'icon':           finalIcon,
        'partenaire':     'Boulangerie Atlas',
        'code':           'ZAD-${DateTime.now().millisecondsSinceEpoch}',
        'requiredPoints': _requiredPoints,
      });

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('✅ Offre créée avec succès !'),
          backgroundColor: ZADColors.success,
          duration:        Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MesOffresScreen()),
      );
    } catch (e) {
      debugPrint("❌ Erreur lors de la création: $e");
      setState(() => _isLoading = false);
      _showError('Erreur lors de la création: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(message),
        backgroundColor: ZADColors.danger,
        duration:        const Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDonorType();
    _requiredPointsController.text = '10';
    _requiredPointsController.addListener(() {
      _updateRequiredPoints(_requiredPointsController.text);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _valeurController.dispose();
    _autreOffreController.dispose();
    _requiredPointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header ──
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
                        const Expanded(
                          child: Text('Nouvelle offre',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   20,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 26),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── 1. Icône ──
                      _SectionTitle(icon: Icons.emoji_emotions, label: '1. Icône de l\'offre'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:       _iconOptions.length,
                          itemBuilder: (context, index) {
                            final icon       = _iconOptions[index];
                            final isSelected = _selectedIcon == icon['value'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIcon    = icon['value']!;
                                  _showAutreField  = (icon['value'] == '🎁');
                                  if (icon['value'] != '🎁') {
                                    _autreOffreController.clear();
                                  }
                                });
                              },
                              child: Container(
                                width:  70,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ZADColors.primarySoft
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? ZADColors.primary
                                        : ZADColors.divider,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(icon['value']!,
                                        style: const TextStyle(fontSize: 28)),
                                    const SizedBox(height: 4),
                                    Text(
                                      icon['label']!,
                                      style: TextStyle(
                                        fontSize:   10,
                                        color:      isSelected
                                            ? ZADColors.primary
                                            : ZADColors.textLight,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      if (_showAutreField) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color:        Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color:      Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset:     const Offset(0, 3))
                            ],
                          ),
                          child: TextField(
                            controller: _autreOffreController,
                            decoration: const InputDecoration(
                              hintText:       'Précisez le type d\'offre...',
                              border:         InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── 2. Type ──
                      _SectionTitle(icon: Icons.category, label: '2. Type de l\'offre'),
                      const SizedBox(height: 10),
                      Row(
                        children: _typeOptions.map((type) {
                          final isSelected = _selectedType == type['value'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedType = type['value']!),
                              child: Container(
                                margin:  const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ZADColors.primarySoft
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? ZADColors.primary
                                        : ZADColors.divider,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(type['icon']!,
                                        style: const TextStyle(fontSize: 20)),
                                    const SizedBox(height: 4),
                                    Text(
                                      type['label']!,
                                      style: TextStyle(
                                        fontSize:   12,
                                        color:      isSelected
                                            ? ZADColors.primary
                                            : ZADColors.textMedium,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ── 3. Valeur (فقط عند Pourcentage) ──
                      if (_selectedType == 'reduction') ...[
                        _SectionTitle(
                            icon:  Icons.local_offer,
                            label: '3. Valeur de l\'offre'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color:        Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:       Border.all(color: ZADColors.divider),
                          ),
                          child: TextField(
                            controller:   _valeurController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText:       'Ex: 20',
                              border:         InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                              suffixText:     '%',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── 4. Titre ──
                      _SectionTitle(
                        icon:  Icons.title,
                        label: _selectedType == 'reduction'
                            ? '4. Titre de l\'offre'
                            : '3. Titre de l\'offre',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:       Border.all(color: ZADColors.divider),
                        ),
                        child: TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText:       'Ex: 20% de réduction sur le pain',
                            border:         InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── 5. Description ──
                      _SectionTitle(
                        icon:  Icons.description,
                        label: _selectedType == 'reduction'
                            ? '5. Description'
                            : '4. Description',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:       Border.all(color: ZADColors.divider),
                        ),
                        child: TextField(
                          controller: _descriptionController,
                          maxLines:   2,
                          decoration: const InputDecoration(
                            hintText:       'Ex: Sur tout le pain',
                            border:         InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════
                      // ✅ قسم النقاط المطلوبة (بدون خيار Gratuit)
                      // ══════════════════════════════════════════
                      _SectionTitle(
                        icon:  Icons.star,
                        label: _selectedType == 'reduction'
                            ? '6. Points requis pour débloquer'
                            : '5. Points requis pour débloquer',
                      ),
                      const SizedBox(height: 8),

                      // توضيح ديناميكي
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:        const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border:       Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Le bénévole doit avoir au moins $_requiredPoints pts pour débloquer cette offre',
                                style: const TextStyle(
                                  fontSize:   11,
                                  color:      Color(0xFF795548),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // اختيار سريع للنقاط (Chips - بدون Gratuit)
                      SizedBox(
                        height: 42,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:       _pointsPresets.length,
                          itemBuilder: (_, i) {
                            final pts      = _pointsPresets[i];
                            final isActive = _requiredPoints == pts;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _requiredPoints = pts;
                                  _requiredPointsController.text = pts.toString();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin:   const EdgeInsets.only(right: 8),
                                padding:  const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? const LinearGradient(colors: [
                                          Color(0xFF388E3C),
                                          Color(0xFF4CAF50),
                                        ])
                                      : null,
                                  color:        isActive ? null : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive
                                        ? ZADColors.primary
                                        : ZADColors.divider,
                                    width: isActive ? 2 : 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color:      ZADColors.primary
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset:     const Offset(0, 3),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  '$pts pts',
                                  style: TextStyle(
                                    fontSize:   12,
                                    fontWeight: FontWeight.w700,
                                    color:      isActive
                                        ? Colors.white
                                        : ZADColors.textMedium,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ✅ إدخال يدوي لأي عدد نقاط (TextField)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border:       Border.all(color: ZADColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit, 
                                color: ZADColors.primary, size: 18),
                            const SizedBox(width: 12),
                            const Text('Personnaliser',
                                style: TextStyle(
                                  fontSize:   13,
                                  color:      ZADColors.textMedium,
                                  fontWeight: FontWeight.w600,
                                )),
                            const Spacer(),
                            Container(
                              width: 100,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: ZADColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextField(
                                controller: _requiredPointsController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ZADColors.primary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '10',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                  suffixText: 'pts',
                                  suffixStyle: TextStyle(
                                    fontSize: 12,
                                    color: ZADColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ══════════════════════════════════════════

                      const SizedBox(height: 24),

                      // ── Nombre d'utilisations ──
                      _SectionTitle(
                        icon:  Icons.people,
                        label: _selectedType == 'reduction'
                            ? '7. Nombre d\'utilisations'
                            : '6. Nombre d\'utilisations',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _isIllimite = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isIllimite
                                      ? ZADColors.primarySoft
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isIllimite
                                        ? ZADColors.primary
                                        : ZADColors.divider,
                                    width: _isIllimite ? 2 : 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Text('Illimité',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _isIllimite = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isIllimite
                                      ? ZADColors.primarySoft
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !_isIllimite
                                        ? ZADColors.primary
                                        : ZADColors.divider,
                                    width: !_isIllimite ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        if (_quantity > 1)
                                          setState(() => _quantity--);
                                      },
                                      icon: const Icon(Icons.remove, size: 18),
                                      padding:     EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    Text('$_quantity',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    IconButton(
                                      onPressed: () =>
                                          setState(() => _quantity++),
                                      icon:        const Icon(Icons.add, size: 18),
                                      padding:     EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Date d'expiration ──
                      _SectionTitle(
                        icon:  Icons.event,
                        label: _selectedType == 'reduction'
                            ? '8. Date d\'expiration'
                            : '7. Date d\'expiration',
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:        Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:       Border.all(color: ZADColors.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: ZADColors.primary),
                              const SizedBox(width: 12),
                              Text(
                                _expiryDate != null
                                    ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                    : 'Sélectionner une date',
                                style: TextStyle(
                                  color: _expiryDate != null
                                      ? ZADColors.textDark
                                      : ZADColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      ZADButton(
                        label: 'Publier l\'offre',
                        icon:  Icons.send,
                        onTap: _publierOffre,
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: ZADColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String   label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ZADColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize:   15,
            color:      ZADColors.textDark,
          ),
        ),
      ],
    );
  }
}