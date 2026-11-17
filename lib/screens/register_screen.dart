import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmPassFocus = FocusNode();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Rive
  StateMachineController? _controller;
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();

    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus) {
        _isHandsUp?.change(false);
        _numLook?.value = 50.0;
      }
    });

    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        _isHandsUp?.change(false);
        _numLook?.value = 50.0;
      }
    });

    _passFocus.addListener(() {
      if (_passFocus.hasFocus) {
        _isHandsUp?.change(true);
      } else if (!_confirmPassFocus.hasFocus) {
        _isHandsUp?.change(false);
      }
    });

    _confirmPassFocus.addListener(() {
      if (_confirmPassFocus.hasFocus) {
        _isHandsUp?.change(true);
      } else if (!_passFocus.hasFocus) {
        _isHandsUp?.change(false);
      }
    });
  }

  void _onLookTextChanged(String value) {
    _isHandsUp?.change(false);
    if (_isChecking == null) return;

    _isChecking!.change(true);
    _numLook?.value = (value.length / 40.0 * 100.0).clamp(0.0, 100.0);

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _isChecking?.change(false);
    });
  }

  bool _isStrongPassword(String pass) {
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );
    return re.hasMatch(pass);
  }

  String _mapRegisterError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este correo ya está registrado. Intenta iniciar sesión.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'operation-not-allowed':
        return 'El registro con correo/contraseña no está habilitado.';
      default:
        return 'Error al registrar usuario: ${e.message ?? e.code}';
    }
  }

  Future<void> _onRegister() async {
    if (_isLoading) return;

    // Ocultar teclado inmediatamente y bajar las manos del osito
    FocusManager.instance.primaryFocus?.unfocus();
    _typingDebounce?.cancel();
    _controller?.isActive = true;
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    if (!_formKey.currentState!.validate()) {
      _trigFail?.fire();
      return;
    }

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    setState(() => _isLoading = true);
    authAnimationLock.value = true;

    try {
      // 1. Crear usuario en Firebase Authentication
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);

        // 2. Guardar datos básicos en Cloud Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Despertar controlador y ejecutar animación de éxito del osito
      _isChecking?.change(false);
      _isHandsUp?.change(false);
      await Future.delayed(const Duration(milliseconds: 250));
      _controller?.isActive = true;
      _trigSuccess?.fire();

      await Future.delayed(const Duration(milliseconds: 2000));

      if (!mounted) return;
      // Volver a la raíz para que AuthGate muestre HomeScreen automáticamente
      Navigator.of(context).popUntil((route) => route.isFirst);
      authAnimationLock.value = false;
    } on FirebaseAuthException catch (e) {
      authAnimationLock.value = false;
      _trigFail?.fire();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapRegisterError(e)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      authAnimationLock.value = false;
      _trigFail?.fire();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Osito animado de Rive
                  SizedBox(
                    width: size.width,
                    height: 170,
                    child: RiveAnimation.asset(
                      'assets/login-bear.riv',
                      stateMachines: const ['Login Machine'],
                      onInit: (artboard) {
                        _controller = StateMachineController.fromArtboard(
                          artboard,
                          'Login Machine',
                        );
                        if (_controller == null) return;
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
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Nombre completo
                  TextFormField(
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                    onChanged: _onLookTextChanged,
                    validator: (val) {
                      if (val == null || val.trim().length < 3) {
                        return 'Ingresa tu nombre (mínimo 3 caracteres)';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Correo electrónico
                  TextFormField(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: _onLookTextChanged,
                    validator: (val) {
                      final email = val?.trim() ?? '';
                      final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!re.hasMatch(email)) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Contraseña segura
                  TextFormField(
                    controller: _passCtrl,
                    focusNode: _passFocus,
                    enabled: !_isLoading,
                    obscureText: _obscurePass,
                    onChanged: (_) {
                      _isChecking?.change(false);
                      _isHandsUp?.change(true);
                    },
                    validator: (val) {
                      if (val == null || !_isStrongPassword(val)) {
                        return 'Mín. 8 caracteres, 1 mayúscula, 1 minúscula, 1 número y 1 símbolo';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePass = !_obscurePass);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Confirmar contraseña
                  TextFormField(
                    controller: _confirmPassCtrl,
                    focusNode: _confirmPassFocus,
                    enabled: !_isLoading,
                    obscureText: _obscureConfirm,
                    onChanged: (_) {
                      _isChecking?.change(false);
                      _isHandsUp?.change(true);
                    },
                    validator: (val) {
                      if (val != _passCtrl.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botón de registro
                  MaterialButton(
                    minWidth: size.width,
                    height: 50,
                    color: Colors.pinkAccent,
                    disabledColor: Colors.pinkAccent.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onPressed: _isLoading ? null : _onRegister,
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
                            'Registrarse',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmPassFocus.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }
}