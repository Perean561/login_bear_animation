import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'dart:async'; //3.1 Importar el timer

class LoginScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  // Control para mostrar/ocultar contraseña
  bool _obscure = true;

  //1.1 Crear el cerebro de la animación
  StateMachineController? _controller;
  //SMI: State Machine Input / Entrada de máquina de estado
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;

  //3.2 Variable del recorrido de la mirada
  SMINumber? _numLook;

  //3.3 Timer para detener la mirada al dejar de escribir
  Timer? _typingDebounce;

  //2.1 Crear las variables para FocusNode
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  //2.2 Listeners (Oyentes/Chismosos)
  @override
  void initState(){
    super.initState();
    _emailFocus.addListener((){
      if (_emailFocus.hasFocus) {
        //Verificar que no sea nulo
        if (_isHandsUp != null) {
          //Manos abajo en el email
          _isHandsUp?.change(false);
          //3.4 Mirada neutra
          _numLook?.value = 50.0;
        }
      }
    });
    _passwordFocus.addListener(() {
      //Manos arriba en el password
      _isHandsUp?.change(_passwordFocus.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    //Para obtener el tamaño de la pantalla
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SizedBox(
                width: size.width,
                height: 200,
                child: RiveAnimation.asset(
                  'assets/login-bear.riv',
                  stateMachines: ['Login Machine'],
                  //1.2 Vincular animación
                  onInit: (artboard) {
                    _controller = StateMachineController.fromArtboard(
                      artboard,
                      'Login Machine',
                      );

                      //1,3 Verificar qie inició bien
                      if (_controller == null) return;
                      //Agrega el controlador al escenario/tablero
                      artboard.addController(_controller!);
                      //Vinculamos variables
                      _isChecking = _controller!.findSMI('isChecking');
                      _isHandsUp = _controller!.findSMI('isHandsUp');
                      _trigSuccess = _controller!.findSMI('trigSuccess');
                      _trigFail = _controller!.findSMI('trigFail');
                      //3.5 Vincular numLook
                      _numLook = _controller!.findSMI('numLook');
                  },
                  ),
              ),
              //Para separar espacio
              SizedBox(height: 10),
              // Campo de texto para Email
              TextField(
                focusNode: _emailFocus,
                onChanged: (value) {
                  if (_isHandsUp != null) {
                    //No tapes los ojos al ver email
                    // _isHandsUp!.change(false);
                  }
                  //Si isChecking es nulo
                  if (_isChecking == null) return;
                  //Activar el modo chismoso
                  _isChecking!.change(true);
                  //3.6 Implementar numLook
                  //Ajustes de limites del 0 al 100
                  //80 es la medida de calibración
                  final look = (value.length / 60.0 * 100.0).clamp(0.0, 100.0);
                  //Clamp es el rango (abrazadera)
                  _numLook?.value = look;

                  //3.7 Debounce:si vuelve a teclear, reinicia el contador
                  //Cancelar cualquier timer existente
                  _typingDebounce?.cancel();
                  //Crear un nuevo timer
                  _typingDebounce = Timer(const Duration(seconds: 3), (){
                    //Si se cierra la pantalla, quita el contador
                    if (!mounted) return;
                    //Mirada neutra
                    _isChecking?.change(false);
                  });

                },
                // Para mostrar el teclado
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    )
                ),
              ),
              // Campo de texto para contraseña
              SizedBox(height: 10),
              TextField(
                //2.3 Asignar foco al campo de texto
                focusNode: _passwordFocus,
                onChanged: (value) {
                  if (_isChecking != null) {
                    //No tapes los ojos al ver email
                    // _isChecking!.change(false);
                  }
                  //Si isChecking es nulo
                  if (_isHandsUp == null) return;
                  //Activar el modo chismoso
                  _isHandsUp!.change(true);
                },
                obscureText: _obscure,
                // Para mostrar el teclado
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      //Refrescar el ícono
                      setState(() {
                        _obscure = !_obscure;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    )
                ),
              ),
            ],
          ),
          ),
      ),
    );
  }
  void dispose() {
    //2.4 Liberar memoria de los FocusNode
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _typingDebounce?.cancel(); //3.9 Eliminar el timer
    super.dispose();
  }
}