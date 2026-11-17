import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:login_bear_animation/auth_animation_lock.dart';
import 'package:login_bear_animation/screens/forgot_password_screen.dart';
import 'package:login_bear_animation/screens/register_screen.dart';
import 'package:rive/rive.dart';

class LoginScreen extends StatefulWidget {
  final String? connectionStatus;

  const LoginScreen({super.key, this.connectionStatus});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================================
  // ESTADOS DE INTERFAZ
  // ============================================================
  bool _obscure = true;
  bool _rememberMe = false;
  bool _rememberMeLocked = false;
  bool _isLoading = false;

  // ============================================================
  // RIVE
  // ============================================================
  StateMachineController? _controller;

  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  // Último estado informado por la máquina de Rive.
  String _currentBearState = 'idle';

  // Se registra ANTES de cambiar isHandsUp para no perder el evento idle.
  Completer<void>? _bearIdleCompleter;

  Timer? _typingDebounce;
  Timer? _rememberMeTimer;

  // ============================================================
  // FOCUS NODES Y TEXT CONTROLLERS
  // ============================================================
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  String? emailError;
  String? passError;

  // ============================================================
  // VALIDACIONES LOCALES
  // ============================================================
  bool isValidEmail(String email) {
    final RegExp re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  bool isValidPassword(String pass) {
    return pass.length >= 6;
  }

  // ============================================================
  // DETECTAR EL ESTADO DE REPOSO DE RIVE
  // ============================================================
  bool _isIdleState(String stateName) {
    final String state = stateName.toLowerCase();
    return state.contains('idle') && !state.contains('look');
  }

  // ============================================================
  // PREPARAR OSITO PARA EL RESULTADO
  // ============================================================
  Future<void> _prepareBearForLogin() async {
    _typingDebounce?.cancel();

    // Capturar el foco ANTES de cerrarlo. Si estaba en Password,
    // sabemos que el oso probablemente estaba en la pose Hands_up.
    final bool passwordWasFocused = _passwordFocus.hasFocus;
    final bool mustWaitForIdle =
        passwordWasFocused || !_isIdleState(_currentBearState);

    _controller?.isActive = true;

    // Registrar primero la espera; después cambiaremos isHandsUp.
    // Así no se pierde una notificación idle rápida de Rive.
    Completer<void>? waiter;
    if (mustWaitForIdle) {
      waiter = Completer<void>();
      _bearIdleCompleter = waiter;
    }

    // Cerrar el teclado y ordenar que el oso baje las manos.
    _passwordFocus.unfocus();
    _emailFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    _isChecking?.change(false);
    _numLook?.value = 50.0;
    _isHandsUp?.change(false);

    if (waiter != null) {
      try {
        // Esperar el cambio REAL a idle, no una duración supuesta.
        await waiter.future.timeout(const Duration(milliseconds: 1800));
        debugPrint('RIVE: Se detectó idle después de bajar las manos.');

        // IMPORTANTE: Rive puede notificar la entrada a 'idle' cuando
        // comienza la transición visual, no cuando termina de dibujarla.
        // La transición hands_down dura aproximadamente 650 ms.
        // Esperamos 700 ms para dejarla terminar antes del trigger.
        await Future.delayed(const Duration(milliseconds: 700));
        debugPrint('RIVE: Transición hands_down terminada (700 ms).');
      } on TimeoutException {
        debugPrint(
          'RIVE TIMEOUT: No se detectó idle en 1800 ms. '
          'Último estado: $_currentBearState. '
          'Revisar la transición Hands_up -> hands_down -> idle en Rive.',
        );
      } finally {
        if (identical(_bearIdleCompleter, waiter)) {
          _bearIdleCompleter = null;
        }
      }
    }

    // Separar el callback de estado de la ejecución del trigger.
    await Future.delayed(const Duration(milliseconds: 50));
    debugPrint('RIVE: Estado antes de autenticar: $_currentBearState');
  }

  // ============================================================
  // DISPARAR RESULTADO RIVE
  // ============================================================
  void _fireBearResult(SMITrigger? trigger, String triggerName) {
    if (!mounted) return;

    _controller?.isActive = true;

    if (_controller == null || trigger == null) {
      debugPrint(
        'ERROR RIVE: No se pudo disparar $triggerName. '
        'Controller: ${_controller != null}, trigger: ${trigger != null}',
      );
      return;
    }

    debugPrint(
      'RIVE: Intentando disparar $triggerName desde estado $_currentBearState',
    );
    trigger.fire();
    debugPrint('RIVE: Se envió el trigger $triggerName');
  }

  // ============================================================
  // MAPEO DE ERRORES DE FIREBASE AUTH
  // ============================================================
  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta registrada con este correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El formato del correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Verifica tu red.';
      default:
        return 'Error de autenticación: ${e.message ?? e.code}';
    }
  }

  void _showLoginError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ============================================================
  // LOGIN CON FIREBASE AUTH + RIVE
  // ============================================================
  Future<void> _onLogin() async {
    // Bloquear el botón desde el primer toque, incluso durante
    // el tiempo que tarda el osito en bajar las manos.
    if (_isLoading) return;

    final String email = _emailCtrl.text.trim();
    final String pass = _passCtrl.text;

    final String? eError =
        isValidEmail(email) ? null : 'Ingresa un correo válido';
    final String? pError =
        isValidPassword(pass) ? null : 'Mínimo 6 caracteres requeridos';

    setState(() {
      emailError = eError;
      passError = pError;
      _isLoading = true;
    });

    try {
      // Primero se cierra el teclado y se bajan las manos.
      // Esto ocurre tanto si los datos son válidos como si no lo son.
      await _prepareBearForLogin();

      if (!mounted) return;

      // Si la validación local falla, mostrar Fail sin consultar Firebase.
      if (eError != null || pError != null) {
        _fireBearResult(_trigFail, 'trigFail');
        return;
      }

      // AuthGate permanecerá en LoginScreen mientras se muestra Success.
      authAnimationLock.value = true;

      try {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: email,
              password: pass,
            )
            .timeout(const Duration(seconds: 15));

        if (!mounted) return;

        // El osito ya tuvo tiempo de bajar las manos antes de llegar aquí.
        _fireBearResult(_trigSuccess, 'trigSuccess');

        // Mantener Login visible para que se aprecie la animación.
        await Future.delayed(const Duration(milliseconds: 2000));
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        _fireBearResult(_trigFail, 'trigFail');
        _showLoginError(_mapFirebaseAuthError(e));
      } on TimeoutException {
        if (!mounted) return;

        _fireBearResult(_trigFail, 'trigFail');
        _showLoginError('Tiempo de espera agotado. Revisa tu conexión.');
      } catch (e) {
        if (!mounted) return;

        _fireBearResult(_trigFail, 'trigFail');
        _showLoginError('Error inesperado: $e');
      } finally {
        // Liberar AuthGate tanto en éxito como en error.
        authAnimationLock.value = false;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // REMEMBER ME
  // ============================================================
  void _toggleRememberMe(bool? value) {
    if (_rememberMeLocked || value == null) return;

    setState(() {
      _rememberMeLocked = true;
      _rememberMe = value;
    });

    _rememberMeTimer?.cancel();
    _rememberMeTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _rememberMeLocked = false;
      });
    });
  }

  // ============================================================
  // INIT STATE
  // ============================================================
  @override
  void initState() {
    super.initState();

    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        _isHandsUp?.change(false);
        _numLook?.value = 50.0;
      }
    });

    _passwordFocus.addListener(() {
      if (!_isLoading) {
        _isHandsUp?.change(_passwordFocus.hasFocus);
      }
    });
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // INDICADOR DE CONEXIÓN FIREBASE
                if (widget.connectionStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.connectionStatus!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ==================================================
                // ANIMACIÓN RIVE
                // ==================================================
                SizedBox(
                  width: size.width,
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/login-bear.riv',
                    stateMachines: const ['Login Machine'],
                    onInit: (artboard) {
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                        onStateChange: (stateMachineName, stateName) {
                          _currentBearState = stateName;
                          debugPrint(
                            'RIVE STATE: machine=$stateMachineName, '
                            'state=$stateName',
                          );

                          // Completar la espera únicamente cuando Rive
                          // confirme que regresó a idle.
                          if (_isIdleState(stateName)) {
                            final Completer<void>? waiter =
                                _bearIdleCompleter;
                            if (waiter != null && !waiter.isCompleted) {
                              waiter.complete();
                            }
                          }
                        },
                      );

                      if (_controller == null) {
                        debugPrint(
                          'ERROR RIVE: No se encontró Login Machine.',
                        );
                        return;
                      }

                      artboard.addController(_controller!);

                      _isChecking =
                          _controller!.findSMI('isChecking') as SMIBool?;
                      _isHandsUp =
                          _controller!.findSMI('isHandsUp') as SMIBool?;
                      _trigSuccess =
                          _controller!.findSMI('trigSuccess') as SMITrigger?;
                      _trigFail =
                          _controller!.findSMI('trigFail') as SMITrigger?;
                      _numLook =
                          _controller!.findSMI('numLook') as SMINumber?;

                      debugPrint(
                        'RIVE INPUTS: '
                        'isChecking=${_isChecking != null}, '
                        'isHandsUp=${_isHandsUp != null}, '
                        'trigSuccess=${_trigSuccess != null}, '
                        'trigFail=${_trigFail != null}, '
                        'numLook=${_numLook != null}',
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // EMAIL
                // ==================================================
                TextField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  readOnly: _isLoading,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    _isHandsUp?.change(false);
                    if (_isChecking == null) return;

                    _isChecking!.change(true);
                    final double look =
                        (value.length / 60.0 * 100.0)
                            .clamp(0.0, 100.0)
                            .toDouble();
                    _numLook?.value = look;

                    _typingDebounce?.cancel();
                    _typingDebounce = Timer(
                      const Duration(seconds: 3),
                      () {
                        if (!mounted) return;
                        _isChecking?.change(false);
                      },
                    );
                  },
                  decoration: InputDecoration(
                    errorText: emailError,
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // PASSWORD
                // ==================================================
                TextField(
                  controller: _passCtrl,
                  focusNode: _passwordFocus,
                  readOnly: _isLoading,
                  obscureText: _obscure,
                  onChanged: (value) {
                    _isChecking?.change(false);
                    _isHandsUp?.change(_passwordFocus.hasFocus);
                  },
                  decoration: InputDecoration(
                    errorText: passError,
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // REMEMBER ME + FORGOT PASSWORD
                // ==================================================
                SizedBox(
                  width: size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _rememberMeLocked
                                ? null
                                : _toggleRememberMe,
                            side: const BorderSide(
                              width: 1.5,
                              color: Colors.black54,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 2),
                          const Text(
                            'Remember me',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      initialEmail: _emailCtrl.text.trim(),
                                    ),
                                  ),
                                );
                              },
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // LOGIN BUTTON
                // ==================================================
                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: Colors.pinkAccent,
                  disabledColor: Colors.pinkAccent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _isLoading ? null : _onLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // SIGN UP LINK
                // ==================================================
                SizedBox(
                  width: size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _typingDebounce?.cancel();
    _rememberMeTimer?.cancel();
    super.dispose();
  }
}
