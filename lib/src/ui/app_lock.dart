part of '../../main.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.state,
    required this.onUnlocked,
  });

  final CsacAppState state;
  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final auth = LocalAuthentication();
  String pin = '';
  bool checkingBiometric = false;
  bool biometricAvailable = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hidePlatformTextInput();
      checkBiometric();
    });
  }

  Future<void> checkBiometric() async {
    if (!supportsLocalAuth ||
        !widget.state.preferences.appLockBiometricEnabled) {
      return;
    }
    try {
      final supported = await auth.isDeviceSupported();
      final biometrics = await auth.canCheckBiometrics;
      if (!mounted) {
        return;
      }
      setState(() => biometricAvailable = supported || biometrics);
      if (supported || biometrics) {
        await unlockWithBiometric();
      }
    } catch (_) {
      if (mounted) {
        setState(() => biometricAvailable = false);
      }
    }
  }

  Future<void> unlockWithBiometric() async {
    if (!supportsLocalAuth || checkingBiometric) {
      return;
    }
    setState(() {
      checkingBiometric = true;
      error = null;
    });
    try {
      final ok = await auth.authenticate(
        localizedReason: context.strings.text('Unlock CsAC to view chats'),
        persistAcrossBackgrounding: true,
        sensitiveTransaction: false,
      );
      if (ok && mounted) {
        widget.onUnlocked();
      }
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => checkingBiometric = false);
      }
    }
  }

  void unlockWithPin() {
    if (widget.state.verifyAppLockPin(pin)) {
      widget.onUnlocked();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      error = context.strings.text('Incorrect PIN.');
      pin = '';
    });
  }

  void updatePin(String value) {
    setState(() {
      pin = value;
      error = null;
    });
    if (value.length >= 8) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pin.length >= 8) {
          unlockWithPin();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final colors = CsacColors.of(context);
    return ColoredBox(
      color: colors.systemBackground,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_rounded, size: 58, color: scheme.primary),
                  const SizedBox(height: 18),
                  Text(
                    strings.text('App locked'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.text('Enter your PIN to protect chat history.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _PinEntryPad(
                    value: pin,
                    onChanged: updatePin,
                    label: strings.text('PIN'),
                    helperText: strings.text('4-8 digits'),
                    leadingIcon:
                        supportsLocalAuth &&
                            widget.state.preferences.appLockBiometricEnabled &&
                            biometricAvailable
                        ? Icons.fingerprint
                        : null,
                    leadingTooltip: strings.text('Use biometrics'),
                    onLeadingPressed: checkingBiometric
                        ? null
                        : unlockWithBiometric,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: AppLockPin.isValid(pin) ? unlockWithPin : null,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: Text(strings.text('Unlock')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
