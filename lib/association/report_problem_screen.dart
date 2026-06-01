import 'package:flutter/material.dart';

class ZadColors {
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color darkNavy = Color(0xFF1A2B4A);
}

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  String? _selectedIssue;
  final TextEditingController _detailsController = TextEditingController();
  bool _isLoading = false;

  // قائمة الخيارات مع ألوانها الأصلية
  final List<Map<String, dynamic>> _options = [
    {
      'label': 'Donneur absent',
      'icon': Icons.person_off_outlined,
      'color': Color(0xFFE8F0FE),
      'darkColor': Color(0xFFC0D3F1),
      'iconColor': Color(0xFF4A90E2),
    },
    {
      'label': 'Don endommagé',
      'icon': Icons.broken_image_outlined,
      'color': Color(0xFFFFECEC),
      'darkColor': Color(0xFFFFC1C1),
      'iconColor': Color(0xFFE53935),
    },
    {
      'label': 'Lieu inaccessible',
      'icon': Icons.map_outlined,
      'color': Color(0xFFE8F5E9),
      'darkColor': Color(0xFFC8E6C9),
      'iconColor': Color(0xFF43A047),
    },
    {
      'label': 'Retard important',
      'icon': Icons.timer_outlined,
      'color': Color(0xFFFFF9C4),
      'darkColor': Color(0xFFFFF176),
      'iconColor': Color(0xFFFBC02D),
    },
    {
      'label': 'Autre',
      'icon': Icons.more_horiz_outlined,
      'color': Color(0xFFF3E5F5),
      'darkColor': Color(0xFFE1BEE7),
      'iconColor': Color(0xFF8E24AA),
    },
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  // ✅ دالة عرض رسالة النجاح
  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rapport envoyé avec succès !',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: ZadColors.leafGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ✅ دالة إرسال التقرير
  Future<void> _submitReport() async {
    if (_selectedIssue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez sélectionner un problème'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // محاكاة إرسال البيانات إلى الخادم
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    // عرض رسالة النجاح
    _showSuccessMessage();

    // تفريغ الحقول بعد الإرسال
    _detailsController.clear();
    setState(() {
      _selectedIssue = null;
    });

    // العودة إلى الصفحة السابقة بعد ثانية ونصف
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, color: ZadColors.darkNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Rapport',
          style: TextStyle(
            color: ZadColors.leafGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quel est le souci ?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ZadColors.darkNavy,
              ),
            ),
            const SizedBox(height: 25),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2,
              ),
              itemCount: _options.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedIssue == _options[index]['label'];

                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedIssue = _options[index]['label']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _options[index]['darkColor']
                          : _options[index]['color'],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? _options[index]['iconColor']
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _options[index]['icon'],
                          color: _options[index]['iconColor'],
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _options[index]['label'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: ZadColors.darkNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),
            const Text(
              "Précisions (Optionnel)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Expliquez ce qu'il s'est passé...",
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // ✅ الزر مع حالة التحميل ورسالة النجاح
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZadColors.leafGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Envoyer le rapport",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
