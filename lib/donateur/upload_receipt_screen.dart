import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:a/cloudinary_service.dart';

class UploadReceiptScreen extends StatefulWidget {
  final int amount;
  final int method; // 0=CCP  1=BaridiMob
  const UploadReceiptScreen(
      {super.key, required this.amount, required this.method});

  @override
  State<UploadReceiptScreen> createState() => _UploadReceiptScreenState();
}

class _UploadReceiptScreenState extends State<UploadReceiptScreen>
    with TickerProviderStateMixin {

  late AnimationController _pageCtrl;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  File?   _receipt;
  bool    _sending = false;
  String? _errorMessage;
  String  _statusText = 'Envoi en cours...';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pageFade =
        CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut));

    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
        lowerBound: 0.97,
        upperBound: 1.03)
      ..repeat(reverse: true);
    _pulseAnim = _pulseCtrl;

    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked =
        await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _receipt = File(picked.path);
        _errorMessage = null;
      });
    }
  }

  // ─── الدالة الرئيسية — رفع الصورة ثم حفظ Firestore ────────────────────────
  Future<void> _submit() async {
    if (_receipt == null) return;

    setState(() {
      _sending = true;
      _errorMessage = null;
      _statusText = 'Envoi de l\'image...';
    });

    // 1️⃣ رفع الصورة على Cloudinary
    final String? receiptUrl =
        await CloudinaryService.uploadFile(_receipt!);

    if (!mounted) return;

    if (receiptUrl == null) {
      setState(() {
        _sending = false;
        _errorMessage =
            'Échec du téléchargement. Vérifiez votre connexion et réessayez.';
      });
      return;
    }

    setState(() => _statusText = 'Enregistrement de la demande...');

    // 2️⃣ حفظ التبرع في Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final methodLabel = widget.method == 0 ? 'CCP' : 'BaridiMob';

      // جلب اسم المستخدم
      String userName = 'Donateur';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          userName = userDoc.data()?['name'] ?? 'Donateur';
        }
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('financial_donations')
          .add({
        // ── معلومات المتبرع ──────────────────────────
        'donorId'    : user.uid,
        'donorName'  : userName,
        'donorEmail' : user.email ?? '',

        // ── تفاصيل التبرع ────────────────────────────
        'amount'     : widget.amount,
        'method'     : methodLabel,   // 'CCP' أو 'BaridiMob'
        'receiptUrl' : receiptUrl,    // رابط الصورة على Cloudinary

        // ── الحالة (الادمين سيغيّرها لـ 'accepted' أو 'rejected') ──
        'status'     : 'pending',

        // ── التواريخ ──────────────────────────────────
        'createdAt'  : FieldValue.serverTimestamp(),
        'updatedAt'  : FieldValue.serverTimestamp(),

        // ── ملاحظات الادمين (تُملأ لاحقاً) ─────────
        'adminNote'  : '',
      });

      if (!mounted) return;

      // 3️⃣ إرسال إشعار للمستخدم
      await _sendNotification(user.uid, userName);

      setState(() => _sending = false);
      _showSuccessDialog();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorMessage = 'Erreur lors de l\'enregistrement. Réessayez.';
      });
      debugPrint('❌ Firestore error: $e');
    }
  }

  // ── إرسال إشعار للمستخدم ──────────────────────────────────
  Future<void> _sendNotification(String userId, String userName) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId'   : userId,
        'title'    : '✅ Demande de don reçue',
        'body'     :
            'Votre don de ${widget.amount} DZD a bien été reçu. L\'administrateur vérifiera votre reçu sous 24h.',
        'type'     : 'financial_donation',
        'lu'       : false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Notification error (non-bloquant): $e');
      // l'erreur de notification ne bloque pas le flux
    }
  }

  // ── Dialog succès ─────────────────────────────────────────
  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (_, a, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
        child: FadeTransition(opacity: a, child: child),
      ),
      pageBuilder: (_, __, ___) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF2E7D32), size: 56),
            ),
            const SizedBox(height: 18),
            const Text('Demande envoyée !',
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'L\'administrateur vérifiera votre reçu sous 24h.\nVous serez notifié dès confirmation 🌿',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey, height: 1.6, fontSize: 13),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                child: const Text('Retour à l\'accueil',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final methodLabel =
        widget.method == 0 ? 'CCP / Poste' : 'BaridiMob';
    final methodHint = widget.method == 0
        ? 'Photo du reçu de virement postal'
        : 'Capture d\'écran de la confirmation BaridiMob';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('Télécharger le reçu',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Rappel montant + méthode ──────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF2E7D32), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${widget.amount} DZD via $methodLabel',
                          style: const TextStyle(
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Zone upload ───────────────────────────
                Expanded(
                  child: GestureDetector(
                    onTap: _showPickerSheet,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _receipt == null ? _pulseAnim.value : 1.0,
                        child: child,
                      ),
                      child: _receipt != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(_receipt!, fit: BoxFit.cover),
                                  // overlay pour rechange
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.edit,
                                              color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('Changer',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: const Color(0xFF2E7D32)
                                        .withOpacity(0.4),
                                    width: 2,
                                    strokeAlign:
                                        BorderSide.strokeAlignOutside),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF2E7D32)
                                          .withOpacity(0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFE8F5E9),
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.upload_file,
                                        size: 44,
                                        color: Color(0xFF2E7D32)),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'Appuyez pour ajouter le reçu',
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text(methodHint,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),

                // ── رسالة الخطأ ───────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── زر إرسال ─────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        (_receipt != null && !_sending) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: _receipt != null ? 4 : 0,
                      shadowColor: const Color(0xFF2E7D32).withOpacity(0.4),
                    ),
                    child: _sending
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              ),
                              const SizedBox(width: 12),
                              Text(_statusText,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          )
                        : const Text('Envoyer la demande',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt,
                      color: Color(0xFF2E7D32)),
                ),
                title: const Text('Prendre une photo',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library,
                      color: Color(0xFF2E7D32)),
                ),
                title: const Text('Choisir depuis la galerie',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
