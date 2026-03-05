import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/telegram_service.dart';
import '../../theme/app_theme.dart';

class TelegramAuthScreen extends StatefulWidget {
  const TelegramAuthScreen({super.key});

  @override
  State<TelegramAuthScreen> createState() => _TelegramAuthScreenState();
}

class _TelegramAuthScreenState extends State<TelegramAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;
  AuthStep _currentStep = AuthStep.phone;

  @override
  void initState() {
    super.initState();
    _initTelegram();
  }

  Future<void> _initTelegram() async {
    try {
      setState(() => _loading = true);
      TelegramService.initClient();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _loading = false;
      });
    }
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = TelegramService.sendCode(_phoneController.text.trim());

      if (result == TelegramService.OK) {
        setState(() {
          _currentStep = AuthStep.code;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to send code';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _submitCode() async {
    if (_codeController.text.isEmpty) {
      setState(() => _error = 'Please enter the code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = TelegramService.submitCode(_codeController.text.trim());

      if (result == TelegramService.OK) {
        await _completeAuth();
      } else if (result == TelegramService.NEED_PASSWORD) {
        setState(() {
          _currentStep = AuthStep.password;
          _loading = false;
        });
      } else if (result == TelegramService.NEED_SIGNUP) {
        setState(() {
          _error = 'Account not found. Please sign up on Telegram first.';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Invalid code';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _submitPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = TelegramService.submitPassword(_passwordController.text);

      if (result == TelegramService.OK) {
        await _completeAuth();
      } else {
        setState(() {
          _error = 'Invalid password';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _completeAuth() async {
    try {
      final session = TelegramService.getSession();
      await TelegramService.saveSession(session);
      if (!mounted) return;
      setState(() => _loading = false);
      await _showSessionDialog(session);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = 'Failed to save session: $e';
        _loading = false;
      });
    }
  }

  Future<void> _showSessionDialog(String session) async {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Telegram Session',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Store this session string safely. You can use it to restore login later.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: SelectableText(
                  session,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: session),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Session copied to clipboard.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                ],
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Telegram Authentication'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 24),
              _buildStepIndicator(),
              const SizedBox(height: 32),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Input fields based on current step
              if (_currentStep == AuthStep.phone) ...[
                _buildPhoneInput(),
                const SizedBox(height: 24),
                _buildActionButton(
                  'Send Code',
                  Icons.send_rounded,
                  _sendCode,
                ),
              ] else if (_currentStep == AuthStep.code) ...[
                _buildCodeInput(),
                const SizedBox(height: 24),
                _buildActionButton(
                  'Verify Code',
                  Icons.check_circle_outline,
                  _submitCode,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = AuthStep.phone;
                      _codeController.clear();
                      _error = null;
                    });
                  },
                  child: Text(
                    'Change Phone Number',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ] else if (_currentStep == AuthStep.password) ...[
                _buildPasswordInput(),
                const SizedBox(height: 24),
                _buildActionButton(
                  'Submit Password',
                  Icons.lock_open_rounded,
                  _submitPassword,
                ),
              ],

              const SizedBox(height: 32),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your Telegram account will be securely linked. We never store your password.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return TextField(
      controller: _phoneController,
      enabled: !_loading,
      keyboardType: TextInputType.phone,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Phone number',
        prefixIcon: const Icon(Icons.phone, color: AppTheme.primaryColor),
        hintText: '+1234567890',
        hintStyle: TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return TextField(
      controller: _codeController,
      enabled: !_loading,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 8,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: 'Verification code',
        hintText: '● ● ● ● ● ●',
        hintStyle: TextStyle(
          color: AppTheme.textMuted,
          letterSpacing: 16,
        ),
        filled: true,
        fillColor: AppTheme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordInput() {
    return TextField(
      controller: _passwordController,
      enabled: !_loading,
      obscureText: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: '2FA password',
        prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryColor),
        hintText: '2FA Password',
        hintStyle: TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: _loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.accentColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.telegram, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            _getTitleText(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getSubtitleText(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepChip(
          label: 'Phone',
          isActive: _currentStep == AuthStep.phone,
        ),
        const SizedBox(width: 8),
        _StepChip(
          label: 'Code',
          isActive: _currentStep == AuthStep.code,
        ),
        const SizedBox(width: 8),
        _StepChip(
          label: '2FA',
          isActive: _currentStep == AuthStep.password,
        ),
      ],
    );
  }

  String _getTitleText() {
    switch (_currentStep) {
      case AuthStep.phone:
        return 'Enter Your Phone Number';
      case AuthStep.code:
        return 'Enter Verification Code';
      case AuthStep.password:
        return 'Enter 2FA Password';
    }
  }

  String _getSubtitleText() {
    switch (_currentStep) {
      case AuthStep.phone:
        return 'We\'ll send a verification code to your Telegram account';
      case AuthStep.code:
        return 'Enter the code you received in Telegram';
      case AuthStep.password:
        return 'Your account has 2FA enabled. Please enter your password';
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

enum AuthStep {
  phone,
  code,
  password,
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool isActive;

  const _StepChip({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryColor.withValues(alpha: 0.2)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? AppTheme.primaryColor : AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
