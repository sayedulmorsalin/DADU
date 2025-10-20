import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Auth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Email/Password Registration
  Future<String?> registerWithEmailAndPassword(
      String email, String password, String name) async {
    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Store additional user info in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e.code);
    } catch (e) {
      return "Registration failed: $e";
    }
  }


// Email/Password Login
  Future<String?> loginWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Update last login timestamp in user document
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e.code);
    } catch (e) {
      return "Login failed: $e";
    }
  }


  // Forgot Password
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e.code);
    } catch (e) {
      return "Password reset failed: $e";
    }
  }

  // Change Password (requires recent login)
  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return "User not logged in";

      // Reauthenticate before changing password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e.code);
    } catch (e) {
      return "Password change failed: $e";
    }
  }

  // Anonymous Login (existing method)
  Future<void> anonymousLogin() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;

      if (user != null) {
        final userDoc = _firestore.collection('anonymous_users').doc(user.uid);

        // Create or update anonymous user with last login
        await userDoc.set({
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print("Anonymous user: ${user.uid}");
      }
    } catch (e) {
      print("Anonymous login failed: $e");
    }
  }


  // Helper to handle auth error codes
  String _handleAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Enter a valid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found for this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'operation-not-allowed':
        return 'Email/password accounts are disabled';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'requires-recent-login':
        return 'Reauthenticate before changing password';
      default:
        return 'Authentication failed: $code';
    }
  }

  Future<void> createUserProfile({
    required String name,
    required String phone,
    String? profilePicUrl,
    required String? district,
    required String? thana,
    required String address,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final userData = {
      'email': user.email,
      'name': name,
      'phone': phone,
      'profile_pic': profilePicUrl,
      'district': district,
      'thana': thana,
      'address': address,
      'free_delivery_info': 0,
      'free_delivery_status': false,
      'cart_items': [],
      'to_verify': [],
      'to_ship': [],
      'to_receive': [],
      'completed': [],
      'last_updated': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(user.uid).set(userData, SetOptions(merge: true));
  }

  // Add to your Auth class
  Future<void> updateLastLogin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final timestamp = FieldValue.serverTimestamp();
    final userData = {'lastLogin': timestamp};

    if (user.isAnonymous) {
      await _firestore.collection('anonymous_users').doc(user.uid).update(userData);
    } else {
      await _firestore.collection('users').doc(user.uid).update(userData);
    }
  }


  // Additional helper methods
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Future<void> signOut() async => await _auth.signOut();
}