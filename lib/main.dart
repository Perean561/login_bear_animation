import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:login_bear_animation/auth_animation_lock.dart';

// Conserva el acceso al notifier para cualquier archivo antiguo que
// todavía lo importe desde main.dart.
export 'package:login_bear_animation/auth_animation_lock.dart'
    show authAnimationLock;
import 'package:login_bear_animation/firebase_options.dart';
import 'package:login_bear_animation/screens/home_screen.dart';
import 'package:login_bear_animation/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseConnected = false;
  String connectionMessage = '';

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    firebaseConnected = true;
    connectionMessage =
        'Firebase conectado (${Firebase.app().options.projectId})';
    debugPrint('ÉXITO FASE 1: $connectionMessage');
  } catch (e, stackTrace) {
    connectionMessage = 'Error al conectar con Firebase: $e';
    debugPrint('ERROR FASE 1: $connectionMessage');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(
    MyApp(
      firebaseConnected: firebaseConnected,
      connectionMessage: connectionMessage,
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool firebaseConnected;
  final String connectionMessage;

  const MyApp({
    super.key,
    required this.firebaseConnected,
    required this.connectionMessage,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rive Animated Login',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AuthGate(
        firebaseConnected: firebaseConnected,
        connectionMessage: connectionMessage,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final bool firebaseConnected;
  final String connectionMessage;

  const AuthGate({
    super.key,
    required this.firebaseConnected,
    required this.connectionMessage,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseConnected) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  widget.connectionMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: authAnimationLock,
          builder: (context, isAnimatingSuccess, _) {
            if (snapshot.hasData && !isAnimatingSuccess) {
              return const HomeScreen();
            }

            return LoginScreen(
              connectionStatus: widget.connectionMessage,
            );
          },
        );
      },
    );
  }
}
