import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import '../notification_service.dart';

class ZadColors {
  static const Color darkNavy = Color(0xFF1A2B4A);
  static const Color teal = Color(0xFF2E7D7D);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg = Color(0xFFF5F7FA);
  static const Color textDark = Color(0xFF1A2B4A);
}

class EvaluerBenevoleScreen extends StatefulWidget {
  final String? benevoleId;
  final String? benevoleName;
  final String? missionTitle;
  final String? donationId;

  const EvaluerBenevoleScreen({
    super.key,
    this.benevoleId,
    this.benevoleName,
    this.missionTitle,
    this.donationId,
  });

  @override
  State<EvaluerBenevoleScreen> createState() => _EvaluerBenevoleScreenState();
}

class _EvaluerBenevoleScreenState extends State<EvaluerBenevoleScreen> {
  int _notePonctualite = 5;
  int _noteSoin = 4;
  int _noteComportement = 4;
  final _commentaireController = TextEditingController();
  bool _isSaving = false;

  // حساب _noteGlobale تلقائياً من المعايير
  int get _noteGlobale => ((_notePonctualite + _noteSoin + _noteComportement) / 3).round();

  @override
  void dispose() {
    _commentaireController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final moyenne = (_notePonctualite + _noteSoin + _noteComportement) / 3;
    
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("Vous devez être connecté");
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final associationName = userDoc.data()?['associationName'] ?? 
                             userDoc.data()?['name'] ?? 
                             'Association';

      await FirebaseFirestore.instance.collection('ratings').add({
        'fromUserId': user.uid,
        'fromUserRole': 'association',
        'fromUserName': associationName,
        'toUserId': widget.benevoleId,
        'toUserRole': 'benevole',
        'toUserName': widget.benevoleName ?? 'Bénévole',
        'donationId': widget.donationId,
        'missionTitle': widget.missionTitle,
        'notePonctualite': _notePonctualite,
        'noteSoin': _noteSoin,
        'noteComportement': _noteComportement,
        'moyenne': moyenne,
        'commentaire': _commentaireController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (widget.benevoleId != null && widget.benevoleId!.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: widget.benevoleId!,
          title: '⭐ Nouvelle évaluation !',
          body: '$associationName vous a évalué avec ${moyenne.toStringAsFixed(1)}/5 étoiles',
          type: 'evaluation',
          extraData: {
            'moyenne': moyenne.toStringAsFixed(1),
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Évaluation envoyée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      print('❌ Erreur: $e');
      _showError("Erreur lors de l'envoi de l'évaluation");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final benevoleName = widget.benevoleName ?? 'ASSIA H.';
    final missionTitle = widget.missionTitle ?? 'Pain 30 unités';

    return Scaffold(
      backgroundColor: ZadColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(benevoleName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Évaluer $benevoleName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mission complétée · $missionTitle',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Quelle note donnez-vous à ce bénévole ?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ZadColors.darkNavy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return Icon(
                        i < _noteGlobale ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFB800),
                        size: 36,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _noteLabel(_noteGlobale),
                    style: const TextStyle(
                      fontSize: 13,
                      color: ZadColors.labelGrey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Critères d'évaluation :",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ZadColors.darkNavy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CritereRow(
                    label: 'Ponctualité',
                    note: _notePonctualite,
                    onChanged: (v) => setState(() => _notePonctualite = v),
                  ),
                  const SizedBox(height: 10),
                  _CritereRow(
                    label: 'Soin du don',
                    note: _noteSoin,
                    onChanged: (v) => setState(() => _noteSoin = v),
                  ),
                  const SizedBox(height: 10),
                  _CritereRow(
                    label: 'Comportement',
                    note: _noteComportement,
                    onChanged: (v) => setState(() => _noteComportement = v),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Commentaire (optionnel) :',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ZadColors.darkNavy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFCCD6E0),
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: _commentaireController,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ZadColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Partagez votre expérience...',
                        hintStyle: TextStyle(
                          color: ZadColors.labelGrey.withOpacity(0.8),
                          fontSize: 13,
                        ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _onSubmit,
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
                        "Soumettre l'évaluation",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'B';
  }

  String _noteLabel(int note) {
    switch (note) {
      case 1:
        return 'Très mauvais — 1/5';
      case 2:
        return 'Mauvais — 2/5';
      case 3:
        return 'Moyen — 3/5';
      case 4:
        return 'Très bien — 4/5';
      case 5:
        return 'Excellent — 5/5';
      default:
        return '';
    }
  }
}

class _CritereRow extends StatelessWidget {
  final String label;
  final int note;
  final ValueChanged<int> onChanged;

  const _CritereRow({
    required this.label,
    required this.note,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ZadColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ZadColors.darkNavy,
              ),
            ),
          ),
          Row(
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => onChanged(i + 1),
                child: Icon(
                  i < note ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFB800),
                  size: 22,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}