// ============================================================
// 📄 lib/screens/benevole/notification_settings_screen.dart
// ============================================================

import 'package:flutter/material.dart';

class BenevoleNotificationSettingsScreen extends StatefulWidget {
  const BenevoleNotificationSettingsScreen({super.key});

  @override
  State<BenevoleNotificationSettingsScreen> createState() =>
      _BenevoleNotificationSettingsScreenState();
}

class _BenevoleNotificationSettingsScreenState
    extends State<BenevoleNotificationSettingsScreen> {
  static const _green     = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _orange    = Color(0xFFFF8F00);
  static const _blue      = Color(0xFF1565C0);
  static const _blueBg    = Color(0xFFE3F2FD);
  static const _divider   = Color(0xFFEEEEEE);
  static const _subText   = Color(0xFF757575);
  static const _textDark  = Color(0xFF1B1B1B);

  // ── Toggle States ────────────────────────────────────────
  bool _notifDons        = true;
  bool _notifUrgent      = true;
  bool _notifMissions    = true;
  bool _notifBadges      = true;
  bool _notifMessages    = true;
  bool _notifEvaluations = false;
  bool _notifSound       = true;
  bool _notifVibration   = true;
  bool _notifEmail       = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  _buildSection(
                    title: '🍽️ Dons',
                    items: [
                      _toggleItem(
                        'Nouveaux dons à proximité',
                        'Recevoir les alertes de dons disponibles',
                        _notifDons,
                        _greenPale, _green,
                        (v) => setState(() => _notifDons = v),
                      ),
                      _toggleItem(
                        '⚡ Dons urgents',
                        'Alertes prioritaires pour les dons urgents',
                        _notifUrgent,
                        const Color(0xFFFFEBEE),
                        const Color(0xFFD32F2F),
                        (v) => setState(() => _notifUrgent = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    title: '📋 Missions',
                    items: [
                      _toggleItem(
                        'Mises à jour de missions',
                        'Statut, confirmations, rappels',
                        _notifMissions,
                        _greenPale, _green,
                        (v) => setState(() => _notifMissions = v),
                      ),
                      _toggleItem(
                        'Évaluations reçues',
                        'Quand un donateur vous évalue',
                        _notifEvaluations,
                        const Color(0xFFFFF3E0),
                        _orange,
                        (v) => setState(() => _notifEvaluations = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    title: '🏅 Badges & Récompenses',
                    items: [
                      _toggleItem(
                        'Nouveaux badges débloqués',
                        'Niveaux, récompenses, points',
                        _notifBadges,
                        const Color(0xFFFFFDE7),
                        const Color(0xFFF9A825),
                        (v) => setState(() => _notifBadges = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    title: '💬 Messages',
                    items: [
                      _toggleItem(
                        'Nouveaux messages',
                        'Messages des associations et donateurs',
                        _notifMessages,
                        _blueBg, _blue,
                        (v) => setState(() => _notifMessages = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    title: '🔊 Son & Vibration',
                    items: [
                      _toggleItem(
                        'Son des notifications',
                        'Activer le son lors des alertes',
                        _notifSound,
                        _greenPale, _green,
                        (v) => setState(() => _notifSound = v),
                      ),
                      _toggleItem(
                        'Vibration',
                        'Vibrer lors des notifications',
                        _notifVibration,
                        _greenPale, _green,
                        (v) => setState(() => _notifVibration = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    title: '📧 Email',
                    items: [
                      _toggleItem(
                        'Notifications par email',
                        'Recevoir un résumé hebdomadaire',
                        _notifEmail,
                        _blueBg, _blue,
                        (v) => setState(() => _notifEmail = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('✅ Paramètres sauvegardés !'),
                            backgroundColor: _green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 6,
                        shadowColor: _green.withOpacity(0.4),
                      ),
                      child: const Text('💾 Sauvegarder',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x554CAF50),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 18, left: 18, right: 18,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Paramètres notifications',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                )),
          ),
          const Divider(height: 1, color: _divider),
          ...items,
        ],
      ),
    );
  }

  Widget _toggleItem(
    String title,
    String subtitle,
    bool value,
    Color iconBg,
    Color iconColor,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              value
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: value ? iconColor : _subText,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _textDark,
                    )),
                Text(subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: _subText,
                    )),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _green,
          ),
        ],
      ),
    );
  }
}