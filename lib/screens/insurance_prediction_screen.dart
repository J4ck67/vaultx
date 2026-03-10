import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/insurance_dataset.dart';
import '../widgets/upload_bill.dart';

class InsurancePredictionScreen extends StatefulWidget {
  const InsurancePredictionScreen({super.key});

  @override
  State<InsurancePredictionScreen> createState() =>
      _InsurancePredictionScreenState();
}

class _InsurancePredictionScreenState extends State<InsurancePredictionScreen> {
  final TextEditingController _salaryController = TextEditingController();

  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;

  double _monthlySalary = 0;
  double _totalInsurancePaid = 0; // Annually

  int _healthScore = 0;
  List<InsurancePlan> _healthRecommendations = [];
  List<InsurancePlan> _vehicleRecommendations = [];

  /*──────── CORE LOGIC ────────*/

  Future<void> _analyzePolicyHealth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final salaryText = _salaryController.text.trim();
    if (salaryText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your estimated monthly salary."),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _monthlySalary = double.tryParse(salaryText.replaceAll(',', '')) ?? 0;
    });

    try {
      // 1. Fetch user's insurance bills from the vault
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .where('category', isEqualTo: 'Insurance')
          .get();

      double totalHealthPaid = 0;
      double totalVehiclePaid = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Safely extract amount whether it's stored as String or Number
        double amount = 0;
        if (data['amount'] is num) {
          amount = (data['amount'] as num).toDouble();
        } else if (data['amount'] is String) {
          amount = double.tryParse(data['amount'].replaceAll(',', '')) ?? 0;
        }

        String name = (data['originalName'] as String?)?.toLowerCase() ?? "";

        // Very basic heuristic: if bill name implies car/vehicle
        if (name.contains('car') ||
            name.contains('motor') ||
            name.contains('vehicle')) {
          totalVehiclePaid += amount;
        } else {
          // Assume health or generic insurance
          totalHealthPaid += amount;
        }
      }

      _totalInsurancePaid = totalHealthPaid + totalVehiclePaid;

      // 2. Calculate Policy Health Score
      // Ideal: Insurance premiums should be roughly 5-10% of ANNUAL income natively.
      // E.g. 50,000 monthly = 600,000 annual. 5-10% = 30,000 to 60,000 towards insurance.
      double annualIncome = _monthlySalary * 12;

      if (annualIncome == 0) {
          _healthScore = 0;
      } else if (_totalInsurancePaid == 0) {
          // No insurance found in Vault
          _healthScore = 15; // Vulnerable
      } else {
          double ratio = _totalInsurancePaid / annualIncome;
          
          if (ratio >= 0.05 && ratio <= 0.12) {
              _healthScore = 95; // Golden ratio
          } else if (ratio > 0.001 && ratio < 0.05) {
              _healthScore = 70; // Under-insured likely
          } else if (ratio > 0.12 && ratio <= 0.20) {
              _healthScore = 60; // Overpaying
          } else if (ratio > 0.20) {
              _healthScore = 40; // Severely overpaying
          } else {
              _healthScore = 50; // Catch-all for extreme math (e.g. billion dollar salary)
          }
      }

      // 3. Generate Smart Recommendations based on what they are currently paying
      _healthRecommendations = IndianInsuranceDataset.getRecommendations(
        category: 'Health',
        currentPremiumPaid: totalHealthPaid,
      );

      _vehicleRecommendations = IndianInsuranceDataset.getRecommendations(
        category: 'Vehicle',
        currentPremiumPaid: totalVehiclePaid,
      );

      setState(() {
        _hasAnalyzed = true;
      });
    } catch (e) {
      debugPrint("Error analyzing policy: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Analysis failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  /*──────── UI COMPONENTS ────────*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Policy Health Engine",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSalaryInput(),
                const SizedBox(height: 24),
                if (_isAnalyzing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Colors.black),
                    ),
                  )
                else if (_hasAnalyzed)
                  _buildResultsView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFDD53F),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety,
              color: Colors.black,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   "Smart Insurance Predictor", 
                   style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                 ),
                 const SizedBox(height: 4),
                 const Text(
                   "Analyze your bills to find cheaper, better premiums tailored for you.",
                   style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                 ),
                 const SizedBox(height: 12),
                 GestureDetector(
                   onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadBillButton()));
                   },
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                     decoration: BoxDecoration(
                       color: const Color(0xFFFDD53F),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: const Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Icon(Icons.upload_file_rounded, color: Colors.black, size: 14),
                         SizedBox(width: 6),
                         Text("Upload Policy", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                       ],
                     )
                   ),
                 )
               ],
             )
           )
        ],
      ),
    );
  }

  Widget _buildSalaryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Monthly Income (₹)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "E.g. 50000",
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.currency_rupee,
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _analyzePolicyHealth,
              child: Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),

        // Score Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _getScoreColor().withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getScoreColor().withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                "Your Policy Health Score",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: CircularProgressIndicator(
                      value: _healthScore / 100,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[200],
                      color: _getScoreColor(),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        "$_healthScore",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(),
                        ),
                      ),
                      const Text(
                        "/100",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _getScoreMessage(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        if (_healthRecommendations.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.medical_services, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                "Health Insurance Matches",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._healthRecommendations.map(
            (plan) => _buildRecommendationCard(plan),
          ),
          const SizedBox(height: 24),
        ],

        if (_vehicleRecommendations.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                "Vehicle Insurance Matches",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._vehicleRecommendations.map(
            (plan) => _buildRecommendationCard(plan),
          ),
        ],
      ],
    );
  }

  Widget _buildRecommendationCard(InsurancePlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.providerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: plan.category == 'Health'
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  plan.type,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: plan.category == 'Health' ? Colors.red : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.planName,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Est. Premium",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    "₹${plan.estimatedAnnualPremium.toStringAsFixed(0)}/yr",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Coverage",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    "₹${(plan.coverageAmount / 100000).toStringAsFixed(1)}L",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plan.keyBenefits
                .take(2)
                .map((b) => _buildBadge(b))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 12, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor() {
    if (_healthScore >= 80) return Colors.green;
    if (_healthScore >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getScoreMessage() {
    if (_healthScore >= 90) return "Excellent! You are paying a perfectly balanced ratio of insurance premiums to your income.";
    if (_healthScore >= 70) return "You're slightly under-insured. Consider upgrading your health or car base plans for safety.";
    if (_healthScore >= 50) return "You're overpaying for insurance. Compare your premiums to the market averages below.";
    if (_healthScore == 15) return "No active policies found in your Vault. Please Upload your Insurance bills or explore the baseline recommendations below.";
    return "Critical! You are severely overpaying compared to your salary. Secure yourself immediately with the plans below.";
  }
}
