import 'dart:async';
import 'package:firebase_core/firebase_core.dart';

String friendlyError(Object error) {
  if (error is TimeoutException) {
    return 'The server has not replied. Check your connection and refresh before retrying.';
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'email-already-in-use' =>
        'This email already has an account. Sign in instead.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'weak-password' => 'Use a stronger password with at least 8 characters.',
      'network-request-failed' ||
      'unavailable' => 'Cannot reach the server. Check your connection.',
      'permission-denied' || 'unauthorized' =>
        'Access was denied. Check your campus account or contact the project team.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'operation-not-allowed' =>
        'Email/password sign-in is not enabled in Firebase.',
      'failed-precondition' =>
        'The database needs configuration. Contact the project team.',
      'quota-exceeded' => 'Storage capacity is temporarily unavailable.',
      _ => 'The operation failed (${error.code}). Please try again.',
    };
  }
  if (error is StateError) return error.message;
  if (error is ArgumentError) return '${error.message}';
  return 'Something went wrong. Please try again.';
}
