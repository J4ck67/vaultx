import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ───────── GOOGLE ─────────
  GoogleSignIn _google() => GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<User?> signInWithGoogle() async {
    final googleSignIn = _google();

    try {
      await googleSignIn.signOut();
      await googleSignIn.disconnect();
    } catch (_) {}

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  // ───────── PHONE OTP STATE ─────────
  String? _verificationId;
  int? _resendToken;

  String get verificationId {
    if (_verificationId == null) {
      throw Exception("OTP session expired. Request OTP again.");
    }
    return _verificationId!;
  }

  // ───────── SEND / RESEND OTP ─────────
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,

        // ❌ DO NOT AUTO LOGIN
        verificationCompleted: (_) {},

        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "OTP verification failed");
        },

        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (_) {
      onError("OTP request failed");
    }
  }

  // ───────── VERIFY OTP ─────────
  Future<User?> verifyOtp({
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  // ───────── LOGOUT ─────────
  Future<void> logout() async {
    try {
      await _google().signOut();
      await _google().disconnect();
    } catch (_) {}

    await _auth.signOut();
  }
}
