import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vaultx/screens/profile.dart';

import '../services/file_view_service.dart';
import '../widgets/upload_bill.dart';
import 'document_preview_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = "Electricity";

  final categories = [
    "Electricity",
    "Rent",
    "Internet",
    "Insurance",
    "Subscription",
    "Other",
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
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                /*──────── HEADER ────────*/
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
                        color: Colors.blueAccent,
                      ),
                    ),
                    const Spacer(),

                    /// PROFILE → NAVIGATE TO PROFILE SCREEN
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? const Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.white,
                        )
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                /*──────── TOTAL DUE ────────*/
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

                /*──────── UPCOMING ────────*/
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

                /*──────── CATEGORIES ────────*/
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
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selected
                              ? Colors.amber
                              : Colors.white,
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.black
                                : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                /*──────── RECENT DOCS ────────*/
                const Text(
                  "Recent Documents",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),


        StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('documents')
            .where('category', isEqualTo: selectedCategory)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "No documents yet",
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          return Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () async {
                  final storagePath = data['storagePath'];
                  final originalName = data['originalName'];

                  if (storagePath == null || originalName == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Invalid document data")),
                    );
                    return;
                  }

                  // Loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final file = await FileViewService.downloadAndDecrypt(
                      storagePath: storagePath,
                      originalName: originalName,
                    );

                    if (!mounted) return;
                    Navigator.pop(context); // close loader

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentPreviewScreen(file: file),
                      ),
                    );
                  } catch (e) {
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to open document")),
                    );
                  }
                },
                child: Container(
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
                      const Icon(Icons.lock, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['originalName'] ?? 'Encrypted file',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((data['amount'] ?? "").isNotEmpty)
                              Text(
                                "Amount: ${data['amount']}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            if ((data['dueDate'] ?? "").isNotEmpty)
                              Text(
                                "Due: ${data['dueDate']}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.red),
                              ),
                          ],
                        ),
                      ),

                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );

            }).toList(),
          );
        },
      ),



      const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
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
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UploadBillButton(),
          ),
        );
      },
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
