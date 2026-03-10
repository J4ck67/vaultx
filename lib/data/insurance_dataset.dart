class InsurancePlan {
  final String providerName;
  final String planName;
  final String category; // "Health" or "Vehicle"
  final double estimatedAnnualPremium; // Base average in ₹
  final double coverageAmount; // Base average coverage in ₹
  final List<String> keyBenefits;
  final String type; // "Family", "Individual", "Comprehensive", "Third-Party"

  const InsurancePlan({
    required this.providerName,
    required this.planName,
    required this.category,
    required this.estimatedAnnualPremium,
    required this.coverageAmount,
    required this.keyBenefits,
    required this.type,
  });
}

class IndianInsuranceDataset {
  static const List<InsurancePlan> healthInsurances = [
    InsurancePlan(
      providerName: 'Star Health',
      planName: 'Family Health Optima',
      category: 'Health',
      estimatedAnnualPremium: 14500,
      coverageAmount: 1000000,
      type: 'Family',
      keyBenefits: [
        'No Claim Bonus up to 100%',
        'Auto Restoration of Sum Insured',
        'Covers newborn from day 1',
        'Ayush Treatment covered'
      ],
    ),
    InsurancePlan(
      providerName: 'HDFC ERGO',
      planName: 'Optima Secure',
      category: 'Health',
      estimatedAnnualPremium: 12000,
      coverageAmount: 1000000,
      type: 'Individual',
      keyBenefits: [
        '2X Coverage from Day 1',
        'Zero deduction on non-medical expenses',
        'Free health checkup on renewal',
        'E-opinion for critical illness'
      ],
    ),
    InsurancePlan(
      providerName: 'Care Health',
      planName: 'Care Supreme',
      category: 'Health',
      estimatedAnnualPremium: 9500,
      coverageAmount: 700000,
      type: 'Individual',
      keyBenefits: [
        'Unlimited automatic recharge',
        'Cumulative bonus super',
        'Annual health check-ups',
        'No sub-limit on room rent'
      ],
    ),
    InsurancePlan(
      providerName: 'Niva Bupa',
      planName: 'ReAssure 2.0',
      category: 'Health',
      estimatedAnnualPremium: 15800,
      coverageAmount: 1500000,
      type: 'Family',
      keyBenefits: [
        'Lock-in premium based on entry age',
        'Carry forward unused coverage',
        'ReAssure benefit triggered after 1st claim',
        'Cashless in 30 mins'
      ],
    ),
    InsurancePlan(
      providerName: 'Aditya Birla',
      planName: 'Activ Health Platinum',
      category: 'Health',
      estimatedAnnualPremium: 13200,
      coverageAmount: 1000000,
      type: 'Family',
      keyBenefits: [
        '100% Reload of Sum Insured',
        'HealthReturns based on active lifestyle',
        'Chronic management program',
        'Dental and Vision coverage'
      ],
    ),
  ];

  static const List<InsurancePlan> vehicleInsurances = [
    InsurancePlan(
      providerName: 'ICICI Lombard',
      planName: 'Comprehensive Car Insurance',
      category: 'Vehicle',
      estimatedAnnualPremium: 8500,
      coverageAmount: 600000, // IDV
      type: 'Comprehensive',
      keyBenefits: [
        'Zero Depreciation Cover',
        'Cashless at 5600+ garages',
        'Engine Protect Plus',
        '24x7 Roadside Assistance'
      ],
    ),
    InsurancePlan(
      providerName: 'Tata AIG',
      planName: 'Auto Secure',
      category: 'Vehicle',
      estimatedAnnualPremium: 7800,
      coverageAmount: 550000, // IDV
      type: 'Comprehensive',
      keyBenefits: [
        'Return to Invoice cover',
        'No Claim Bonus protection',
        'Consumables cover',
        'Quick claim settlement'
      ],
    ),
    InsurancePlan(
      providerName: 'Go Digit',
      planName: 'Digit Car Insurance',
      category: 'Vehicle',
      estimatedAnnualPremium: 6500,
      coverageAmount: 500000, // IDV
      type: 'Comprehensive',
      keyBenefits: [
        'Customizable IDV',
        'Smartphone smartphone inspection',
        'Advance cash for repairs',
        'Tyre Protect'
      ],
    ),
    InsurancePlan(
      providerName: 'Bajaj Allianz',
      planName: 'Drive Assure',
      category: 'Vehicle',
      estimatedAnnualPremium: 9200,
      coverageAmount: 700000, // IDV
      type: 'Comprehensive',
      keyBenefits: [
        'Conveyance benefit',
        'Key and Lock replacement',
        'Personal baggage cover',
        'Accident shield'
      ],
    ),
    InsurancePlan(
      providerName: 'Acko',
      planName: 'Acko Comprehensive',
      category: 'Vehicle',
      estimatedAnnualPremium: 5800,
      coverageAmount: 480000, // IDV
      type: 'Comprehensive',
      keyBenefits: [
        'Instant quotes and zero paperwork',
        'Doorstep car pick-up & drop',
        'Zero hidden deductions',
        '1-hour free repair network'
      ],
    ),
  ];

  // Helper method to query recommendations based on current spending
  static List<InsurancePlan> getRecommendations({
    required String category,
    required double currentPremiumPaid,
  }) {
    List<InsurancePlan> dataset = category == 'Health' 
        ? healthInsurances 
        : (category == 'Vehicle' ? vehicleInsurances : [...healthInsurances, ...vehicleInsurances]);

    // We recommend plans that are substantially cheaper than what they currently pay
    // Or if they aren't paying anything, we recommend the most affordable solid ones
    List<InsurancePlan> recommendations = [];
    
    if (currentPremiumPaid > 0) {
       // User is overpaying, show them options that are at least 15% cheaper
       recommendations = dataset.where(
         (plan) => plan.estimatedAnnualPremium < (currentPremiumPaid * 0.85)
       ).toList();
    } 

    // If no cheaper plans, or if they have no insurance (0), suggest the best value ones
    if (recommendations.isEmpty) {
        recommendations = List.from(dataset);
        recommendations.sort((a, b) => a.estimatedAnnualPremium.compareTo(b.estimatedAnnualPremium));
    }

    // Return top 2 recommendations
    return recommendations.take(2).toList();
  }
}
