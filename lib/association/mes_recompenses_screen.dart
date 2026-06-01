// 📄 lib/association/mes_recompenses_screen.dart
// شاشة عرض مكافآت الجمعية (الكوبونات التي حصلت عليها)

import 'package:flutter/material.dart';
import 'home_screen.dart';

class ZadColors {
  static const Color darkNavy = Color(0xFF1A2B4A);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg = Color(0xFFF5F7FA);
  static const Color primary = Color(0xFF2E7D32);
  static const Color primarySoft = Color(0xFFE8F5E9);
  static const Color success = Color(0xFF4CAF50);
  static const Color textDark = Color(0xFF1B1B1B);
  static const Color textMedium = Color(0xFF616161);
  static const Color textLight = Color(0xFF8A8A8A);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color headerBg = Color(0xFF1B5E20);
}

class MesRecompensesScreen extends StatefulWidget {
  const MesRecompensesScreen({super.key});

  @override
  State<MesRecompensesScreen> createState() => _MesRecompensesScreenState();
}

class _MesRecompensesScreenState extends State<MesRecompensesScreen> {
  List<Map<String, dynamic>> _mesCoupons = [
    {
      'id': '1',
      'title': '20% de réduction',
      'partenaire': 'Boulangerie Atlas',
      'code': 'ZAD-1-2026',
      'expiry': '30/05/2026',
      'icon': '🥐',
      'used': false,
    },
    {
      'id': '2',
      'title': 'Boisson gratuite',
      'partenaire': 'Café Bab El Qarmadine',
      'code': 'ZAD-5-2026',
      'expiry': 'Indéfiniment',
      'icon': '☕',
      'used': false,
    },
  ];
  
  void _useCoupon(int index) {
    setState(() {
      _mesCoupons[index]['used'] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coupon marqué comme utilisé'),
        backgroundColor: ZadColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _showQRCode(Map<String, dynamic> coupon) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: ZadColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(coupon['icon'], style: const TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                coupon['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ZadColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                coupon['partenaire'],
                style: const TextStyle(
                  fontSize: 14,
                  color: ZadColors.textMedium,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZadColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code, size: 100, color: ZadColors.primary),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        coupon['code'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ZadColors.primary,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.event_available, size: 16, color: ZadColors.textLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Valable jusqu\'au ${coupon['expiry']}',
                      style: const TextStyle(fontSize: 12, color: ZadColors.textLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZadColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
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
              color: ZadColors.headerBg,
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
                const Expanded(
                  child: Text(
                    'Mes récompenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 26),
              ],
            ),
          ),
          
          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _RecompenseStatCard(
                  value: _mesCoupons.length.toString(),
                  label: 'Total coupons',
                  icon: Icons.card_giftcard,
                ),
                const SizedBox(width: 12),
                _RecompenseStatCard(
                  value: _mesCoupons.where((c) => !c['used']).length.toString(),
                  label: 'Disponibles',
                  icon: Icons.check_circle,
                ),
              ],
            ),
          ),
          
          // Coupons list
          Expanded(
            child: _mesCoupons.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.card_giftcard, size: 64, color: ZadColors.labelGrey),
                        SizedBox(height: 16),
                        Text('Aucune récompense',
                            style: TextStyle(color: ZadColors.labelGrey, fontSize: 14)),
                        SizedBox(height: 8),
                        Text('Les offres que vous obtenez apparaîtront ici',
                            style: TextStyle(color: ZadColors.labelGrey, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _mesCoupons.length,
                    itemBuilder: (context, index) {
                      final coupon = _mesCoupons[index];
                      return _CouponCard(
                        coupon: coupon,
                        onUse: () => _useCoupon(index),
                        onShowQR: () => _showQRCode(coupon),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecompenseStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  
  const _RecompenseStatCard({required this.value, required this.label, required this.icon});
  
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: ZadColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ZadColors.textDark,
                )),
            Text(label,
                style: const TextStyle(
                  color: ZadColors.textLight,
                  fontSize: 11,
                )),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;
  final VoidCallback onUse;
  final VoidCallback onShowQR;
  
  const _CouponCard({
    required this.coupon,
    required this.onUse,
    required this.onShowQR,
  });
  
  @override
  Widget build(BuildContext context) {
    final isUsed = coupon['used'] as bool;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUsed ? ZadColors.background : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUsed ? ZadColors.divider : ZadColors.primary,
          width: isUsed ? 1 : 1.5,
        ),
        boxShadow: isUsed ? null : [
          BoxShadow(
            color: ZadColors.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: ZadColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(coupon['icon'], style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isUsed ? ZadColors.textLight : ZadColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  coupon['partenaire'],
                  style: TextStyle(
                    color: isUsed ? ZadColors.textLight : ZadColors.textMedium,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event_available, size: 12, color: ZadColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      coupon['expiry'],
                      style: const TextStyle(color: ZadColors.textLight, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isUsed)
            Column(
              children: [
                GestureDetector(
                  onTap: onShowQR,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ZadColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onUse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ZadColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ZadColors.success),
                    ),
                    child: const Text(
                      'Utilisé',
                      style: TextStyle(
                        color: ZadColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ZadColors.divider,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Utilisé',
                style: TextStyle(
                  color: ZadColors.textLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}