import 'package:flutter/foundation.dart';

/// Evita que AuthGate cambie a HomeScreen antes de terminar Success en Rive.
final ValueNotifier<bool> authAnimationLock = ValueNotifier<bool>(false);
