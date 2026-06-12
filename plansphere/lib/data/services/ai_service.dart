import 'package:plansphere/data/models/bill_model.dart';

class AiService {
  /// Calculates a bounded, logical Warranty Health Score [0 - 100]
  int calculateHealthScore(BillModel bill) {
    if (!bill.hasWarranty || bill.warrantyExpiryDate == null) {
      return 0;
    }

    final now = DateTime.now();
    final totalDays = bill.warrantyExpiryDate!.difference(bill.purchaseDate).inDays;
    
    // 1. Determine Base Score
    int baseScore = 90; // Default active warranty
    final status = bill.warrantyStatus;
    if (status == WarrantyStatus.expired) {
      baseScore = 10;
    } else if (status == WarrantyStatus.expiringSoon) {
      baseScore = 50;
    } else if (status == WarrantyStatus.noWarranty) {
      baseScore = 0;
    }

    // 2. Age Penalty (elapsing warranty over time, max 20 point deduction)
    double agePenalty = 0.0;
    if (totalDays > 0 && status != WarrantyStatus.expired) {
      final elapsedDays = now.difference(bill.purchaseDate).inDays;
      if (elapsedDays > 0) {
        final ratio = elapsedDays / totalDays;
        agePenalty = 20.0 * ratio;
      }
    } else if (status == WarrantyStatus.expired) {
      agePenalty = 20.0;
    }

    // 3. Service History Bonus (+10 per record, cap at +20)
    int serviceBonus = bill.serviceHistory.length * 10;
    if (serviceBonus > 20) {
      serviceBonus = 20;
    }

    // Calculate final score with strict boundary capping [0 - 100]
    final double rawScore = baseScore.toDouble() - agePenalty + serviceBonus.toDouble();
    final int finalScore = rawScore.round().clamp(0, 100);

    return finalScore;
  }

  /// Categorize bills locally using keyword analysis
  String smartCategorize(String text) {
    final lowerText = text.toLowerCase();

    final categoryKeywords = {
      'Electronics': ['mobile', 'phone', 'laptop', 'computer', 'macbook', 'ipad', 'tablet', 'tv', 'television', 'camera', 'headphone', 'earphone', 'keyboard', 'mouse', 'charger'],
      'Appliances': ['refrigerator', 'washing machine', 'microwave', 'oven', 'ac', 'air conditioner', 'dishwasher', 'fan', 'cooler', 'geyser', 'heater', 'chimney'],
      'Food & Grocery': ['grocery', 'supermarket', 'mart', 'vegetable', 'fruit', 'food', 'restaurant', 'cafe', 'swiggy', 'zomato', 'bakery', 'milk', 'cheese'],
      'Medical': ['hospital', 'clinic', 'pharmacy', 'medicine', 'doctor', 'dental', 'lab', 'diagnostic', 'prescription', 'syrup', 'tablet', 'health'],
      'Travel': ['airline', 'flight', 'hotel', 'bus', 'train', 'ticket', 'booking', 'irctc', 'makemytrip', 'uber', 'ola', 'cab', 'taxi'],
      'Insurance': ['insurance', 'premium', 'policy', 'life insurance', 'health insurance', 'lic', 'hdfc ergo'],
      'Fuel': ['petrol', 'diesel', 'fuel', 'gas station', 'hp', 'indian oil', 'bpcl', 'iocl', 'cng'],
      'Automobile': ['car', 'bike', 'vehicle', 'service', 'spare', 'tyre', 'motor', 'garage', 'mechanic', 'lubricant'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return 'Others';
  }

  /// Compiles dynamic spent categories analysis
  Map<String, double> computeCategorySpending(List<BillModel> bills) {
    final spending = <String, double>{};
    for (final bill in bills) {
      spending[bill.category] = (spending[bill.category] ?? 0.0) + bill.amount;
    }
    return spending;
  }

  /// Generates dynamic monthly insights (paragraphs) based on historical user spending
  List<String> generateSpendingInsights(List<BillModel> bills) {
    if (bills.isEmpty) {
      return ['No bills logged yet. Log transactions to get AI insights!'];
    }

    final insights = <String>[];
    final categorySpend = computeCategorySpending(bills);
    
    // Find top spending category
    String topCategory = 'Others';
    double maxSpend = 0.0;
    categorySpend.forEach((cat, amt) {
      if (amt > maxSpend) {
        maxSpend = amt;
        topCategory = cat;
      }
    });

    insights.add(
      'Your largest spending category is **$topCategory** with a total of **₹${maxSpend.toStringAsFixed(0)}**. '
      'Ensure high-value items in this category have active warranties logged!'
    );

    // Maintenance health check
    final activeWarranties = bills.where((b) => b.hasWarranty && b.warrantyStatus == WarrantyStatus.active).toList();
    if (activeWarranties.isNotEmpty) {
      final avgHealth = activeWarranties.map((b) => calculateHealthScore(b)).reduce((a, b) => a + b) / activeWarranties.length;
      insights.add(
        'The average **Warranty Health Score** of your active assets is **${avgHealth.toStringAsFixed(0)}/100**. '
        'Keeping regular service logs maintains high health ratings and protects item utility.'
      );
    } else {
      insights.add(
        'You currently have **0 active warranties** logged. '
        'Add details for newly purchased items to avoid out-of-pocket repair costs!'
      );
    }

    // Expiry warnings
    final expiringSoon = bills.where((b) => b.hasWarranty && b.warrantyStatus == WarrantyStatus.expiringSoon).toList();
    if (expiringSoon.isNotEmpty) {
      insights.add(
        'You have **${expiringSoon.length} item(s)** with warranties expiring within 30 days! '
        'We recommend executing maintenance checkups or filing claims for any current defects immediately.'
      );
    }

    // Brand Loyalty Insight
    final brands = <String, int>{};
    for (final bill in bills) {
      if (bill.brand != 'Generic' && bill.brand.isNotEmpty) {
        brands[bill.brand] = (brands[bill.brand] ?? 0) + 1;
      }
    }
    if (brands.isNotEmpty) {
      String favBrand = 'Generic';
      int maxCount = 0;
      brands.forEach((brand, cnt) {
        if (cnt > maxCount) {
          maxCount = cnt;
          favBrand = brand;
        }
      });
      insights.add(
        'You demonstrate a strong preference for **$favBrand** products (logged $maxCount times). '
        'Check out service history records to see if your favorite brand has high maintenance requirements!'
      );
    }

    return insights;
  }
}
