// firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      case TargetPlatform.macOS: return macos;
      case TargetPlatform.windows: return windows;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // Atalhos para as variáveis repetidas
  static String get _projId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get _senderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get _bucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_WEB'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_WEB'] ?? '',
        messagingSenderId: _senderId,
        projectId: _projId,
        authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN_WEB'] ?? '',
        storageBucket: _bucket,
        measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID_WEB'] ?? '',
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_ANDROID'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_ANDROID'] ?? '',
        messagingSenderId: _senderId,
        projectId: _projId,
        storageBucket: _bucket,
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_IOS'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_IOS'] ?? '',
        messagingSenderId: _senderId,
        projectId: _projId,
        storageBucket: _bucket,
        iosBundleId: dotenv.env['FIREBASE_IOS_BUNDLE_ID'] ?? '',
      );

  static FirebaseOptions get macos => ios;

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_WINDOWS'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_WINDOWS'] ?? '',
        messagingSenderId: _senderId,
        projectId: _projId,
        authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN_WEB'] ?? '',
        storageBucket: _bucket,
        measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID_WINDOWS'] ?? '',
      );
}