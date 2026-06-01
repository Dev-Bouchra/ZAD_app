// ============================================================
// 📄 lib/screens/benevole/evaluate_donor_screen.dart
// ✅ معدل بالكامل: نظام نقاط +10 للأول و +5 للثاني
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../notification_service.dart';

class EvaluateDonorScreen extends StatefulWidget {
  final String donorName;
  final String missionTitle;
  final String quantity;
  final String? donorId;
  final String? donationId;

  const EvaluateDonorScreen({
    super.key,
    required this.donorName,
    required this.missionTitle,
    required this.quantity,
    this.donorId,
    this.donationId,
  });

  @override
  State<EvaluateDonorScreen> createState() => _EvaluateDonorScreenState();
}

class _EvaluateDonorScreenState extends State<EvaluateDonorScreen> {
  static const _blue = Color(0xFF1565C0);
  static const _blueBg = Color(0xFFE3F2FD);
  static const _textDark = Color(0xFF1B1B1B);
  static const _subText = Color(0xFF757575);

  double _rating = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  bool _isSaving = false;

  final List<String> _tags = [
    '🍽️ Don bien préparé',
    '⏰ Prêt à l\'heure',
    '😊 Accueil agréable',
    '📦 Emballage soigné',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_blue, Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Évaluer le donateur',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 38),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.store, color: _blue, size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.donorName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.missionTitle,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.quantity,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Note globale',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(5, (index) {
                            return GestureDetector(
                              onTap: () => setState(
                                () => _rating = (index + 1).toDouble(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  index < _rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: const Color(0xFFFFB800),
                                  size: 38,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        if (_rating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _blueBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getRatingText(_rating),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Points positifs',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _tags.map((tag) {
                            final isSelected = _selectedTags.contains(tag);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedTags.remove(tag);
                                  } else {
                                    _selectedTags.add(tag);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _blue
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected ? Colors.white : _subText,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Commentaire',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _commentController,
                          maxLines: 3,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Partagez votre expérience...',
                            hintStyle: TextStyle(color: _subText),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  FutureBuilder<bool>(
                    future: _hasRatedAssociation(),
                    builder: (context, snapshot) {
                      final hasRatedAssociation = snapshot.data ?? false;
                      final pointsToEarn = hasRatedAssociation ? 5 : 10;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.shade50, Colors.amber.shade100],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  hasRatedAssociation ? Icons.star_half : Icons.stars,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '+$pointsToEarn points',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFF8F00),
                                    ),
                                  ),
                                  Text(
                                    hasRatedAssociation 
                                        ? 'Dernière évaluation ! +5 points'
                                        : 'Évaluez aussi l\'association pour +10 points',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: _subText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _subText,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Ignorer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _rating > 0 && !_isSaving ? _submitEvaluation : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Envoyer l\'évaluation',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 4.8) return 'Exceptionnel ! 🌟';
    if (rating >= 4.5) return 'Excellent ! 🎉';
    if (rating >= 4.0) return 'Très bien ! 👍';
    if (rating >= 3.5) return 'Bien ✨';
    if (rating >= 3.0) return 'Satisfaisant 😊';
    if (rating >= 2.0) return 'Moyen 😐';
    return 'À améliorer 💪';
  }

  Future<bool> _hasRatedAssociation() async {
    if (widget.donationId == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donationId)
          .get();
      return doc.data()?['hasEvaluatedAssociation'] == true;
    } catch (e) {
      return false;
    }
  }

  void _submitEvaluation() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("Vous devez être connecté");
        return;
      }

      final db = FirebaseFirestore.instance;
      final donationRef = db.collection('dons').doc(widget.donationId);
      final donationDoc = await donationRef.get();
      final donationData = donationDoc.data();

      if (donationData?['hasEvaluatedDonor'] == true) {
        _showError("Vous avez déjà évalué ce donateur");
        setState(() => _isSaving = false);
        return;
      }

      final hasRatedAssociation = donationData?['hasEvaluatedAssociation'] == true;

      final userDoc = await db.collection('users').doc(user.uid).get();
      final benevoleName = userDoc.data()?['name'] ?? 'Bénévole';

      await db.collection('ratings').add({
        'fromUserId': user.uid,
        'fromUserRole': 'benevole',
        'fromUserName': benevoleName,
        'toUserId': widget.donorId ?? '',
        'toUserRole': 'donor',
        'toUserName': widget.donorName,
        'donationId': widget.donationId ?? '',
        'missionTitle': widget.missionTitle,
        'noteGlobale': _rating,
        'selectedTags': _selectedTags.toList(),
        'commentaire': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (widget.donorId != null && widget.donorId!.isNotEmpty) {
        final donorDoc = await db.collection('users').doc(widget.donorId).get();
        if (donorDoc.exists) {
          final data = donorDoc.data()!;
          final currentRating = (data['rating'] ?? 0.0).toDouble();
          final currentCount = (data['ratingCount'] ?? 0).toInt();
          final newCount = currentCount + 1;
          final newRating = ((currentRating * currentCount) + _rating) / newCount;

          await db.collection('users').doc(widget.donorId).update({
            'rating': newRating,
            'ratingCount': newCount,
          });
        }

        await NotificationService.sendNotificationToUser(
          userId: widget.donorId!,
          title: '⭐ Nouvelle évaluation !',
          body: '$benevoleName vous a évalué avec ${_rating.toInt()}/5 étoiles',
          type: 'new_rating',
          extraData: {
            'rating': _rating,
            'fromName': benevoleName,
            'tags': _selectedTags.toList(),
          },
        );
      }

      // ✅ النظام الجديد: +10 للأول، +5 للثاني
      final pointsToAdd = hasRatedAssociation ? 5 : 10;
      await db.collection('users').doc(user.uid).update({
        'points': FieldValue.increment(pointsToAdd),
      });

      await donationRef.update({
        'hasEvaluatedDonor': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('+$pointsToAdd points ! 🎉'),
              ],
            ),
            backgroundColor: _blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Erreur evaluation donor: $e');
      _showError("Erreur lors de l'envoi");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}