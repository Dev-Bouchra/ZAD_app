import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'upload_receipt_screen.dart';

class CcpDetailsScreen extends StatefulWidget {
  final int amount;
  final int method; // 0=CCP  1=BaridiMob
  const CcpDetailsScreen(
      {super.key, required this.amount, required this.method});

  @override
  State<CcpDetailsScreen> createState() => _CcpDetailsScreenState();
}

class _CcpDetailsScreenState extends State<CcpDetailsScreen>
    with TickerProviderStateMixin {

  // ── Animations ────────────────────────────────────────────
  late AnimationController _headerCtrl;
  late Animation<double>   _headerScale;
  late Animation<double>   _headerFade;
  late AnimationController _listCtrl;
  late Animation<double>   _listFade;
  late Animation<Offset>   _listSlide;

  // ── بيانات Firebase ───────────────────────────────────────
  Map<String, dynamic>? _paymentInfo;
  bool _loadingInfo = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    // animations
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerScale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.elasticOut));
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);

    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _listFade = CurvedAnimation(parent: _listCtrl, curve: Curves.easeOut);
    _listSlide = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _listCtrl, curve: Curves.easeOut));

    _headerCtrl.forward();
    _loadPaymentInfo();
  }

  // ── جلب البيانات من Firestore ─────────────────────────────
  // المسار: payment_info/ccp     للـ CCP
  //          payment_info/baridi  للـ BaridiMob
  Future<void> _loadPaymentInfo() async {
    final docId = widget.method == 0 ? 'ccp' : 'baridi';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('payment_info')
          .doc(docId)
          .get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        setState(() {
          _paymentInfo = doc.data();
          _loadingInfo = false;
        });
        Future.delayed(const Duration(milliseconds: 300),
            () { if (mounted) _listCtrl.forward(); });
      } else {
        setState(() {
          _loadError = 'Informations non disponibles pour le moment.';
          _loadingInfo = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Erreur de connexion. Vérifiez votre réseau.';
        _loadingInfo = false;
      });
    }
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Copié dans le presse-papiers'),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCcp = widget.method == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(
            isCcp ? 'Virement CCP / Poste' : 'Paiement BaridiMob',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header animé ──────────────────────────────
            ScaleTransition(
              scale: _headerScale,
              child: FadeTransition(
                opacity: _headerFade,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1B5E20),
                        Color(0xFF2E7D32),
                        Color(0xFF388E3C)
                      ],
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
                  child: Column(
                    children: [
                      Icon(
                        isCcp ? Icons.mail_outline : Icons.phone_android,
                        color: Colors.white,
                        size: 38,
                      ),
                      const SizedBox(height: 10),
                      const Text('Montant à virer',
                          style: TextStyle(
                              color: Color(0xFFB9F6CA), fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('${widget.amount} DZD',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ── محتوى (loading / error / بيانات) ─────────
            if (_loadingInfo)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2E7D32)),
                    SizedBox(height: 14),
                    Text('Chargement des informations...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else if (_loadError != null)
              _buildErrorWidget()
            else
              _buildContent(isCcp),
          ],
        ),
      ),
    );
  }

  // ── Widget erreur ─────────────────────────────────────────
  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(_loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() { _loadingInfo = true; _loadError = null; });
              _loadPaymentInfo();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Réessayer',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── المحتوى الرئيسي بعد تحميل البيانات ───────────────────
  Widget _buildContent(bool isCcp) {
    final info = _paymentInfo!;

    return FadeTransition(
      opacity: _listFade,
      child: SlideTransition(
        position: _listSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                isCcp
                    ? 'Informations du compte CCP'
                    : 'Informations BaridiMob',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (isCcp) ...[
              // حقول CCP: number, key, name, rip
              if (info['number'] != null)
                _infoCard(context, 'Numéro CCP', info['number']),
              if (info['key'] != null) ...[
                const SizedBox(height: 8),
                _infoCard(context, 'Clé', info['key']),
              ],
              if (info['name'] != null) ...[
                const SizedBox(height: 8),
                _infoCard(context, 'Nom', info['name']),
              ],
              if (info['rip'] != null) ...[
                const SizedBox(height: 8),
                _infoCard(context, 'RIP', info['rip']),
              ],
            ] else ...[
              // حقول BaridiMob: number, name
              if (info['number'] != null)
                _infoCard(context, 'Numéro BaridiMob', info['number']),
              if (info['name'] != null) ...[
                const SizedBox(height: 8),
                _infoCard(context, 'Nom', info['name']),
              ],
            ],

            const SizedBox(height: 20),

            // ── خطوات ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDE7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFEE58)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 Étapes',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  if (isCcp) ...[
                    _step('1', 'Rendez-vous au bureau de Poste Algérie'),
                    _step('2',
                        'Demandez un virement vers le compte ci-dessus'),
                    _step('3', 'Conservez votre reçu'),
                    _step('4',
                        'Téléchargez une photo du reçu à l\'étape suivante'),
                  ] else ...[
                    _step('1', 'Ouvrez l\'application BaridiMob'),
                    _step('2',
                        'Choisissez "Virement" puis entrez le numéro ci-dessus'),
                    _step('3', 'Entrez le montant : ${widget.amount} DZD'),
                    _step('4',
                        'Faites une capture d\'écran de la confirmation'),
                    _step('5',
                        'Téléchargez la capture à l\'étape suivante'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── زر التالي ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, a, __) => UploadReceiptScreen(
                        amount: widget.amount, method: widget.method),
                    transitionsBuilder: (_, a, __, child) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: a, curve: Curves.easeOut)),
                      child: child,
                    ),
                  ),
                ),
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: const Text('Télécharger le reçu',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: const Color(0xFF2E7D32).withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _copy(context, value),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child:
                    Icon(Icons.copy, color: Color(0xFF2E7D32), size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(0xFF2E7D32), shape: BoxShape.circle),
            child: Text(num,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }
}
