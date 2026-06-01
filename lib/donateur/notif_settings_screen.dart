import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'home_screen.dart';
import '../shared/zad_colors.dart';

class NotifSettingsScreen extends StatefulWidget {
  const NotifSettingsScreen({super.key});

  @override
  State<NotifSettingsScreen> createState() => _NotifSettingsScreenState();
}

class _NotifSettingsScreenState extends State<NotifSettingsScreen> {
  // إعدادات الإشعارات
  bool _notifDons = true;
  bool _notifBenevoles = true;
  bool _notifExpired = true;
  bool _notifRating = true;
  bool _notifMessages = true;
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _soundEnabled = true;
  
  bool _isLoading = true;

  // مفاتيح التخزين
  static const String KEY_NOTIF_DONS = 'notif_dons';
  static const String KEY_NOTIF_BENEVOLES = 'notif_benevoles';
  static const String KEY_NOTIF_EXPIRED = 'notif_expired';
  static const String KEY_NOTIF_RATING = 'notif_rating';
  static const String KEY_NOTIF_MESSAGES = 'notif_messages';
  static const String KEY_PUSH_ENABLED = 'push_enabled';
  static const String KEY_EMAIL_ENABLED = 'email_enabled';
  static const String KEY_SOUND_ENABLED = 'sound_enabled';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// تحميل الإعدادات المحفوظة
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _notifDons = prefs.getBool(KEY_NOTIF_DONS) ?? true;
        _notifBenevoles = prefs.getBool(KEY_NOTIF_BENEVOLES) ?? true;
        _notifExpired = prefs.getBool(KEY_NOTIF_EXPIRED) ?? true;
        _notifRating = prefs.getBool(KEY_NOTIF_RATING) ?? true;
        _notifMessages = prefs.getBool(KEY_NOTIF_MESSAGES) ?? true;
        _pushEnabled = prefs.getBool(KEY_PUSH_ENABLED) ?? true;
        _emailEnabled = prefs.getBool(KEY_EMAIL_ENABLED) ?? false;
        _soundEnabled = prefs.getBool(KEY_SOUND_ENABLED) ?? true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Erreur chargement settings: $e");
      setState(() => _isLoading = false);
    }
  }

  /// حفظ جميع الإعدادات
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(KEY_NOTIF_DONS, _notifDons);
      await prefs.setBool(KEY_NOTIF_BENEVOLES, _notifBenevoles);
      await prefs.setBool(KEY_NOTIF_EXPIRED, _notifExpired);
      await prefs.setBool(KEY_NOTIF_RATING, _notifRating);
      await prefs.setBool(KEY_NOTIF_MESSAGES, _notifMessages);
      await prefs.setBool(KEY_PUSH_ENABLED, _pushEnabled);
      await prefs.setBool(KEY_EMAIL_ENABLED, _emailEnabled);
      await prefs.setBool(KEY_SOUND_ENABLED, _soundEnabled);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Préférences enregistrées avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Erreur sauvegarde settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur lors de l\'enregistrement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// تغيير إعداد معين مع حفظ تلقائي (اختياري)
  void _updateSetting(bool value, Function setter) {
    setState(() {
      setter(value);
    });
    _saveSettings(); // حفظ فوري عند التغيير
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: ZADColors.headerBg,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomeScreen(),
                              ),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 18),
                          ),
                          const Expanded(
                            child: Text('Paramètres notifications',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: const Text('Canaux de réception',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: ZADColors.textDark)),
                        ),
                        Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              _NotifToggle(
                                icon: Icons.notifications_outlined,
                                label: 'Notifications push',
                                subtitle: 'Alertes sur votre appareil',
                                value: _pushEnabled,
                                onChanged: (v) => _updateSetting(v, (val) => _pushEnabled = val),
                              ),
                              _NotifDivider(),
                              _NotifToggle(
                                icon: Icons.email_outlined,
                                label: 'Notifications par email',
                                subtitle: 'Résumé quotidien par email',
                                value: _emailEnabled,
                                onChanged: (v) => _updateSetting(v, (val) => _emailEnabled = val),
                              ),
                              _NotifDivider(),
                              _NotifToggle(
                                icon: Icons.volume_up_outlined,
                                label: 'Son des notifications',
                                subtitle: "Activer le son d'alerte",
                                value: _soundEnabled,
                                onChanged: (v) => _updateSetting(v, (val) => _soundEnabled = val),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: const Text('Types de notifications',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: ZADColors.textDark)),
                        ),
                        Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              _NotifToggle(
                                icon: Icons.volunteer_activism_outlined,
                                label: 'Activité des dons',
                                subtitle: 'Publication, livraison, confirmation',
                                value: _notifDons,
                                onChanged: (v) => _updateSetting(v, (val) => _notifDons = val),
                              ),
                              _NotifDivider(),
                              _NotifToggle(
                                icon: Icons.person_outlined,
                                label: 'Bénévoles',
                                subtitle: 'Acceptation, arrivée, départ',
                                value: _notifBenevoles,
                                onChanged: (v) => _updateSetting(v, (val) => _notifBenevoles = val),
                              ),
                              _NotifDivider(),
                              _NotifToggle(
                                icon: Icons.warning_amber_outlined,
                                label: 'Dons expirés',
                                subtitle: 'Alerte quand un don expire sans collecte',
                                value: _notifExpired,
                                onChanged: (v) => _updateSetting(v, (val) => _notifExpired = val),
                              ),
                              _NotifDivider(),
                              _NotifToggle(
                                icon: Icons.star_outline,
                                label: 'Évaluations reçues',
                                subtitle: 'Quand un bénévole vous évalue',
                                value: _notifRating,
                                onChanged: (v) => _updateSetting(v, (val) => _notifRating = val),
                              ),
                              _NotifDivider(),
                              _NotifToggle(
                                icon: Icons.chat_bubble_outline,
                                label: 'Messages',
                                subtitle: 'Nouveaux messages reçus',
                                value: _notifMessages,
                                onChanged: (v) => _updateSetting(v, (val) => _notifMessages = val),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: ZADButton(
                            label: 'Enregistrer les préférences',
                            icon: Icons.check,
                            onTap: () async {
                              await _saveSettings();
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 4),
    );
  }
}

class _NotifToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value ? ZADColors.primarySoft : ZADColors.divider.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: value ? ZADColors.primary : ZADColors.textLight,
                size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: ZADColors.textDark)),
                Text(subtitle,
                    style: const TextStyle(
                        color: ZADColors.textLight,
                        fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: ZADColors.primary,
          ),
        ],
      ),
    );
  }
}

class _NotifDivider extends StatelessWidget {
  const _NotifDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 68,
      color: ZADColors.divider,
    );
  }
}