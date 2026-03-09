
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vaultx/screens/profile.dart';
import '../services/file_view_service.dart';
import '../services/gmail_service.dart';
import '../widgets/upload_bill.dart';
import 'document_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = "Electricity";
  bool isScanning = false;

  final categories = [
    "Electricity",
    "Rent",
    "Internet",
    "Insurance",
    "Subscription",
    "Other",
  ];

  /* ──────── GMAIL INTEGRATION LOGIC ──────── */
  Future<void> _scanGmailForBills() async {
    setState(() => isScanning = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final gmailService = GmailService();
      List<BillMetadata> bills = await gmailService.fetchRecentBills();

      if (bills.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No PDF bills found in Gmail.")));
        }
        setState(() => isScanning = false);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      int addedCount = 0; // Track how many are actually NEW

      // Process all bills in parallel
      List<Future<void>> uploadTasks = bills.map((bill) async {

        // 🔴 1. DUPLICATE CHECK: Use the Gmail ID as the Firestore Doc ID
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('documents')
            .doc(bill.id); // 👈 We use bill.id instead of .doc()

        final docSnap = await docRef.get();
        if (docSnap.exists) {
          debugPrint("⏭️ Skipping duplicate: ${bill.subject}");
          return; // It exists! Exit this specific task early.
        }

        // 🟢 2. IT IS NEW: Proceed with upload
        String detectedCategory = _detectCategory(bill.subject);

        // Use the Gmail ID in the file name to prevent Storage overwrites too
        final String fileName = "${bill.id}_${bill.filename}";
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('uploads/${user.uid}/$detectedCategory/$fileName');

        final uploadTask = await storageRef.putData(
            bill.fileBytes,
            SettableMetadata(contentType: 'application/pdf')
        );

        final downloadUrl = await uploadTask.ref.getDownloadURL();

        batch.set(docRef, {
          'originalName': bill.subject,
          'biller': 'Gmail Import',
          'category': detectedCategory,
          'amount': 0.00,
          'dueDate': FieldValue.serverTimestamp(),
          'fileType': 'pdf',
          'fileUrl': downloadUrl,
          'storagePath': storageRef.fullPath,
          'createdAt': FieldValue.serverTimestamp(),
          'isEncrypted': false,
        });

        addedCount++; // Increment our "New Files" counter
      }).toList();

      // Wait for all checks and uploads to finish
      await Future.wait(uploadTasks);

      // Only commit to Firestore if we actually found new documents
      if (addedCount > 0) {
        await batch.commit();
      }

      // Show appropriate success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(addedCount > 0
                  ? "🚀 Imported $addedCount new bills!"
                  : "✔️ Everything is up to date (No new bills)."),
              backgroundColor: addedCount > 0 ? Colors.green : Colors.blueAccent
          ),
        );
      }

    } catch (e) {
      debugPrint("Scan Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isScanning = false);
    }
  }

  // 🧠 SMART CATEGORIZER
  String _detectCategory(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('Insurance') || s.contains('policy') || s.contains('premium')) return "Insurance";
    if (s.contains('subscription') || s.contains('tickets') || s.contains('your tickets') || s.contains('prime')) return "Subscription";
    if (s.contains('electricity') || s.contains('power') || s.contains('bill')) return "Electricity";
    if (s.contains('e-account') || s.contains('banking') || s.contains('rent')) return "Rent";
    if (s.contains('internet') || s.contains('wifi') || s.contains('broadband')) return "Internet";
    return "Other";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      // 🟢 Added the Floating Action Button back here.
      // By default, it aligns to the bottom right.
      floatingActionButton: const _UploadButton(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDD53F), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /*──────── 1. HEADER ────────*/
                Row(
                  children: [
                    const Icon(Icons.security_sharp, color: Colors.black, size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      "Vault",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      "X",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent),
                    ),
                    const Spacer(),

                    // GMAIL SYNC BUTTON
                    if (isScanning)
                      const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.sync, color: Colors.black),
                        tooltip: "Scan bills from Gmail",
                        onPressed: _scanGmailForBills,
                      ),

                    const SizedBox(width: 8),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black,
                          backgroundImage: user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? const Icon(Icons.person,
                              size: 18, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                /*──────── 2. PROFILE & TOTAL DUE CARD ────────*/
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A1A), Color(0xFF333333)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName ?? "User",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.lock,
                                        size: 12, color: Colors.black),
                                    SizedBox(width: 4),
                                    Text(
                                      "Vault Secured",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.shield,
                              color: Colors.white24, size: 40),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Total Due",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "₹12,450.00",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Across all upcoming bills",
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                /*──────── 3. UPCOMING BILLS ────────*/
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      "Upcoming Bills",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildUpcomingBillCard("Rent", "₹8,500", "2 days left",
                          Icons.home, true),
                      const SizedBox(width: 12),
                      _buildUpcomingBillCard("Internet", "₹1,200", "5 days left",
                          Icons.wifi, false),
                      const SizedBox(width: 12),
                      _buildUpcomingBillCard("Power", "₹2,400", "12 days left",
                          Icons.bolt, false),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                /*──────── 4. CATEGORIES ────────*/
                const Text(
                  "Recent Documents",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: 10,
                    children: categories.map((c) {
                      final selected = c == selectedCategory;
                      return GestureDetector(
                        onTap: () => setState(() => selectedCategory = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: selected ? Colors.black : Colors.white,
                            border: Border.all(
                                color: selected ? Colors.black : Colors.black12),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                /*──────── 5. RECENT DOCUMENTS LIST ────────*/
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('documents')
                      .where('category', isEqualTo: selectedCategory)
                      .orderBy('createdAt', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.folder_open,
                                size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text(
                              "No $selectedCategory documents",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildDocumentTile(context, data);
                      },
                    );
                  },
                ),

                const SizedBox(height: 120), // 🟢 Increased spacing at the bottom so documents aren't hidden
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────── HELPER WIDGETS ────────

  Widget _buildUpcomingBillCard(String title, String amount, String days,
      IconData icon, bool isUrgent) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFE74C3C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 20, color: isUrgent ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: isUrgent ? Colors.white70 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              color: isUrgent ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.white.withOpacity(0.2)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              days,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isUrgent ? Colors.white : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(BuildContext context, Map<String, dynamic> data) {
    double? amount;
    if (data['amount'] is num) {
      amount = data['amount'].toDouble();
    } else if (data['amount'] is String) {
      amount = double.tryParse(data['amount']);
    }

    String? formattedDueDate;
    if (data['dueDate'] is Timestamp) {
      final date = (data['dueDate'] as Timestamp).toDate();
      formattedDueDate = "${date.day}/${date.month}/${date.year}";
    }

    return GestureDetector(
      onTap: () async {
        final storagePath = data['storagePath'];
        final originalName = data['originalName'];

        if (storagePath == null || originalName == null) return;

        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()));

        try {
          // 🚀 UPDATED: USING downloadFile (No Decryption)
          final file = await FileViewService.downloadFile(
              storagePath: storagePath,
              originalName: originalName
          );

          if (!mounted) return;
          Navigator.pop(context);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DocumentPreviewScreen(file: file)));
        } catch (e) {
          debugPrint("❌ Open Error: $e"); // View this in your Debug Console
          if (mounted) {
            Navigator.pop(context); // Close loading spinner
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error: ${e.toString()}"), // Show real error
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description, color: Colors.amber),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['originalName'] ?? 'Document',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (data['biller'] != null)
                        Text(
                          "${data['biller']} • ",
                          style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      Text(
                        formattedDueDate ?? "No due date",
                        style: TextStyle(
                            fontSize: 12,
                            color: formattedDueDate != null
                                ? Colors.redAccent
                                : Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (amount != null && amount > 0)
              Text(
                "₹${amount.toStringAsFixed(0)}",
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────── NEW UPLOAD BUTTON ────────
class _UploadButton extends StatelessWidget {
  const _UploadButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 🟢 This padding is critical! It pushes the FAB up so it sits
      // nicely above your floating bottom navigation bar.
      padding: const EdgeInsets.only(bottom: 100.0),
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Colors.black, Color(0xFF333333)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadBillButton()),
            );
          },
          backgroundColor: Colors.transparent, // Ensures the gradient shows through
          elevation: 0, // Handled by our Container's shadow instead
          highlightElevation: 0,
          child: const Icon(
            Icons.add_rounded,
            color: Color(0xFFFDD53F), // VaultX Amber
            size: 32,
          ),
        ),
      ),
    );
  }
}