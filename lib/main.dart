import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'notification_service.dart';
import 'shared/zad_colors.dart';

// Begin
import 'begin/splash_screen.dart';
import 'begin/onboarding_screen1.dart';

// Auth
import 'auth/login_screen.dart' as auth_login;
import 'auth/forgot_password_screen.dart' as auth_forgot;

// Association
import 'association/home_screen.dart' as assoc_home;
import 'association/dons_disponibles_screen.dart';
import 'association/benevoles_screen.dart';
import 'association/beneficiaires_screen.dart';
import 'association/ajouter_beneficiare_screen.dart';
import 'association/notifications_screen.dart' as assoc_notifications;
import 'association/profil_screen.dart';
import 'association/confirmer_reception_screen.dart';
import 'association/publier_bessoin_screen.dart';
import 'association/evaluer_benevole_screen.dart';
import 'association/statistiques_screen.dart';
import 'association/association_register_screen.dart';
import 'association/chat_screen.dart' as assoc_chat;
import 'association/documents_screen.dart';
import 'association/don_details_screen.dart';
import 'association/history_screen.dart' as assoc_history;
import 'association/messages_list_screen.dart';
import 'association/mission_tracking_screen.dart';
import 'association/modifier_profil_screen.dart';
import 'association/report_problem_screen.dart';

// Donateur
import 'donateur/home_screen.dart' as don_home;
import 'donateur/register_step1_screen.dart';
import 'donateur/register_step2_screen.dart';
import 'donateur/publish_don_screen.dart';
import 'donateur/my_dons_screen.dart';
import 'donateur/tracking_screen.dart';
import 'donateur/evaluate_screen.dart';
import 'donateur/stats_screen.dart';
import 'donateur/notifications_screen.dart' as don_notifications;
import 'donateur/messages_screen.dart' as don_messages;
import 'donateur/chat_screen.dart' as don_chat;
import 'donateur/profile_screen.dart' as don_profile;
import 'donateur/confirm_collecte_screen.dart';
import 'donateur/edit_profile_screen.dart' as don_edit_profile;
import 'donateur/historique_dons_screen.dart';
import 'donateur/notif_settings_screen.dart';
import 'donateur/signaler_probleme_screen.dart';
import 'donateur/evaluate_volunteer_screen.dart';
import 'donateur/besoins_screen.dart';

// Benevole
import 'benevole/dashboard_screen.dart' as ben_dashboard;
import 'benevole/register_screen.dart';
import 'benevole/missions_screen.dart' as ben_missions;
import 'benevole/map_screen.dart' as ben_map;
import 'benevole/badges_screen.dart' as ben_badges;
import 'benevole/chat_screen.dart' as ben_chat;
import 'benevole/coupon_qrcode_screen.dart' as ben_coupon;
import 'benevole/edit_profile_screen.dart';
import 'benevole/evaluate_association_screen.dart' as ben_evaluate_assoc;
import 'benevole/messages_screen.dart';
import 'benevole/notification_settings_screen.dart';
import 'benevole/notifications_screen.dart';
import 'benevole/profile_screen.dart';

// ==================== كلاسات التصميم ====================

class AppTheme {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color textDark = Color(0xFF1B1B1B);
  static const Color textGrey = Color(0xFF7A7A7A);
  static const Color hintColor = Color(0xFF9E9E9E);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color errorRed = Color(0xFFD32F2F);
}

class ZadBackground extends StatelessWidget {
  final Widget child;
  const ZadBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F8E9), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      ),
    );
  }
}

class ZADTextField extends StatelessWidget {
  final String? label;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType keyboardType;
  final TextEditingController controller;

  const ZADTextField({
    super.key,
    this.label,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: ZADColors.inputBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.inputBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.hintColor),
              prefixIcon: icon != null
                  ? Icon(icon, color: AppTheme.hintColor)
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ZadTextField extends ZADTextField {
  const ZadTextField({
    super.key,
    required super.label,
    required super.hint,
    required super.controller,
    super.keyboardType = TextInputType.text,
  });
}

class ZADButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool outlined;
  final Color? color;

  const ZADButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : (color ?? ZADColors.primary),
          borderRadius: BorderRadius.circular(14),
          border: outlined
              ? Border.all(color: color ?? ZADColors.primary, width: 2)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  color: outlined
                      ? (color ?? ZADColors.primary)
                      : Colors.white,
                  size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: outlined ? (color ?? ZADColors.primary) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ZADBottomNav extends StatelessWidget {
  final int currentIndex;
  const ZADBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.home_outlined, 'label': 'Accueil', 'route': '/don/home'},
      {'icon': Icons.volunteer_activism_outlined, 'label': 'Dons', 'route': '/don/my_dons'},
      {'icon': Icons.add_circle_outline, 'label': 'Publier', 'route': '/don/publish'},
      {'icon': Icons.bar_chart_outlined, 'label': 'Stats', 'route': '/don/stats'},
      {'icon': Icons.chat_bubble_outline, 'label': 'Messages', 'route': '/don/messages'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              return GestureDetector(
                onTap: () {
                  if (!isActive) {
                    Navigator.pushReplacementNamed(
                        context, items[i]['route'] as String);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i]['icon'] as IconData,
                      color: isActive ? ZADColors.primary : ZADColors.textLight,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive ? ZADColors.primary : ZADColors.textLight,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ==================== ✅ ImagePreviewBox ====================
class ImagePreviewBox extends StatelessWidget {
  final File imageFile;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  const ImagePreviewBox({
    super.key,
    required this.imageFile,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZADColors.primaryLight, width: 1.5),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(
              imageFile,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: onReplace,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ZADColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Changer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ✅ showImagePickerSheet ====================
Future<File?> showImagePickerSheet(
  BuildContext context, {
  String title = 'Choisir une photo',
}) async {
  final picker = ImagePicker();
  File? result;

  await showModalBottomSheet(
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
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ZADColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ZADColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ZADColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.camera_alt, color: ZADColors.primary),
            ),
            title: const Text('Caméra'),
            onTap: () async {
              Navigator.pop(ctx);
              final p = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
              );
              if (p != null) result = File(p.path);
            },
          ),
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ZADColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.photo_library, color: ZADColors.primary),
            ),
            title: const Text('Galerie'),
            onTap: () async {
              Navigator.pop(ctx);
              final p = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (p != null) result = File(p.path);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  return result;
}

// ==================== main ====================

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().init();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const ZADApp());
}

class ZADApp extends StatelessWidget {
  const ZADApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZAD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashScreen(),

      routes: {
        // Begin
        '/onboarding': (_) => const OnboardingScreen1(),

        // Auth
        '/login': (_) => const auth_login.LoginScreen(),
        '/forgot_password': (_) => const auth_forgot.ForgotPasswordScreen(),

        // Association
        '/assoc/home': (_) => const assoc_home.HomeScreen(),
        '/assoc/dons': (_) => const DonsDisponiblesScreen(),
        '/assoc/benevoles': (_) => const BenevolesScreen(),
        '/assoc/beneficiaires': (_) => const BeneficiairesScreen(),
        '/assoc/ajouter-beneficiaire': (_) => const AjouterBeneficiaireScreen(),
        '/assoc/notifications': (_) =>
            const assoc_notifications.NotificationsScreen(),
        '/assoc/profil': (_) => const ProfilScreen(),
        '/assoc/publier_besoin': (_) => const PublierBesoinScreen(),
        '/assoc/evaluer': (_) => const EvaluerBenevoleScreen(),
        '/assoc/statistiques': (_) => const StatistiquesScreen(),
        '/assoc/register': (_) => const AssociationRegisterScreen(),
        '/assoc/documents': (_) => const DocumentsScreen(),
        '/assoc/history': (_) => const assoc_history.HistoryScreen(),
        '/assoc/messages': (_) => const MessagesListScreen(),
        '/assoc/modifier_profil': (_) => const ModifierProfilScreen(),
        '/assoc/report_problem': (_) => const ReportProblemScreen(),

        // Donateur
        '/don/register': (_) => const RegisterStep1Screen(),
        '/don/home': (_) => const don_home.HomeScreen(),
        '/don/publish': (_) => const PublishDonScreen(),
        '/don/my_dons': (_) => const MyDonsScreen(),
        '/don/evaluate': (_) => const EvaluateScreen(),
        '/don/stats': (_) => const StatsScreen(),
        '/don/notifications': (_) =>
            const don_notifications.NotificationsScreen(),
        '/don/messages': (_) => const don_messages.MessagesScreen(),
        '/don/profile': (_) => const don_profile.ProfileScreen(),
        '/don/edit_profile': (_) =>
            const don_edit_profile.DonateurEditProfileScreen(),
        '/don/historique_dons': (_) => const HistoriqueDonsScreen(),
        '/don/notif_settings': (_) => const NotifSettingsScreen(),
        '/don/signaler_probleme': (_) => const SignalerProblemeScreen(),
        '/don/besoins': (_) => const BesoinsScreen(),

        // Benevole
        '/ben/dashboard': (_) => const ben_dashboard.BenevoleDashboardScreen(),
        '/ben/register': (_) => const BenevoleRegisterScreen(),
        '/ben/missions': (_) => const ben_missions.BenevoleMissionsScreen(),
        '/ben/map': (_) => const ben_map.BenevoleMapScreen(),
        '/ben/badges': (_) => const ben_badges.BenevoleBadgesScreen(),
        '/ben/edit_profile': (_) => const BenevoleEditProfileScreen(),
        '/ben/messages': (_) => const BenevoleMessagesScreen(),
        '/ben/notif_settings': (_) =>
            const BenevoleNotificationSettingsScreen(),
        '/ben/notifications': (_) => const BenevoleNotificationsScreen(),
        '/ben/profile': (_) => const BenevoleProfileScreen(),
      },

      onGenerateRoute: (settings) {
        // Association - Confirmer réception (requires donId)
        if (settings.name == '/assoc/confirmer-reception') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => ConfirmerReceptionScreen(
              donId: args?['donId'] ?? '',
            ),
          );
        }

        // Association - Mission tracking (requires donId)
        if (settings.name == '/assoc/mission_tracking') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => MissionTrackingScreen(
              donId: args?['donId'] ?? '',
            ),
          );
        }

        // Association - Don details (requires donId + donData)
        if (settings.name == '/assoc/don_details') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => DonDetailsScreen(
              donId: args?['donId'] ?? '',
              donData: args?['donData'] as Map<String, dynamic>? ??
                  {
                    'titre': '',
                    'source': '',
                    'adresse': '',
                    'quantite': '',
                    'expiration': '',
                    'description': '',
                    'isUrgent': false,
                    'statut': 'En attente',
                  },
            ),
          );
        }

        // Donateur - Tracking (requires donId)
        if (settings.name == '/don/tracking') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => TrackingScreen(
              donId: args?['donId'] ?? '',
            ),
          );
        }

        // Donateur - Confirm collecte (requires donId)
        if (settings.name == '/don/confirm_collecte') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => ConfirmCollecteScreen(
              donId: args?['donId'] ?? '',
            ),
          );
        }

        // Donateur - Register step 2 (requires user data)
        if (settings.name == '/don/register2') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => RegisterStep2Screen(
              nom: args?['nom'] ?? '',
              email: args?['email'] ?? '',
              phone: args?['phone'] ?? '',
              quartier: args?['quartier'] ?? '',
              genre: args?['genre'] ?? '',
              donorType: args?['donorType'] ?? '',
              birthDate: args?['birthDate'] ?? DateTime.now(),
            ),
          );
        }

        // Donateur - Evaluate volunteer (requires volunteer data)
        if (settings.name == '/don/evaluate_volunteer') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => EvaluateVolunteerScreen(
              volunteerName: args?['volunteerName'] ?? '',
              volunteerInitials: args?['volunteerInitials'] ?? '',
              currentRating: (args?['currentRating'] ?? 0.0).toDouble(),
              volunteerId: args?['volunteerId'] ?? '',
              donationId: args?['donationId'] ?? '',
              missionTitle: args?['missionTitle'] ?? '',
            ),
          );
        }

        // Association - Chat (requires contact data)
        if (settings.name == '/assoc/chat') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => assoc_chat.ChatScreen(
              contactName: args?['contactName'] ?? '',
              contactInitials: args?['contactInitials'] ?? '',
              contactId: args?['contactId'] ?? '',
            ),
          );
        }

        // Donateur - Chat (requires contact data)
        if (settings.name == '/don/chat') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => don_chat.ChatScreen(
              contactName: args?['contactName'] ?? '',
              contactInitials: args?['contactInitials'] ?? '',
              contactBgColor: args?['contactBgColor'] ?? ZADColors.primary,
              contactPhone: args?['contactPhone'] ?? '',
              contactId: args?['contactId'] ?? '',
            ),
          );
        }

        // Benevole - Chat (requires contact data)
        if (settings.name == '/ben/chat') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => ben_chat.BenevoleChatScreen(
              name: args?['name'] ?? '',
              avatar: args?['avatar'] ?? '',
              avatarColor: args?['avatarColor'] ?? const Color(0xFF4CAF50),
              isOnline: args?['isOnline'] ?? false,
              contactId: args?['contactId'] ?? '',
            ),
          );
        }

        // Benevole - Coupon QR Code (requires coupon data)
        if (settings.name == '/ben/coupon') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => ben_coupon.CouponQRCodeScreen(
              title: args?['title'] ?? '',
              partner: args?['partner'] ?? '',
              code: args?['code'] ?? '',
              expiry: args?['expiry'] ?? '',
              type: args?['type'] ?? 'meal',
            ),
          );
        }

        // Benevole - Evaluate association (requires association data)
        if (settings.name == '/ben/evaluate_assoc') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => ben_evaluate_assoc.EvaluateAssociationScreen(
              associationName: args?['associationName'] ?? '',
              missionTitle: args?['missionTitle'] ?? '',
              quantity: args?['quantity'] ?? '',
            ),
          );
        }

        return null;
      },
    );
  }
}