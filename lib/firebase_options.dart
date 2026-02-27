// firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Default [FirebaseOptions] 
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_WEB'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_WEB'] ?? '',
        messagingSenderId: '932043130642',
        projectId: 'ao-gosto-app-c0b31',
        authDomain: 'ao-gosto-app-c0b31.firebaseapp.com',
        storageBucket: 'ao-gosto-app-c0b31.firebasestorage.app',
        measurementId: 'G-VKQBFM2WER',
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_ANDROID'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_ANDROID'] ?? '',
        messagingSenderId: '932043130642',
        projectId: 'ao-gosto-app-c0b31',
        storageBucket: 'ao-gosto-app-c0b31.firebasestorage.app',
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_IOS'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_IOS'] ?? '',
        messagingSenderId: '932043130642',
        projectId: 'ao-gosto-app-c0b31',
        storageBucket: 'ao-gosto-app-c0b31.firebasestorage.app',
        iosBundleId: 'com.example.entregador',
      );

  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_MACOS'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_MACOS'] ?? '',
        messagingSenderId: '932043130642',
        projectId: 'ao-gosto-app-c0b31',
        storageBucket: 'ao-gosto-app-c0b31.firebasestorage.app',
        iosBundleId: 'com.example.entregador',
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY_WINDOWS'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID_WINDOWS'] ?? '',
        messagingSenderId: '932043130642',
        projectId: 'ao-gosto-app-c0b31',
        authDomain: 'ao-gosto-app-c0b31.firebaseapp.com',
        storageBucket: 'ao-gosto-app-c0b31.firebasestorage.app',
        measurementId: 'G-M6CJ0WQPQP',
      );
}