import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'home_screen.dart';
import '../notification_service.dart';
import '../shared/zad_colors.dart';

class EvaluateVolunteerScreen extends StatefulWidget {
  final String volunteerName;
  final String volunteerInitials;
  final double currentRating;
  final String? volunteerId;
  final String? missionTitle;
  final String? donationId;

  const EvaluateVolunteerScreen({
    super.key,
    required this.volunteerName,
    required this.volunteerInitials,
    required this.currentRating,
    this.volunteerId,
    this.missionTitle,
    this.donationId,
  });

  @override
  State<EvaluateVolunteerScreen> createState() =>
      _EvaluateVolunteerScreenState();
}

class _EvaluateVolunteerScreenState extends State<EvaluateVolunteerScreen> {
  int _globalRating = 5;
  int _ponctuality = 5;
  int _soin = 5;
  int _comportement = 5;

  void _updateGlobalRating() {
    final avg = (_ponctuality + _soin + _comportement) / 3;
    setState(() {
      _globalRating = avg.round().clamp(1, 5);
    });
  }

  final TextEditingController _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 5: return 'Excellent';
      case 4: return 'Très bien';
      case 3: return 'Bien';
      case 2: return 'Moyen';
      default: return 'Faible';
    }
  }

  @override
  Widget build(BuildContext context) {
    final missionTitle =
        widget.missionTitle ?? "Collecte · Pain 30 unités · Aujourd'hui";

    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: ZADColors.headerBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: ZADColors.primaryLight,
                          borderRadius: BorderRadius.circular(16)),
                      child: Center(
                          child: Text(widget.volunteerInitials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20))),
                    ),
                    const SizedBox(height: 10),
                    Text('Évaluer ${widget.volunteerName}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text(missionTitle,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Note globale du bénévole',
                      style: TextStyle(
                          color: ZADColors.textMedium,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _StarRating(rating: _globalRating, size: 36, onChanged: null),
                  const SizedBox(height: 6),
                  Text(
                    '${_getRatingText(_globalRating)} — $_globalRating/5 ⭐',
                    style: const TextStyle(
                        color: ZADColors.textMedium,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Critères :',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: ZADColors.textDark))),
                  const SizedBox(height: 12),
                  _CriteriaRow(
                      icon: Icons.access_time,
                      label: 'Ponctualité',
                      rating: _ponctuality,
                      onChanged: (v) => setState(() {
                            _ponctuality = v;
                            _updateGlobalRating();
                          })),
                  const SizedBox(height: 10),
                  _CriteriaRow(
                      icon: Icons.volunteer_activism,
                      label: 'Soin du don',
                      rating: _soin,
                      onChanged: (v) => setState(() {
                            _soin = v;
                            _updateGlobalRating();
                          })),
                  const SizedBox(height: 10),
                  _CriteriaRow(
                      icon: Icons.sentiment_satisfied_alt,
                      label: 'Comportement',
                      rating: _comportement,
                      onChanged: (v) => setState(() {
                            _comportement = v;
                            _updateGlobalRating();
                          })),
                  const SizedBox(height: 20),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Commentaire :',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: ZADColors.textDark))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Très ponctuel et professionnel...',
                        hintStyle:
                            TextStyle(color: ZADColors.textLight, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: ZADColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'Votre évaluation aide ${widget.volunteerName.split(' ').first} à gagner des badges !',
                                style: const TextStyle(
                                    color: ZADColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ZADButton(
                      label: _isSaving
                          ? "Envoi en cours..."
                          : "Soumettre l'évaluation",
                      icon: Icons.star,
                      onTap: _isSaving ? () {} : _submitEvaluation,
                      color: ZADColors.primary),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    child: const Center(
                        child: Text('Ignorer',
                            style: TextStyle(
                                color: ZADColors.textLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w500))),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 0),
    );
  }

  Future<void> _submitEvaluation() async {
    if (widget.volunteerId == null || widget.volunteerId!.isEmpty) {
      _showError("ID du bénévole manquant");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("Vous devez être connecté");
        return;
      }

      // جلب اسم المتبرع
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final donorName = userDoc.data()?['name'] ??
          userDoc.data()?['donorName'] ??
          'Donateur';

      final moyenne = (_globalRating + _ponctuality + _soin + _comportement) / 4;

      // ✅ 1. حفظ التقييم في ratings collection
      await FirebaseFirestore.instance.collection('ratings').add({
        'fromUserId': user.uid,
        'fromUserRole': 'donor',
        'fromUserName': donorName,
        'toUserId': widget.volunteerId,
        'toUserRole': 'benevole',
        'toUserName': widget.volunteerName,
        'donationId': widget.donationId,
        'missionTitle': widget.missionTitle,
        'noteGlobale': _globalRating,
        'notePonctualite': _ponctuality,
        'noteSoin': _soin,
        'noteComportement': _comportement,
        'moyenne': moyenne,
        'commentaire': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ 2. تحديث متوسط التقييم في ملف البنيفول
      await _updateVolunteerRating(widget.volunteerId!, moyenne);

      // ✅ 3. إرسال إشعار للبنيفول في المسار الصحيح
      await NotificationService.sendNotificationToUser(
        userId: widget.volunteerId!,
        title: '⭐ Nouvelle évaluation reçue !',
        body: '$donorName vous a évalué avec $_globalRating/5 étoiles',
        type: 'new_rating',
        extraData: {
          'rating': _globalRating,
          'moyenne': moyenne.toStringAsFixed(1),
          'fromUserName': donorName,
          'donationId': widget.donationId ?? '',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Évaluation envoyée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur evaluation: $e');
      _showError("Erreur lors de l'envoi: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ تحديث متوسط تقييم البنيفول في Firestore
  Future<void> _updateVolunteerRating(String volunteerId, double newRating) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(volunteerId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) return;

        final data = snap.data()!;
        final oldRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

        final newCount = ratingCount + 1;
        final updatedRating = ((oldRating * ratingCount) + newRating) / newCount;

        tx.update(userRef, {
          'rating': double.parse(updatedRating.toStringAsFixed(2)),
          'ratingCount': newCount,
        });
      });
    } catch (e) {
      debugPrint('⚠️ Erreur mise à jour rating: $e');
      // لا نوقف العملية إذا فشل التحديث
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// ─── Star Rating Widget ────────────────────────────────────────
class _StarRating extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  const _StarRating({required this.rating, this.size = 24, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(i + 1) : null,
          child: Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < rating ? ZADColors.accentYellow : ZADColors.divider,
            size: size,
          ),
        );
      }),
    );
  }
}

// ─── Criteria Row Widget ──────────────────────────────────────
class _CriteriaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int rating;
  final ValueChanged<int> onChanged;

  const _CriteriaRow({
    required this.icon,
    required this.label,
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: ZADColors.primaryLight, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ZADColors.textDark,
                      fontSize: 14)),
            ],
          ),
          _StarRating(rating: rating, size: 20, onChanged: onChanged),
        ],
      ),
    );
  }
}