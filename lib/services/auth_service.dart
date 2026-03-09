import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart'; // 👈 NEW IMPORT
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart'; // 👈 NEW IMPORT

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keep one instance of GoogleSignIn
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // 🔴 IMPORTANT: We added the Gmail scope here.
    // This allows the app to ask for "Read-only" permission to emails.
    scopes: [
      'email',
      'profile',
      GmailApi.gmailReadonlyScope,
    ],
  );

  // ───────── GOOGLE LOGIN ─────────
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Sign out of existing session to ensure account picker shows up
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User simply closed the popup
        return null;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // 2. Sign in to Firebase
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  // ───────── GMAIL API CLIENT ─────────
  // 🔵 NEW: This method is called by your GmailService to get access
  Future<GmailApi?> getGmailApiClient() async {
    try {
      // Ensure user is signed in (silently check first)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();

      if (googleUser == null) return null;

      // Create an authenticated HTTP client for Gmail API
      final httpClient = await _googleSignIn.authenticatedClient();

      if (httpClient == null) return null;

      return GmailApi(httpClient);
    } catch (e) {
      print("Gmail API Client Error: $e");
      return null;
    }
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
    } catch (e) {
      onError("OTP request failed: $e");
    }
  }

  // ───────── VERIFY OTP ─────────
  Future<User?> verifyOtp({required String smsCode}) async {
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
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Logout Error: $e");
    }
  }
}