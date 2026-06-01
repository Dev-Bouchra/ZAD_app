import 'package:flutter/material.dart';
import 'ccp_details_screen.dart';

class MoneyDonationScreen extends StatefulWidget {
  const MoneyDonationScreen({super.key});

  @override
  State<MoneyDonationScreen> createState() => _MoneyDonationScreenState();
}

class _MoneyDonationScreenState extends State<MoneyDonationScreen>
    with TickerProviderStateMixin {

  // ── Animations ────────────────────────────────────────────
  late AnimationController _pageCtrl;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  late AnimationController _cardCtrl;

  int?   _selectedAmount;
  int    _selectedMethod = 0; // 0=CCP 1=BaridiMob 2=CIB
  final  TextEditingController _customCtrl = TextEditingController();
  final  List<int> _amounts = [200, 500, 1000, 2000, 5000];

  int get _finalAmount {
    if (_selectedAmount != null) return _selectedAmount!;
    return int.tryParse(_customCtrl.text) ?? 0;
  }

  @override
  void initState() {
    super.initState();

    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pageFade  = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut));

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _cardCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _selectMethod(int index) {
    if (index == _selectedMethod) return;
    _cardCtrl.forward(from: 0);
    setState(() => _selectedMethod = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('Don en argent',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildAmountSection(),
                const SizedBox(height: 24),
                _buildPaymentMethodSection(),
                const SizedBox(height: 20),
                if (_finalAmount > 0) _buildSummaryCard(),
                const SizedBox(height: 28),
                _buildContinueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: const Column(
        children: [
          Text('🌿', style: TextStyle(fontSize: 44)),
          SizedBox(height: 10),
          Text('Votre don sauve de la nourriture',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('100% de votre don va directement aux associations',
              style: TextStyle(color: Color(0xFFB9F6CA), fontSize: 13)),
        ],
      ),
    );
  }

  // ── Montants ──────────────────────────────────────────────
  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choisir le montant (DZD)',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_amounts.length, (i) {
            final amount   = _amounts[i];
            final selected = _selectedAmount == amount;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + i * 80),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                    offset: Offset(0, 20 * (1 - v)), child: child),
              ),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedAmount = amount;
                  _customCtrl.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2E7D32)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: const Color(0xFF2E7D32), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: selected
                              ? const Color(0xFF2E7D32).withOpacity(0.3)
                              : Colors.black.withOpacity(0.06),
                          blurRadius: selected ? 10 : 6,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Text('$amount DZD',
                      style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        const Text('Ou entrez un autre montant',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: _customCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _selectedAmount = null),
          decoration: InputDecoration(
            hintText: 'Ex: 3000',
            suffixText: 'DZD',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFF2E7D32), width: 1.8)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Méthode de paiement ───────────────────────────────────
  Widget _buildPaymentMethodSection() {
    final methods = [
      _PayMethod(
          icon: Icons.mail_outline,
          label: 'CCP / Poste',
          subtitle: 'Virement postal',
          available: true),
      _PayMethod(
          icon: Icons.phone_android,
          label: 'BaridiMob',
          subtitle: 'Paiement mobile',
          available: true),
      _PayMethod(
          icon: Icons.credit_card,
          label: 'Carte CIB',
          subtitle: 'Bientôt disponible',
          available: false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mode de paiement',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...List.generate(methods.length, (i) {
          final m        = methods[i];
          final selected = _selectedMethod == i;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 100),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                  offset: Offset(30 * (1 - v), 0), child: child),
            ),
            child: GestureDetector(
              onTap: m.available ? () => _selectMethod(i) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE8F5E9)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: selected
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade200,
                      width: selected ? 2 : 1),
                  boxShadow: [
                    BoxShadow(
                        color: selected
                            ? const Color(0xFF2E7D32).withOpacity(0.15)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: selected ? 12 : 6,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2E7D32)
                            : m.available
                                ? const Color(0xFFE8F5E9)
                                : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(m.icon,
                          color: selected
                              ? Colors.white
                              : m.available
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey,
                          size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: m.available
                                      ? Colors.black87
                                      : Colors.grey)),
                          Text(m.subtitle,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: m.available
                                      ? Colors.grey
                                      : Colors.grey.shade400)),
                        ],
                      ),
                    ),
                    if (!m.available)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.orange.shade200),
                        ),
                        child: Text('Bientôt',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600)),
                      )
                    else if (selected)
                      const Icon(Icons.check_circle,
                          color: Color(0xFF2E7D32), size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Résumé ────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        children: [
          _summaryRow('Montant total', '$_finalAmount DZD',
              bold: true),
          const Divider(height: 16),
          _summaryRow('Reversé à l\'association',
              '$_finalAmount DZD',
              color: const Color(0xFF2E7D32), bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black87)),
      ],
    );
  }

  // ── Bouton continuer ──────────────────────────────────────
  Widget _buildContinueButton() {
    final enabled = _finalAmount >= 100 && _selectedMethod != 2;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: enabled ? 1.0 : 0.5,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: enabled
              ? () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, a, __) =>
                          CcpDetailsScreen(
                              amount: _finalAmount,
                              method: _selectedMethod),
                      transitionsBuilder: (_, a, __, child) =>
                          SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: a, curve: Curves.easeOut)),
                        child: child,
                      ),
                    ),
                  )
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: enabled ? 4 : 0,
            shadowColor:
                const Color(0xFF2E7D32).withOpacity(0.4),
          ),
          child: Text(
            _selectedMethod == 2
                ? 'CIB — Bientôt disponible'
                : _finalAmount >= 100
                    ? 'Continuer — $_finalAmount DZD'
                    : 'Minimum 100 DZD',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _PayMethod {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final bool     available;
  const _PayMethod(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.available});
}