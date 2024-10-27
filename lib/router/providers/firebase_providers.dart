// Uncomment the code below to use signInWithGoogle

// import 'dart:developer';
//
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/services.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';
//
// part 'firebase_providers.g.dart';
//
// @Riverpod(keepAlive: true)
// FirebaseAuth firebaseAuth(FirebaseAuthRef ref) => FirebaseAuth.instance;
//
// @Riverpod(keepAlive: true)
// GoogleSignIn googleSignIn(GoogleSignInRef ref) => GoogleSignIn();
//
// @Riverpod(keepAlive: true)
// User? user(UserRef ref) => null;
//
// @Riverpod(keepAlive: true)
// class UserNotifier extends _$UserNotifier {
//   @override
//   User? build() => null;
//
//   Future<User?> signInWithGoogle() async {
//     try {
//       final GoogleSignIn googleSignIn = ref.watch(googleSignInProvider);
//       final FirebaseAuth auth = ref.watch(firebaseAuthProvider);
//       final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
//
//       if (googleUser == null) {
//         log('User canceled the sign-in', name: '🔑 Login');
//         return null; // the user canceled the sign-in
//       }
//       final GoogleSignInAuthentication googleAuth =
//       await googleUser.authentication;
//
//       final AuthCredential credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );
//
//       final UserCredential userCredential =
//       await auth.signInWithCredential(credential);
//
//       log('User signed in: ${userCredential.user}', name: '🔑 Login');
//
//       state = userCredential.user;
//
//       return userCredential.user;
//     } catch (e) {
//       log(e.toString(), name: '🔥 Login');
//       log((e as PlatformException).message.toString(), name: '🔥 Login');
//       log(e.details.toString(), name: '🔥 Login');
//       log(e.stacktrace.toString(), name: '🔥 Login');
//       return null;
//     }
//   }
// }
