import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================================
  // MOSTRAR / OCULTAR CONTRASEÑA
  // ============================================================
  bool _obscure = true;

  // ============================================================
  // REMEMBER ME
  // ============================================================
  bool _rememberMe = false;

  // Bloquea temporalmente el checkbox mientras ocurre
  // la animación visual del cambio.
  bool _rememberMeLocked = false;

  // ============================================================
  // RIVE
  // ============================================================
  StateMachineController? _controller;

  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  // ============================================================
  // TIMER PARA EL EFECTO DE ESCRITURA
  // ============================================================
  Timer? _typingDebounce;

  // ============================================================
  // FOCUS NODES
  // ============================================================
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // ============================================================
  // TEXT CONTROLLERS
  // ============================================================
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // ============================================================
  // ERRORES
  // ============================================================
  String? emailError;
  String? passError;

  // ============================================================
  // VALIDAR EMAIL
  // ============================================================
  bool isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  // ============================================================
  // VALIDAR PASSWORD
  // ============================================================
  bool isValidPassword(String pass) {
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );

    return re.hasMatch(pass);
  }

  // ============================================================
  // LOGIN
  // ============================================================
  void _onLogin() {
    // Quitar espacios del correo
    final email = _emailCtrl.text.trim();

    // Obtener contraseña
    final pass = _passCtrl.text;

    // Validar
    final eError = isValidEmail(email) ? null : 'Invalid email';
    final pError = isValidPassword(pass) ? null : 'Invalid password';

    // Actualizar errores
    setState(() {
      emailError = eError;
      passError = pError;
    });

    // Cerrar teclado
    FocusScope.of(context).unfocus();

    // Cancelar timer
    _typingDebounce?.cancel();

    // Bajar las manos
    _isChecking?.change(false);
    _isHandsUp?.change(false);

    // Mirada neutra
    _numLook?.value = 50.0;

    // Ejecutar animación correspondiente
    if (eError == null && pError == null) {
      _trigSuccess?.fire();
    } else {
      _trigFail?.fire();
    }
  }

  // ============================================================
  // REMEMBER ME
  // ============================================================
  void _toggleRememberMe(bool? value) {
    // Si está bloqueado, ignorar el toque.
    if (_rememberMeLocked) {
      return;
    }

    // Evitar valores nulos
    if (value == null) {
      return;
    }

    // Bloquear temporalmente múltiples toques.
    setState(() {
      _rememberMeLocked = true;
      _rememberMe = value;
    });

    // Esperar a que termine la animación visual del checkbox.
    //
    // Esto evita el problema de "anti-spam" cuando el usuario
    // presiona rápidamente varias veces.
    Future.delayed(const Duration(milliseconds: 250), () {
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

    // ----------------------------------------------------------
    // EMAIL FOCUS
    // ----------------------------------------------------------
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        if (_isHandsUp != null) {
          // Manos abajo
          _isHandsUp?.change(false);

          // Mirada neutra
          _numLook?.value = 50.0;
        }
      }
    });

    // ----------------------------------------------------------
    // PASSWORD FOCUS
    // ----------------------------------------------------------
    _passwordFocus.addListener(() {
      // Manos arriba cuando el password tiene foco
      _isHandsUp?.change(_passwordFocus.hasFocus);
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
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
                      // Crear controlador
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );
        
                      // Verificar que se haya creado
                      if (_controller == null) {
                        return;
                      }
        
                      // Agregar controlador
                      artboard.addController(_controller!);
        
                      // Vincular variables
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
        
                  onChanged: (value) {
                    if (_isHandsUp != null) {
                      // No tapar los ojos para el email
                      _isHandsUp!.change(false);
                    }
        
                    if (_isChecking == null) {
                      return;
                    }
        
                    // Activar modo de escritura
                    _isChecking!.change(true);
        
                    // Calcular mirada
                    final look =
                        (value.length / 60.0 * 100.0).clamp(0.0, 100.0);
        
                    _numLook?.value = look;
        
                    // Reiniciar debounce
                    _typingDebounce?.cancel();
        
                    _typingDebounce = Timer(
                      const Duration(seconds: 3),
                      () {
                        if (!mounted) return;
        
                        // Regresar mirada a neutra
                        _isChecking?.change(false);
                      },
                    );
                  },
        
                  keyboardType: TextInputType.emailAddress,
        
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
        
                  onChanged: (value) {
                    if (_isChecking != null) {
                      _isChecking!.change(false);
                    }
        
                    if (_isHandsUp == null) {
                      return;
                    }
        
                    // Manos arriba
                    _isHandsUp!.change(true);
                  },
        
                  obscureText: _obscure,
        
                  decoration: InputDecoration(
                    errorText: passError,
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
        
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ------------------------------------------------
                      // REMEMBER ME - IZQUIERDA
                      // ------------------------------------------------
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _rememberMe,
        
                            // Bloquear interacción mientras cambia.
                            onChanged: _rememberMeLocked
                                ? null
                                : _toggleRememberMe,
        
                            // Duración de la animación visual
                            // del checkbox.
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
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
        
                      // ------------------------------------------------
                      // FORGOT PASSWORD - DERECHA
                      // ------------------------------------------------
                      TextButton(
                        onPressed: () {
                          // Aquí posteriormente puedes agregar
                          // la navegación para recuperar contraseña.
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
        
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
        
                  onPressed: _onLogin,
        
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
        
                const SizedBox(height: 10),
        
                // ==================================================
                // SIGN UP
                // ==================================================
                SizedBox(
                  width: size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                      ),
        
                      TextButton(
                        onPressed: () {},
        
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
    // Liberar controllers
    _emailCtrl.dispose();
    _passCtrl.dispose();

    // Liberar FocusNodes
    _emailFocus.dispose();
    _passwordFocus.dispose();

    // Cancelar timer
    _typingDebounce?.cancel();

    super.dispose();
  }
}