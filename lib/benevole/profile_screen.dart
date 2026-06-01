// ============================================================
// 📄 lib/screens/benevole/profile_screen.dart
// ✅ الإحصائيات (مهمات، كغ، تقييم، نقاط) حقيقية من Firestore
// ============================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../auth/auth_service.dart';
import 'edit_profile_screen.dart';
import 'missions_screen.dart';
import 'badges_screen.dart';
import 'notification_settings_screen.dart';
import '../../auth/login_screen.dart';
import 'dashboard_screen.dart';
import 'package:a/cloudinary_service.dart';

class BenevoleProfileScreen extends StatefulWidget {
  const BenevoleProfileScreen({super.key});

  @override
  State<BenevoleProfileScreen> createState() => _BenevoleProfileScreenState();
}

class _BenevoleProfileScreenState extends State<BenevoleProfileScreen> {
  static const _green = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _orange = Color(0xFFFF8F00);
  static const _orangeBg = Color(0xFFFFF3E0);
  static const _blue = Color(0xFF1565C0);
  static const _blueBg = Color(0xFFE3F2FD);
  static const _red = Color(0xFFD32F2F);
  static const _redBg = Color(0xFFFFEBEE);
  static const _purple = Color(0xFF7B1FA2);
  static const _purpleBg = Color(0xFFF3E5F5);
  static const _divider = Color(0xFFEEEEEE);
  static const _subText = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);

  File? _profileImage;
  final _picker = ImagePicker();

  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String _userInitials = '';
  String _userTransport = 'Voiture';
  String _userQuartier = '';
  String _userBio = '';
  String _userPhotoUrl = '';

  // ✅ إحصائيات حقيقية من Firestore
  int _missionsCompleted = 0;
  int _kgSaved = 0;
  double _rating = 0.0;
  int _userPoints = 0;
  int _unlockedRecompenses = 0;

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. جلب بيانات المستخدم
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _userName = data['name'] ?? 'Bénévole';
          _userEmail = data['email'] ?? '';
          _userPhone = data['phone'] ?? '';
          _userTransport = data['transport'] ?? 'Voiture';
          _userQuartier = data['quartier'] ?? 'Tlemcen Centre';
          _userBio = data['bio'] ?? 'Bénévole chez ZAD';
          _userPhotoUrl = data['photoUrl'] ?? '';
          _userInitials = _getInitials(_userName);
          // ✅ الإحصائيات الحقيقية
          _missionsCompleted = (data['missionsCompleted'] ?? 0).toInt();
          _kgSaved = (data['kgSaved'] ?? 0).toInt();
          _rating = (data['rating'] ?? 0.0).toDouble();
          _userPoints = (data['points'] ?? 0).toInt();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }

      // 2. عد المكافآت المتاحة للمستخدم
      _loadUnlockedRecompenses(user.uid);
    } catch (e) {
      print("❌ Profile Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // ✅ حساب عدد المكافآت التي نقاط المستخدم تسمح بها
  Future<void> _loadUnlockedRecompenses(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('recompenses')
          .where('isActive', isEqualTo: true)
          .get();

      int count = 0;
      for (final doc in snap.docs) {
        final required = (doc.data()['requiredPoints'] ?? 0).toInt();
        if (_userPoints >= required) count++;
      }

      if (mounted) setState(() => _unlockedRecompenses = count);
    } catch (e) {
      print("❌ Erreur recompenses count: $e");
    }
  }

  String _getInitials(String name) {
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
    return 'B';
  }

  String _getTransportIcon(String transport) {
    switch (transport) {
      case 'Voiture': return '🚗';
      case 'Moto': return '🏍️';
      case 'Vélo': return '🚲';
      case 'À pied': return '🚶';
      default: return '🚗';
    }
  }

  // ✅ حساب الشارة بناءً على النقاط الحقيقية
  String get _userBadge {
    if (_userPoints >= 1000) return '⭐ Légende';
    if (_userPoints >= 500) return '🥇 Champion';
    if (_userPoints >= 100) return '🥈 Engagé';
    return '🥉 Débutant';
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ✅ دالة رفع الصورة إلى Cloudinary
  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;
    
    // عرض مؤشر تحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _green),
            const SizedBox(height: 16),
            const Text('Téléchargement de la photo...', 
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
    
    try {
      final photoUrl = await CloudinaryService.uploadAuto(_profileImage!);
      
      if (photoUrl != null) {
        // حفظ الرابط في Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'photoUrl': photoUrl});
          setState(() {
            _userPhotoUrl = photoUrl;
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Photo mise à jour'), backgroundColor: _green),
          );
          _loadUserData(); // إعادة تحميل البيانات
        }
      } else {
        throw Exception('Échec du téléchargement');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) Navigator.pop(context);
      setState(() => _profileImage = null);
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Changer la photo',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt, color: _green),
              ),
              title: const Text('Caméra', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () async {
                Navigator.pop(ctx);
                final p = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                if (p != null) {
                  setState(() => _profileImage = File(p.path));
                  await _uploadProfileImage();
                }
              },
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library, color: _green),
              ),
              title: const Text('Galerie', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () async {
                Navigator.pop(ctx);
                final p = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (p != null) {
                  setState(() => _profileImage = File(p.path));
                  await _uploadProfileImage();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(content,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _subText, height: 1.6)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK', style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Se déconnecter ?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('Vous serez déconnecté de votre compte ZAD.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _subText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(fontFamily: 'Poppins', color: _subText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Se déconnecter',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProfileHero(),
                _buildStats(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      children: [
                        _buildInfoSection(),
                        const SizedBox(height: 12),
                        _buildMenuSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), _greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x554CAF50), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 24,
        left: 18,
        right: 18,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const BenevoleDashboardScreen()),
                ),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
                  ),
                  child: ClipOval(
                    child: _profileImage != null
                        ? Image.file(_profileImage!, fit: BoxFit.cover)
                        : (_userPhotoUrl.isNotEmpty
                            ? Image.network(_userPhotoUrl, fit: BoxFit.cover)
                            : Container(
                                color: Colors.white.withOpacity(0.25),
                                child: Center(
                                  child: Text(_userInitials.isEmpty ? "B" : _userInitials,
                                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                              )),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
                    ),
                    child: const Icon(Icons.camera_alt, color: _green, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_userName.isEmpty ? "Bénévole" : _userName,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Text(
              '🤝 Bénévole · ${_getTransportIcon(_userTransport)} $_userTransport',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text('📍 $_userQuartier',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  // ✅ إحصائيات حقيقية من Firestore
  Widget _buildStats() {
    final ratingStr = _rating > 0 ? '⭐${_rating.toStringAsFixed(1)}' : '⭐-';
    final kgStr = _kgSaved >= 1000
        ? '${(_kgSaved / 1000).toStringAsFixed(1)}t'
        : '${_kgSaved}kg';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _green.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _statItem('$_missionsCompleted', 'Missions', _green),
          _dividerV(),
          _statItem(kgStr, 'Sauvés', _blue),
          _dividerV(),
          _statItem(ratingStr, 'Note', _orange),
          _dividerV(),
          _statItem('$_userPoints', 'Points', _greenDark),
        ],
      ),
    );
  }

  Widget _statItem(String val, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(val,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 9, color: _subText)),
          ],
        ),
      ),
    );
  }

  Widget _dividerV() => Container(width: 1, height: 40, color: _divider);

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: _green, size: 18),
              SizedBox(width: 8),
              Text('Informations',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.email_outlined, 'Email', _userEmail),
          const SizedBox(height: 8),
          _infoRow(Icons.phone_outlined, 'Téléphone', _userPhone),
          const SizedBox(height: 8),
          _infoRow(Icons.location_on_outlined, 'Quartier', _userQuartier),
          const SizedBox(height: 8),
          _infoRow(Icons.directions_car_outlined, 'Transport', _userTransport),
          const SizedBox(height: 8),
          _infoRow(Icons.description_outlined, 'Bio', _userBio),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _subText),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _subText)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Non défini' : value,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: _textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    // ✅ عدد المكافآت المتاحة حقيقي
    final recompensesSubtitle = _unlockedRecompenses > 0
        ? '$_unlockedRecompenses récompense${_unlockedRecompenses > 1 ? 's' : ''} disponible${_unlockedRecompenses > 1 ? 's' : ''}'
        : 'Continuez pour débloquer des récompenses';

    // ✅ عدد المهمات حقيقي
    final missionsSubtitle = '$_missionsCompleted mission${_missionsCompleted > 1 ? 's' : ''} réalisée${_missionsCompleted > 1 ? 's' : ''}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          _menuItem(
            icon: Icons.edit_outlined,
            iconBg: _greenPale,
            iconColor: _green,
            title: 'Modifier le profil',
            subtitle: 'Nom, photo, transport...',
            onTap: () => _navigate(const BenevoleEditProfileScreen()),
          ),
          const Divider(height: 1, indent: 60, endIndent: 16),
          _menuItem(
            icon: Icons.assignment_outlined,
            iconBg: _greenPale,
            iconColor: _green,
            title: 'Historique des missions',
            subtitle: missionsSubtitle,
            onTap: () => _navigate(const BenevoleMissionsScreen()),
          ),
          const Divider(height: 1, indent: 60, endIndent: 16),
          _menuItem(
            icon: Icons.emoji_events_outlined,
            iconBg: const Color(0xFFFFFDE7),
            iconColor: const Color(0xFFF9A825),
            title: 'Mes badges & récompenses',
            subtitle: recompensesSubtitle,
            onTap: () => _navigate(const BenevoleBadgesScreen()),
          ),
          const Divider(height: 1, indent: 60, endIndent: 16),
          _menuItem(
            icon: Icons.notifications_outlined,
            iconBg: _orangeBg,
            iconColor: _orange,
            title: 'Paramètres notifications',
            subtitle: 'Gérer vos alertes',
            onTap: () => _navigate(const BenevoleNotificationSettingsScreen()),
          ),
          const Divider(height: 1, indent: 60, endIndent: 16),
          _menuItem(
            icon: Icons.help_outline,
            iconBg: _blueBg,
            iconColor: _blue,
            title: 'Aide et support',
            subtitle: 'FAQ · Contactez-nous',
            onTap: () => _showInfoDialog(
              '❓ Aide & Support',
              'Pour toute question :\n📧 support@zad-tlemcen.dz\n📞 +213 41 XX XX XX',
            ),
          ),
          const Divider(height: 1, indent: 60, endIndent: 16),
          _menuItem(
            icon: Icons.security_outlined,
            iconBg: _purpleBg,
            iconColor: _purple,
            title: 'Confidentialité',
            subtitle: 'Gérer vos données',
            onTap: () => _showInfoDialog(
              '🔒 Confidentialité',
              'Vos données sont protégées et ne sont jamais partagées avec des tiers.\n\nPolitique de confidentialité ZAD v1.0',
            ),
          ),
          const Divider(height: 1),
          _menuItem(
            icon: Icons.logout,
            iconBg: _redBg,
            iconColor: _red,
            title: 'Se déconnecter',
            subtitle: '',
            isLogout: true,
            onTap: () => _showLogoutDialog(),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isLogout ? _red : _textDark,
                      )),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _subText)),
                  ],
                ],
              ),
            ),
            if (!isLogout)
              const Icon(Icons.arrow_forward_ios, color: _subText, size: 14),
          ],
        ),
      ),
    );
  }
}