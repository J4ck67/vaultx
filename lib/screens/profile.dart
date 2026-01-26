import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/snacksbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late TextEditingController _nameController;
  bool editing = false;
  bool saving = false;

  static const amber = Color(0xFFFDD53F);

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: user?.displayName ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /*──────────────── UPDATE NAME ────────────────*/
  Future<void> _saveProfile() async {
    if (user == null) return;

    setState(() => saving = true);

    try {
      await user!.updateDisplayName(_nameController.text.trim());
      await user!.reload();

      setState(() => editing = false);
      showAnimatedSnackBar(context,message: "Profile updated");
    } catch (e) {
      showAnimatedSnackBar(context,message: "Failed to update profile");
      setState(() => editing = false);
    } finally {
      setState(() => saving = false);
    }
  }

  /*──────────────── LOGOUT ────────────────*/
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }




  /*──────────────── PROVIDER NAME ────────────────*/
  String _providerName() {
    if (user == null) return "Unknown";
    if (user!.isAnonymous) return "Guest";

    for (final p in user!.providerData) {
      if (p.providerId == "google.com") return "Google";
      if (p.providerId == "phone") return "Mobile OTP";
      if (p.providerId == "password") return "Email / Password";
    }
    return "Unknown";
  }

  /*──────────────── UI ────────────────*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [amber, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                /*──────── HEADER ────────*/
                Row(
                  children: const [
                    Text(
                      "Profile",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                /*──────── AVATAR ────────*/

                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                  ),
                  child: ClipOval(
                    child: user?.photoURL != null
                        ? Image.network(
                      user!.photoURL!,
                      fit: BoxFit.contain, // 🔥 KEY FIX
                    )
                        : const Icon(
                      Icons.person,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),


                const SizedBox(height: 16),

                /*──────── NAME ────────*/
                editing
                    ? TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: "Your name",
                    border: OutlineInputBorder(),
                  ),
                )
                    : Text(
                  user?.displayName ?? "VaultX User",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                /*──────── EMAIL / PHONE ────────*/
                Text(
                  user?.email ?? user?.phoneNumber ?? "No contact info",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 28),

                /*──────── INFO CARDS ────────*/
                _infoTile("Login Method", _providerName()),
                _infoTile("User ID", user?.uid.substring(0, 8) ?? "-"),
                _infoTile("Security", "End-to-End Encrypted"),

                const SizedBox(height: 32),

                /*──────── ACTION BUTTONS ────────*/
                if (!editing)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => setState(() => editing = true),
                      child: const Text("Edit Profile"),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: saving ? null : _saveProfile,
                      child: saving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text("Save"),
                    ),
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _logout,
                    child: const Text("Logout"),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

      ),
    );
  }

  /*──────────────── INFO TILE ────────────────*/
  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
