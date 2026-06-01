// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError('Linux non configuré.');
      default:
        throw UnsupportedError('Plateforme non supportée.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBuq3Fr38InPJYsmqSqSYBUQgJ5WKATwMo',
    appId: '1:393652728000:android:023ec5c2ba83176486fd25',
    messagingSenderId: '393652728000',
    projectId: 'appzad',
    storageBucket: 'appzad.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBuq3Fr38InPJYsmqSqSYBUQgJ5WKATwMo',
    appId: '1:393652728000:web:3347140345f280cc86fd25',
    messagingSenderId: '393652728000',
    projectId: 'appzad',
    authDomain: 'appzad.firebaseapp.com',
    storageBucket: 'appzad.firebasestorage.app',
    measurementId: 'G-EYCRCX1P1M',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCrxDkN4jGMlYtz2tO-iajzXu_oQA0xeDg',
    appId: '1:393652728000:ios:3ad0fb5a38d1af0f86fd25',
    messagingSenderId: '393652728000',
    projectId: 'appzad',
    storageBucket: 'appzad.firebasestorage.app',
    iosBundleId: 'com.example.a',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCrxDkN4jGMlYtz2tO-iajzXu_oQA0xeDg',
    appId: '1:393652728000:ios:3ad0fb5a38d1af0f86fd25',
    messagingSenderId: '393652728000',
    projectId: 'appzad',
    storageBucket: 'appzad.firebasestorage.app',
    iosBundleId: 'com.example.a',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBuq3Fr38InPJYsmqSqSYBUQgJ5WKATwMo',
    appId: '1:393652728000:web:e395a396e824974286fd25',
    messagingSenderId: '393652728000',
    projectId: 'appzad',
    authDomain: 'appzad.firebaseapp.com',
    storageBucket: 'appzad.firebasestorage.app',
    measurementId: 'G-S5DE6TEWG7',
  );
}