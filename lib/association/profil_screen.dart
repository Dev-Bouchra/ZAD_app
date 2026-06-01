// lib/association/profil_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'modifier_profil_screen.dart';
import 'history_screen.dart';
import 'documents_screen.dart';
import '../../auth/login_screen.dart';

class ZadColors {
  static const Color darkNavy  = Color(0xFF1A2B4A);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey  = Color(0xFF6B7A8D);
  static const Color cardBg     = Color(0xFFF5F7FA);
}

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  String  _associationName     = 'Association';
  String  _associationInitials = 'A';
  String? _profileImageUrl;
  bool    _isLoading = true;

  int    _totalDons   = 0;
  double _totalKg     = 0;
  double _averageNote = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final donsSnapshot = await FirebaseFirestore.instance
          .collection('dons')
          .where('associationId', isEqualTo: user.uid)
          .where('status',
              whereIn: ['accepte_par_association', 'en_route', 'livre'])
          .get();

      _totalDons = donsSnapshot.docs.length;
      _totalKg   = 0;

      for (var doc in donsSnapshot.docs) {
        final data     = doc.data();
        final quantity = data['quantity'] ?? '';
        if (quantity.contains('kg')) {
          final kg =
              double.tryParse(quantity.replaceAll('kg', '').trim());
          if (kg != null) _totalKg += kg;
        }
      }

      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('toUserId', isEqualTo: user.uid)
          .get();

      if (ratingsSnapshot.docs.isNotEmpty) {
        double sum = 0;
        for (var doc in ratingsSnapshot.docs) {
          sum += (doc.data()['moyenne'] ?? 0).toDouble();
        }
        _averageNote = sum / ratingsSnapshot.docs.length;
      } else {
        _averageNote = 0;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Erreur stats: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data()!;
          final name = data['associationName'] ?? data['name'] ?? 'Association';
          setState(() {
            _associationName     = name;
            _associationInitials = _getInitials(name);
            _profileImageUrl     = data['profileImageUrl'] as String?;
            _isLoading           = false;
          });
        }
      });
    } catch (e) {
      debugPrint("❌ Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Déconnexion"),
        content:
            const Text("Êtes-vous sûr de vouloir vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler",
                style: TextStyle(color: ZadColors.labelGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Déconnecter",
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZadColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Header ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.fromLTRB(20, 52, 20, 28),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B5E20),
                    borderRadius: BorderRadius.only(
                      bottomLeft:  Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildAvatar(),
                      const SizedBox(height: 12),
                      Text(
                        _associationName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(
                              v: '$_totalDons', l: 'Dons reçus'),
                          _Divider(),
                          _Stat(
                              v: '${_totalKg.toStringAsFixed(0)}kg',
                              l: 'Food sauvée'),
                          _Divider(),
                          _Stat(
                              v: _averageNote.toStringAsFixed(1),
                              l: 'Note'),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Menu ────────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    children: [
                      _MenuItem(
                        icon: Icons.edit_outlined,
                        label: 'Modifier le profil',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ModifierProfilScreen()),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.lock_outline,
                        label: 'Changer le mot de passe',
                        onTap: () =>
                            _showChangePasswordSheet(context),
                      ),
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Paramètres de notifications',
                        onTap: () =>
                            _showNotificationSettings(context),
                      ),
                      _MenuItem(
                        icon: Icons.history,
                        label: 'Mon historique complet',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HistoryScreen()),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.folder_outlined,
                        label: 'Mes documents officiels',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const DocumentsScreen()),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.help_outline,
                        label: 'Aide et support',
                        onTap: () => _showSupportSheet(context),
                      ),
                      const SizedBox(height: 12),
                      _LogoutBtn(
                          onTap: () => _handleLogout(context)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Avatar: صورة حقيقية أو initials ──────────────────────────
  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const ModifierProfilScreen()),
      ),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor:
                Colors.white.withValues(alpha: 0.2),
            backgroundImage: _profileImageUrl != null
                ? NetworkImage(_profileImageUrl!) as ImageProvider
                : null,
            child: _profileImageUrl == null
                ? Text(
                    _associationInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt,
                  size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Changer mot de passe ──────────────────────────────────────
  void _showChangePasswordSheet(BuildContext context) {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    bool isChanging  = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 25, right: 25, top: 25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Changer le mot de passe",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ZadColors.leafGreen),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: oldPwdCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Ancien mot de passe",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: newPwdCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Nouveau mot de passe",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isChanging
                      ? null
                      : () async {
                          if (oldPwdCtrl.text.isEmpty ||
                              newPwdCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Veuillez remplir tous les champs')));
                            return;
                          }
                          setSt(() => isChanging = true);
                          try {
                            final user = FirebaseAuth
                                .instance.currentUser;
                            if (user != null &&
                                user.email != null) {
                              final cred =
                                  EmailAuthProvider.credential(
                                email: user.email!,
                                password: oldPwdCtrl.text,
                              );
                              await user
                                  .reauthenticateWithCredential(
                                      cred);
                              await user.updatePassword(
                                  newPwdCtrl.text);
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content: Text(
                                      '✅ Mot de passe mis à jour !'),
                                  backgroundColor:
                                      Color(0xFF1B5E20),
                                ));
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                                    content: Text(
                                        'Mot de passe incorrect')));
                          } finally {
                            setSt(() => isChanging = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: ZadColors.leafGreen),
                  child: isChanging
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text("Mettre à jour",
                          style:
                              TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Paramètres de notifications ───────────────────────────────
  void _showNotificationSettings(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // نفتح الـ bottomSheet مباشرة ونحمّل البيانات داخله
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => _NotificationSettingsSheet(userId: user.uid),
    );
  }

  // ── Aide et support ───────────────────────────────────────────
  void _showSupportSheet(BuildContext context) {
    // نفتح الـ bottomSheet مباشرة ونحمّل البيانات داخله
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => const _SupportSheet(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Widget مستقل للإشعارات — يحمّل البيانات بنفسه
// ════════════════════════════════════════════════════════════════
class _NotificationSettingsSheet extends StatefulWidget {
  final String userId;
  const _NotificationSettingsSheet({required this.userId});

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  bool _newDons  = true;
  bool _messages = true;
  bool _loading  = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('settings')
          .doc('notifications')
          .get();
      if (mounted) {
        setState(() {
          _newDons  = doc.data()?['newDons']  ?? true;
          _messages = doc.data()?['messages'] ?? true;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(String key, bool value) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('settings')
        .doc('notifications')
        .set({key: value}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Paramètres de notifications",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ZadColors.leafGreen),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            )
          else ...[
            SwitchListTile(
              title: const Text("Nouveaux dons"),
              subtitle:
                  const Text("Être notifié lors d'un nouveau don"),
              value: _newDons,
              onChanged: (v) {
                setState(() => _newDons = v);
                _save('newDons', v);
              },
              activeColor: ZadColors.leafGreen,
            ),
            SwitchListTile(
              title: const Text("Messages"),
              subtitle: const Text("Notifications de nouveaux messages"),
              value: _messages,
              onChanged: (v) {
                setState(() => _messages = v);
                _save('messages', v);
              },
              activeColor: ZadColors.leafGreen,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ZadColors.leafGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text("Fermer",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Widget مستقل للدعم — يحمّل البيانات بنفسه
// ════════════════════════════════════════════════════════════════
class _SupportSheet extends StatefulWidget {
  const _SupportSheet();

  @override
  State<_SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<_SupportSheet> {
  String _phone   = '+213 5XX XX XX XX';
  String _email   = 'support@zad.dz';
  bool   _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('support')
          .get();
      if (mounted) {
        setState(() {
          _phone   = doc.data()?['phone'] ?? '+213 5XX XX XX XX';
          _email   = doc.data()?['email'] ?? 'support@zad.dz';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Aide et Support",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ZadColors.leafGreen),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.phone,
                  color: ZadColors.leafGreen),
              title: const Text("Appeler le support"),
              subtitle: Text(_phone),
              onTap: () => _launch(Uri(
                  scheme: 'tel',
                  path: _phone.replaceAll(' ', ''))),
            ),
            ListTile(
              leading: const Icon(Icons.email,
                  color: ZadColors.leafGreen),
              title: const Text("Envoyer un email"),
              subtitle: Text(_email),
              onTap: () =>
                  _launch(Uri(scheme: 'mailto', path: _email)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ZadColors.leafGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text("Fermer",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Widgets مساعدة
// ════════════════════════════════════════════════════════════════
class _Stat extends StatelessWidget {
  final String v, l;
  const _Stat({required this.v, required this.l});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(v,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          Text(l,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11)),
        ],
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.3));
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: ZadColors.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: ZadColors.leafGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        color: ZadColors.darkNavy,
                        fontWeight: FontWeight.w500)),
              ),
              const Icon(Icons.chevron_right,
                  color: ZadColors.labelGrey, size: 20),
            ],
          ),
        ),
      );
}

class _LogoutBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout,
                  color: Color(0xFFE53935), size: 20),
              SizedBox(width: 12),
              Text('Se déconnecter',
                  style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}