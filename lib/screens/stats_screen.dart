import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/sms_service.dart'; // 🟢 Import our SMS service

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int touchedIndex = -1;
  String selectedTimeframe = "This Month";

  // 🟢 We need a list to hold the SMS data locally
  List<SmsReminder> _smsExpenses = [];

  final Map<String, Color> categoryColors = {
    "Electricity": Colors.amber,
    "Rent": Colors.blueAccent,
    "Internet": Colors.purpleAccent,
    "Insurance": Colors.green,
    "Subscription": Colors.redAccent,
    "Other": Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _loadSmsData(); // 🟢 Fetch the SMS data when the screen loads
  }

  // 🟢 Function to grab local SMS data
  Future<void> _loadSmsData() async {
    final smsList = await SmsService.fetchFinancialSms();
    if (mounted) {
      setState(() {
        _smsExpenses = smsList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*──────── 1. HEADER & TIMEFRAME TOGGLE ────────*/
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Activity",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.black,
                    ),
                  ),
                  _buildTimeframeToggle(),
                ],
              ),
            ),

            /*──────── 2. DATA AGGREGATION & CHART ────────*/
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('documents')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  }

                  // Setup Variables
                  double totalSpending = 0;
                  Map<String, double> categoryTotals = {
                    "Electricity": 0, "Rent": 0, "Internet": 0,
                    "Insurance": 0, "Subscription": 0, "Other": 0,
                  };

                  final now = DateTime.now();

                  // ──────── 🟢 ADD FIRESTORE DOCUMENTS ────────
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;

                      if (selectedTimeframe == "This Month" && data['createdAt'] is Timestamp) {
                        DateTime docDate = (data['createdAt'] as Timestamp).toDate();
                        if (docDate.month != now.month || docDate.year != now.year) continue;
                      }

                      double amount = 0;
                      if (data['amount'] is num) amount = data['amount'].toDouble();
                      if (data['amount'] is String) amount = double.tryParse(data['amount']) ?? 0;

                      String category = data['category'] ?? "Other";
                      if (!categoryTotals.containsKey(category)) category = "Other";

                      categoryTotals[category] = categoryTotals[category]! + amount;
                      totalSpending += amount;
                    }
                  }

                  // ──────── 🟢 ADD LOCAL SMS EXPENSES ────────
                  for (var sms in _smsExpenses) {
                    if (sms.amount != null && sms.amount! > 0) {

                      // Filter SMS by timeframe
                      if (selectedTimeframe == "This Month" && sms.receivedDate != null) {
                        if (sms.receivedDate!.month != now.month || sms.receivedDate!.year != now.year) continue;
                      }

                      // Automatically categorize recharges as Internet, and bills as Other
                      String category = sms.isRecharge ? "Internet" : "Other";

                      categoryTotals[category] = categoryTotals[category]! + sms.amount!;
                      totalSpending += sms.amount!;
                    }
                  }

                  // If BOTH are empty, show empty state
                  if (totalSpending == 0) {
                    return _buildEmptyState(message: "No spending logged for $selectedTimeframe.");
                  }

                  // Build Chart Sections
                  List<PieChartSectionData> chartSections = [];
                  int index = 0;
                  categoryTotals.forEach((category, amount) {
                    if (amount > 0) {
                      final isTouched = index == touchedIndex;
                      final double radius = isTouched ? 65.0 : 50.0;
                      final double percentage = (amount / totalSpending) * 100;

                      chartSections.add(
                        PieChartSectionData(
                          color: categoryColors[category],
                          value: amount,
                          title: isTouched ? '₹${amount.toStringAsFixed(0)}' : '${percentage.toStringAsFixed(0)}%',
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: isTouched ? 14.0 : 12.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    index++;
                  });

                  // Render Chart & List
                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        touchedIndex = -1;
                                        return;
                                      }
                                      touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                sectionsSpace: 2,
                                centerSpaceRadius: 75,
                                sections: chartSections,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Total",
                                  style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  "₹${totalSpending.toStringAsFixed(0)}",
                                  style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(32),
                                topRight: Radius.circular(32),
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                              ]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Category Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 20),
                              Expanded(
                                child: ListView(
                                  physics: const BouncingScrollPhysics(),
                                  children: (categoryTotals.entries
                                      .where((e) => e.value > 0)
                                      .toList()
                                    ..sort((a, b) => b.value.compareTo(a.value))) // <-- Wraps the sorted list
                                      .map((e) => _buildStatRow(e.key, e.value, totalSpending)) // <-- Normal dot here!
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*──────── HELPER WIDGETS ────────*/

  Widget _buildTimeframeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildToggleButton("This Month"),
          _buildToggleButton("All Time"),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label) {
    bool isSelected = selectedTimeframe == label;
    return GestureDetector(
      onTap: () => setState(() => selectedTimeframe = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({String message = "Your vault is empty"}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String category, double amount, double total) {
    final color = categoryColors[category] ?? Colors.grey;
    final percentage = (amount / total);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          Text(
            "₹${amount.toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black),
          ),
        ],
      ),
    );
  }
}