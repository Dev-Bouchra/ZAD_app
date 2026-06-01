import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'register_screen.dart';

const Color primaryGreen = Color(0xFF4ADE80);

bool isValidPhone(String phone) {
  return RegExp(r'^[0-9]{10,15}$').hasMatch(phone);
}

class SMSService {
  static Future<bool> sendResetCode(String phone, String code) async {
    await Future.delayed(const Duration(seconds: 1));
    print('=================================');
    print('📱 PHONE: $phone');
    print('🔐 RESET CODE: $code');
    print('📋 COPY THIS CODE: $code');
    print('=================================');
    return true;
  }
}

class CircleShape extends CustomPainter {
  final Color color;
  final double opacity;

  CircleShape({required this.color, this.opacity = 0.15});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.3),
      size.width * 0.4,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BottomCircleShape extends CustomPainter {
  final Color color;
  final double opacity;

  BottomCircleShape({required this.color, this.opacity = 0.15});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.7),
      size.width * 0.4,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isObscure = true;
  String? _errorText;

  void _login() {
    setState(() {
      if (_passController.text != "123456") {
        _errorText = "Incorrect password. Please check your password.";
      } else {
        _errorText = null;
        _showSnackBar('Login successful!', const Color.fromARGB(255, 43, 160, 86));
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 340,
                height: 340,
                child: Icon(
                  Icons.eco,
                  size: 320,
                  color: primaryGreen.withOpacity(0.2),
                ),
              ),
            ),
          ),
          Positioned(
            top: -20,
            right: -20,
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: CircleShape(
                  color: primaryGreen,
                  opacity: 0.15,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: BottomCircleShape(
                  color: primaryGreen,
                  opacity: 0.15,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Se connecter",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Espace Bénévole",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 50),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "E-mail",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF616161),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: "Enter your email",
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Password",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF616161),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _passController,
                          obscureText: _isObscure,
                          decoration: InputDecoration(
                            hintText: "Enter your password",
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isObscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _isObscure = !_isObscure),
                            ),
                          ),
                        ),
                      ),
                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _login,
                      child: const Text(
                        "Se connecter",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "ou",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Pas encore de compte ?",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF616161),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Rejoignez ZAD en tant que Bénévole",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                 OutlinedButton(
                    onPressed: () {Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BenevoleRegisterScreen(),
      ),
    );
  },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      side: const BorderSide(color: Color(0xFF4ADE80)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Créer un compte",
                      style: TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 14,
                      ),
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
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _generatedCode = '';

  String _generateResetCode() {
    return (1000 + math.Random().nextInt(9000)).toString();
  }

  String formatAlgerianPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '+213${cleaned.substring(1)}';
    } else if (cleaned.startsWith(RegExp(r'[5-7]')) && cleaned.length == 9) {
      return '+213$cleaned';
    } else if (cleaned.startsWith('213') && cleaned.length == 12) {
      return '+$cleaned';
    } else {
      return '+213$cleaned';
    }
  }

  Future<void> _sendResetCode() async {
    String phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      _showSnackBar('Please enter your phone number', Colors.red);
      return;
    }

    String formattedPhone = formatAlgerianPhone(phone);
    
    setState(() {
      _isLoading = true;
      _generatedCode = _generateResetCode();
    });
    
    await SMSService.sendResetCode(formattedPhone, _generatedCode);
    
    if (mounted) {
      setState(() => _isLoading = false);
      _showSnackBar('✓ Code sent to $phone', primaryGreen);
      Navigator.pushNamed(
        context, 
        '/verify-code', 
        arguments: {
          'phone': phone,
          'code': _generatedCode,
        },
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4ADE80)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Forgot Password",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "No worries! Enter your phone number below and we will send you a code to reset password.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Phone Number",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: "05XXXXXXXX or 06XXXXXXXX or 07XXXXXXXX",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _sendResetCode,
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
                        "Send Reset Code",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});
  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  int _counter = 59;
  Timer? _timer;
  bool _canResend = false;
  String? _phone;
  String? _correctCode;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        setState(() {
          _phone = args['phone'];
          _correctCode = args['code'];
        });
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_counter > 0) {
        setState(() => _counter--);
      } else {
        setState(() => _canResend = true);
        _timer?.cancel();
      }
    });
  }

  Future<void> _resendCode() async {
    setState(() {
      _counter = 59;
      _canResend = false;
    });
    _startTimer();
    
    if (_phone != null) {
      String newCode = (1000 + math.Random().nextInt(9000)).toString();
      String formattedPhone = _phone!.startsWith('0') ? '+213${_phone!.substring(1)}' : _phone!;
      await SMSService.sendResetCode(formattedPhone, newCode);
      setState(() => _correctCode = newCode);
      _showSnackBar('✓ New code sent', primaryGreen);
    }
  }

  void _verifyCode() {
    String code = _codeController.text.trim();
    
    if (code.length != 4) {
      _showSnackBar('Please enter a valid 4-digit code', Colors.red);
      return;
    }
    
    if (code != _correctCode) {
      _showSnackBar('Invalid code. Please try again.', Colors.red);
      return;
    }
    
    _showSnackBar('✓ Code verified successfully!', primaryGreen);
    Navigator.pushNamed(context, '/reset-password');
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4ADE80)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text(
              "4 Digit Code",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _phone != null 
                  ? "Code has been sent to $_phone"
                  : "Code has been sent to your phone",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: "4 Digit Code",
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText: "",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF616161)),
                children: [
                  const TextSpan(text: "Didn't receive code? "),
                  if (_canResend)
                    TextSpan(
                      text: "Resend Code",
                      style: const TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = _resendCode,
                    )
                  else
                    TextSpan(
                      text: "Resend code in 00:${_counter.toString().padLeft(2, '0')}",
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _verifyCode,
                child: const Text(
                  "Verify Account",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  void _resetPassword() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4ADE80)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Create New Password",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Please enter and confirm your new password. You will need to login after you reset.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Password",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: "must contain 8 char.",
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Confirm Password",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      hintText: ".........",
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 34, 185, 89),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _resetPassword,
                child: const Text(
                  "Reset Password",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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