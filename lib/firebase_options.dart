// Firebase options fed from --dart-define (no committed google-services.json /
// GoogleService-Info.plist), mirroring the driver app. A build without these
// defines leaves every field empty; main.dart guards on that and skips Firebase
// init entirely, so the app runs fine without push.
//
// Provide via env/*.json (--dart-define-from-file) once the Firebase project
// exists, e.g.:
//   "APP_ANDROID_FIREBASE_APP_ID": "1:...:android:...",
//   "APP_ANDROID_FIREBASE_API_KEY": "AIza...",
//   ...
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('APP_ANDROID_FIREBASE_API_KEY'),
    appId: String.fromEnvironment('APP_ANDROID_FIREBASE_APP_ID'),
    messagingSenderId:
        String.fromEnvironment('APP_ANDROID_FIREBASE_MSG_SENDER_ID'),
    projectId: String.fromEnvironment('APP_ANDROID_FIREBASE_PROJECT_ID'),
    storageBucket:
        String.fromEnvironment('APP_ANDROID_FIREBASE_STORAGE_BUCKET'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('APP_IOS_FIREBASE_API_KEY'),
    appId: String.fromEnvironment('APP_IOS_FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('APP_IOS_FIREBASE_MSG_SENDER_ID'),
    projectId: String.fromEnvironment('APP_IOS_FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('APP_IOS_FIREBASE_STORAGE_BUCKET'),
    iosBundleId: String.fromEnvironment('APP_IOS_FIREBASE_BUNDLE_ID'),
  );
}
