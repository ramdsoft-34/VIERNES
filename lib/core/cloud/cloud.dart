import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Verdadero si Firebase quedó configurado (existe
/// `android/app/google-services.json`). Se define en el arranque.
final cloudAvailableProvider = Provider<bool>((ref) => false);

/// Inicia Firebase. Sin configuración la app sigue funcionando sin cuentas.
Future<bool> initializeCloud() async {
  try {
    await Firebase.initializeApp();
    // La base local ya guarda todo sin internet: Firestore no necesita otra
    // copia en el teléfono (y así no quedan datos al cerrar sesión).
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    return true;
  } on Object catch (error) {
    AppLogger.info(
      'Cuentas desactivadas: Firebase no está configurado ($error). '
      'Ver docs/CUENTAS.md',
    );
    return false;
  }
}

/// El error se debe a la falta de conexión (se reintenta más tarde).
bool isOfflineError(Object error) =>
    error is TimeoutException ||
    (error is FirebaseException &&
        const {
          'unavailable',
          'network-request-failed',
          'deadline-exceeded',
        }.contains(error.code));
