import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../services/file_view_service.dart';
import '../services/sms_service.dart';
import '../services/gmail_service.dart';
import '../services/notification_service.dart';
import 'document_preview_screen.dart';

// 🟢 NEW: Unified structure to combine Gmail and SMS alerts in the UI
class UnifiedAlert {
  final String id; 
  final String title;
  final String subtitle;
  final String? dateStr;
  final double? amount;
  final bool isWarning; // e.g. red for bill, orange for recharge

  UnifiedAlert({
    required this.id,
    required this.title,
    required this.subtitle,
    this.dateStr,
    this.amount,
    this.isWarning = false,
  });
}

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  String selectedCategory = "All";
  String searchQuery = "";

  late Future<List<UnifiedAlert>> _alertsFuture;

  final categories = [
    "All",
    "Electricity",
    "Rent",
    "Internet",
    "Insurance",
    "Subscription",
    "Other",
  ];

  static const Color vaultAmber = Color(0xFFFDD53F);

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _alertsFuture = _fetchAndScheduleAlerts();
  }

  Future<void> _initNotifications() async {
    await NotificationService().requestPermissions();
  }

  // ──────── 🟢 NEW: CONSOLIDATED ALERTS PIPELINE ────────
  Future<List<UnifiedAlert>> _fetchAndScheduleAlerts() async {
    List<UnifiedAlert> unifiedList = [];
    
    // 1. Fetch from SMS
    try {
      final smsList = await SmsService.fetchFinancialSms();
      for (var sms in smsList) {
        unifiedList.add(UnifiedAlert(
          id: 'sms_${sms.id}',
          title: sms.sender.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
          subtitle: sms.isRecharge ? "Expiring Soon" : "Payment Due",
          dateStr: sms.extractedDate,
          amount: sms.amount,
          isWarning: !sms.isRecharge,
        ));
      }
    } catch (e) {
      debugPrint("SMS Fetch Error: $e");
    }

    // 2. Fetch from Gmail Text
    try {
      final gmailAlerts = await GmailService().fetchTextAlerts();
      for (var email in gmailAlerts) {
        unifiedList.add(UnifiedAlert(
          id: 'gmail_${email.id}',
          title: "Gmail Alert",
          subtitle: email.subject,
          dateStr: email.extractedDate,
          amount: null, // Harder to reliably extract amount from pure emails without LLM
          isWarning: true,
        ));
      }
    } catch (e) {
      debugPrint("Gmail Fetch Error: $e");
    }

    // 3. Smart Scheduling!
    for (var alert in unifiedList) {
      if (alert.dateStr != null) {
        _attemptToSchedulePush(alert);
      }
    }

    return unifiedList;
  }

  // Parses the loose date strings and schedules Native device Push notifications
  void _attemptToSchedulePush(UnifiedAlert alert) {
    try {
      // Very basic date parsing - assumes dd/mm/yyyy or dd-mm-yyyy for now
      // A more robust implementation would use intl DateFormat extensively
      final parts = alert.dateStr!.split(RegExp(r'[-/ \.]'));
      if (parts.length >= 3) {
        int day = int.tryParse(parts[0]) ?? 1;
        int month = parts[1].length > 2 ? _parseMonth(parts[1]) : int.tryParse(parts[1]) ?? 1;
        int year = int.tryParse(parts[2]) ?? DateTime.now().year;
        if (year < 100) year += 2000;

        // Schedule it for 9:00 AM on the extracted date
        DateTime targetDate = DateTime(year, month, day, 9, 0);

        // If it's strictly in the future, push to OS!
        if (targetDate.isAfter(DateTime.now())) {
            NotificationService().scheduleReminder(
              id: alert.id.hashCode,
              title: alert.title,
              body: "${alert.subtitle} on ${alert.dateStr}!",
              scheduledTime: targetDate,
            );
        }
      }
    } catch (e) {
      debugPrint("Failed to parse/schedule date for ${alert.title}");
    }
  }

  int _parseMonth(String m) {
    final Map<String, int> months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    return months[m.toLowerCase().substring(0, 3)] ?? 1;
  }

  // ──────── 🟢 NEW: HIDE SMS ALERT LOGIC ────────
  Future<void> _dismissSmsAlert(String alertId) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.visibility_off_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Dismiss Alert?"),
          ],
        ),
        content: const Text(
          "This will hide the alert from VaultX. (It will not delete the actual message from your phone).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text("Dismiss"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Save the hidden Alert ID to the user's profile
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'hidden_alerts': FieldValue.arrayUnion([alertId])
      }, SetOptions(merge: true));

      // Refresh the local UI fetch
      setState(() {
        _alertsFuture = _fetchAndScheduleAlerts();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alert dismissed."), backgroundColor: Colors.black87),
      );
    } catch (e) {
      debugPrint("Error hiding alert: $e");
    }
  }

  // ──────── DELETION LOGIC (Documents) ────────
  Future<void> _deleteDocument(String docId, String? storagePath) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Document?"),
          ],
        ),
        content: const Text("This will permanently remove the file from your vault. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          final storageRef = FirebaseStorage.instance.ref(storagePath);
          await storageRef.delete();
        } catch (e) {
          debugPrint("Storage delete error: $e");
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .doc(docId)
          .delete();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Document deleted successfully."), backgroundColor: Colors.black87),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('documents')
        .orderBy('createdAt', descending: true);

    if (selectedCategory != "All") {
      query = query.where('category', isEqualTo: selectedCategory);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDD53F), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /*──────── 1. HEADER & SEARCH ────────*/
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_copy_rounded, size: 28, color: Colors.black),
                        const SizedBox(width: 10),
                        const Text(
                          "My Vault",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Secure",
                            style: TextStyle(color: vaultAmber, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                          hintText: "Search your documents...",
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              /*──────── 3. CATEGORY PILLS ────────*/
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    final isSelected = c == selectedCategory;

                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.white,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            color: isSelected ? vaultAmber : Colors.black87,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),


              /*──────── 2. 🟢 UNIFIED ALERTS CAROUSEL 🟢 ────────*/
              StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                  builder: (context, userSnapshot) {
                    
                    List<dynamic> hiddenAlerts = [];
                    if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      hiddenAlerts = userData['hidden_alerts'] ?? []; // Migrate to generic hidden array
                    }

                    return FutureBuilder<List<UnifiedAlert>>(
                      future: _alertsFuture,
                      builder: (context, alertSnapshot) {
                        if (alertSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }

                        if (!alertSnapshot.hasData || alertSnapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        // 🟢 FILTER OUT THE HIDDEN MESSAGES
                        final visibleAlerts = alertSnapshot.data!
                            .where((alert) => !hiddenAlerts.contains(alert.id))
                            .toList();

                        if (visibleAlerts.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Text(
                                "Smart Inbox Alerts",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                            SizedBox(
                              height: 130, // Prevents the overflow error
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: visibleAlerts.length,
                                itemBuilder: (context, index) {
                                  return _buildAlertCard(visibleAlerts[index]);
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  }
              ),



              /*──────── 4. DOCUMENT GRID (TILES) ────────*/
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.black));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    var docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['originalName'] ?? '').toString().toLowerCase();
                      return name.contains(searchQuery);
                    }).toList();

                    if (docs.isEmpty) {
                      return _buildEmptyState(isSearch: true);
                    }

                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildGridTile(context, doc.id, data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────── HELPER WIDGETS ────────

  // ──────── HELPER WIDGETS ────────

  Widget _buildAlertCard(UnifiedAlert alert) {
    final Color themeColor = !alert.isWarning ? Colors.orange : Colors.redAccent;
    final IconData icon = alert.id.startsWith('gmail') ? Icons.email_rounded : Icons.sim_card_rounded;

    // 🟢 WRAPPED IN GESTURE DETECTOR TO LISTEN FOR LONG PRESS
    return GestureDetector(
      onLongPress: () => _dismissSmsAlert(alert.id),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: themeColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    alert.subtitle,
                    style: TextStyle(fontSize: 9, color: themeColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const Spacer(),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Alert Trigger",
                      style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600),
                    ),
                    Text(
                      alert.amount != null ? "₹${alert.amount!.toStringAsFixed(0)}" : "Check Inbox",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Target Date",
                      style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600),
                    ),
                    Text(
                      alert.dateStr ?? "Action Req.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: alert.dateStr != null ? Colors.black87 : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              isSearch ? Icons.search_off_rounded : Icons.folder_open_rounded,
              size: 80,
              color: Colors.black45
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? "No results found" : "Your vault is empty",
            style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildGridTile(BuildContext context, String docId, Map<String, dynamic> data) {
    double? amount;
    if (data['amount'] is num) amount = data['amount'].toDouble();
    if (data['amount'] is String) amount = double.tryParse(data['amount']);

    String formattedDate = "Unknown Date";
    if (data['createdAt'] is Timestamp) {
      final date = (data['createdAt'] as Timestamp).toDate();
      formattedDate = "${date.day}/${date.month}/${date.year}";
    }

    final String category = data['category'] ?? 'Other';
    final String fileName = data['originalName'] ?? 'Unnamed Document';
    final String? storagePath = data['storagePath'];

    return GestureDetector(
      onLongPress: () {
        _deleteDocument(docId, storagePath);
      },
      onTap: () async {
        if (storagePath == null) return;

        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.black)));

        try {
          final file = await FileViewService.downloadFile(
              storagePath: storagePath, originalName: fileName);

          if (!mounted) return;
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(file: file)));
        } catch (e) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: vaultAmber.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 48,
                        color: Colors.amber[700],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (amount != null && amount > 0)
                          Text(
                            "₹${amount.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}