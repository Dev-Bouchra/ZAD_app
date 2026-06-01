import 'package:flutter/material.dart';
import '../benevole/register_screen.dart';
import '../association/association_register_screen.dart';
import '../donateur/register_step1_screen.dart';

class OnboardingScreen2 extends StatefulWidget {
  const OnboardingScreen2({super.key});
  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String? _selectedRole;

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'association',
      'title': 'Association',
      'subtitle': 'Recevez et distribuez des dons alimentaires',
      'icon': Icons.account_balance,
      'colorNormal': const Color(0xFFFFFFFF),
      'colorSelected': const Color(0xFFE8F5E9),
      'iconColorNormal': const Color(0xFF388E3C),
      'iconBgNormal': const Color(0xFFE8F5E9),
      'iconBgSelected': const Color(0xFF388E3C),
    },
    {
      'id': 'donateur',
      'title': 'Donateur',
      'subtitle': 'Restaurants, commerces ou particuliers',
      'icon': Icons.favorite,
      'colorNormal': const Color(0xFFFFFFFF),
      'colorSelected': const Color(0xFFE3F2FD),
      'iconColorNormal': const Color(0xFF1565C0),
      'iconBgNormal': const Color(0xFFE3F2FD),
      'iconBgSelected': const Color(0xFF1565C0),
    },
    {
      'id': 'benevole',
      'title': 'Bénévole',
      'subtitle': 'Transportez les dons vers les associations',
      'icon': Icons.directions_bike,
      'colorNormal': const Color(0xFFFFFFFF),
      'colorSelected': const Color(0xFFFFF3E0),
      'iconColorNormal': const Color(0xFFE65100),
      'iconBgNormal': const Color(0xFFFFF3E0),
      'iconBgSelected': const Color(0xFFE65100),
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAF0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Image.asset('images/logo.png', height: 40),
            ),
            FadeTransition(
              opacity: _controller,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      'Choisissez votre rôle',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sélectionnez comment vous souhaitez participer',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF558B2F)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _roles.length,
                itemBuilder: (context, index) {
                  final start = 0.15 * index;
                  final end = start + 0.4;
                  final slideAnim =
                      Tween<Offset>(
                        begin: const Offset(1.0, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: Interval(start, end, curve: Curves.easeOut),
                        ),
                      );
                  final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Interval(start, end, curve: Curves.easeIn),
                    ),
                  );
                  return SlideTransition(
                    position: slideAnim,
                    child: FadeTransition(
                      opacity: fadeAnim,
                      child: _buildRoleCard(_roles[index]),
                    ),
                  );
                },
              ),
            ),
            _buildContinuerButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role) {
    final isSelected = _selectedRole == role['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? role['colorSelected'] : role['colorNormal'],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2E7D32)
                : const Color(0xFFE0E0E0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.08),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? role['iconBgSelected']
                    : role['iconBgNormal'],
                shape: BoxShape.circle,
              ),
              child: Icon(
                role['icon'],
                color: isSelected ? Colors.white : role['iconColorNormal'],
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role['title'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role['subtitle'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78909C),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF2E7D32)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFBDBDBD),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinuerButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _selectedRole != null ? 1.0 : 0.5,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _selectedRole != null
                    ? () {
                        // دالة داخلية للتعامل مع الانتقال ومسح الصفحات السابقة من الذاكرة
                        void navigate(Widget target) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => target),
                            (route) => false,
                          );
                        }

                        if (_selectedRole == 'benevole') {
                          navigate(const BenevoleRegisterScreen());
                        } else if (_selectedRole == 'association') {
                          navigate(const AssociationRegisterScreen());
                        } else if (_selectedRole == 'donateur') {
                          navigate(const RegisterStep1Screen());
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  disabledBackgroundColor: const Color(0xFFA5D6A7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Continuer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_dot(false), _dot(false), _dot(true)],
          ),
        ],
      ),
    );
  }

  Widget _dot(bool active) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.symmetric(horizontal: 4),
    width: active ? 20 : 8,
    height: 8,
    decoration: BoxDecoration(
      color: active ? const Color(0xFF2E7D32) : const Color(0xFFA5D6A7),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
