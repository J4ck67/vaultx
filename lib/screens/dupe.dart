import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/upload_bill.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = "Utilities";

  final categories = ["Utilities", "Subscriptions", "Insurance", "Taxes"];

  final recentDocs = [
    {"name": "Electric Bill.pdf", "date": "12 Aug"},
    {"name": "Rent Receipt.pdf", "date": "10 Aug"},
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      floatingActionButton: const _UploadButton(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDD53F),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                /// HEADER + PROFILE
                Row(
                  children: [
                    const Text(
                      "Vault",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      "X",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const Spacer(),

                    /// PROFILE AVATAR
                    GestureDetector(
                      onTap: () => _showProfileSheet(context),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? const Icon(Icons.person,
                            size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                /// TOTAL DUE CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black,
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Due This Month",
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "₹1,240",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                /// UPCOMING
                const Text(
                  "Upcoming",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 130,
                  child: PageView(
                    controller: PageController(viewportFraction: 0.9),
                    children: const [
                      _UpcomingCard(
                        title: "Electric Bill",
                        amount: "₹95",
                        days: 3,
                      ),
                      _UpcomingCard(
                        title: "Rent",
                        amount: "₹1,000",
                        days: 5,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                /// ANALYTICS
                const Text(
                  "Monthly Spend",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                Container(
                  height: 100,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [0.4, 0.8, 0.6, 1.0, 0.7]
                        .map(
                          (v) => Expanded(
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            height: 80 * v,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ),

                const SizedBox(height: 28),

                /// CATEGORIES
                const Text(
                  "Categories",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  children: categories.map((c) {
                    final selected = c == selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selected
                              ? Colors.amber.withOpacity(0.3)
                              : Colors.white,
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                            selected ? Colors.black : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                /// RECENT DOCUMENTS
                const Text(
                  "Recent Documents",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                ...recentDocs.map(
                      (doc) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file,
                            color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            doc["name"]!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          doc["date"]!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*──────────────── PROFILE SHEET ────────────────*/

  void _showProfileSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.black,
              backgroundImage:
              user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person,
                  size: 36, color: Colors.white)
                  : null,
            ),

            const SizedBox(height: 12),

            Text(
              user?.displayName ?? "VaultX User",
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 4),

            Text(
              user?.email ?? user?.phoneNumber ?? "Guest account",
              style: const TextStyle(color: Colors.black54),
            ),

            const SizedBox(height: 20),

            _profileRow("Login Method", _providerName(user)),
            _profileRow("Security", "End-to-End Encrypted"),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pop(context);
                },
                child: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _providerName(User? user) {
    if (user == null) return "Unknown";
    if (user.isAnonymous) return "Guest";

    for (final p in user.providerData) {
      if (p.providerId == "google.com") return "Google";
      if (p.providerId == "phone") return "Mobile OTP";
    }
    return "Email";
  }
}

/*──────────────── UPCOMING CARD ────────────────*/

class _UpcomingCard extends StatelessWidget {
  final String title;
  final String amount;
  final int days;

  const _UpcomingCard({
    required this.title,
    required this.amount,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style:
                    const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: days <= 3
                        ? Colors.red.withOpacity(0.15)
                        : Colors.amber.withOpacity(0.2),
                  ),
                  child: Text(
                    "$days days left",
                    style: TextStyle(
                      fontSize: 12,
                      color: days <= 3 ? Colors.red : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*──────────────── UPLOAD BUTTON ────────────────*/

class _UploadButton extends StatelessWidget {
  const _UploadButton();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.black,
      onPressed: () {Navigator.push(context, MaterialPageRoute(builder: (_) => UploadBillButton()));},
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
