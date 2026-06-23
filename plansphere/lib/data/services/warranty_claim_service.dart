import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/bill_model.dart';

class WarrantyClaimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates a highly professional formal claim letter text based on purchase and defect information
  String compileClaimRequestLetter({
    required BillModel bill,
    required String userName,
    required String userEmail,
    required String defectDescription,
    required String resolutionSought,
    String? serviceCenterName,
    String? supportEmail,
    String? customerCareNumber,
  }) {
    final purchaseDateFormatted = '${bill.purchaseDate.day}/${bill.purchaseDate.month}/${bill.purchaseDate.year}';
    final expiryDateFormatted = bill.warrantyExpiryDate != null
        ? '${bill.warrantyExpiryDate!.day}/${bill.warrantyExpiryDate!.month}/${bill.warrantyExpiryDate!.year}'
        : 'N/A';

    final toName = serviceCenterName != null && serviceCenterName.isNotEmpty
        ? serviceCenterName
        : '${bill.storeName} / ${bill.brand} Care Center';

    final toContact = (supportEmail != null && supportEmail.isNotEmpty) || (customerCareNumber != null && customerCareNumber.isNotEmpty)
        ? '\nContact: ${customerCareNumber ?? ""} ${supportEmail != null && supportEmail.isNotEmpty ? "($supportEmail)" : ""}'
        : '';

    return '''
Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}

To,
Customer Support Services / Warranty Claims Division
$toName$toContact

Subject: Formal Warranty Claim Request for ${bill.brand} ${bill.title}

Dear Sir/Madam,

I am writing this letter to formally register a warranty repair/replacement claim for my purchase of a ${bill.brand} ${bill.title}, bought on $purchaseDateFormatted from ${bill.storeName} for an amount of ₹${bill.amount.toStringAsFixed(2)}. 

Details of the product and invoice are outlined below:
- Product Name: ${bill.title}
- Manufacturer Brand: ${bill.brand}
- Purchase Date: $purchaseDateFormatted
- Active Warranty Period Expires: $expiryDateFormatted
- Purchase Invoice Reference: ${bill.id.substring(0, 8).toUpperCase()}

DESCRIPTION OF ISSUE / DEFECT DETECTED:
$defectDescription

As the product is well within its active manufacturer warranty coverage window, I kindly request you to look into this defect at the earliest. In line with the warranty guidelines, I am seeking the following resolution:
$resolutionSought

Please find attached the original purchase receipt/invoice PDF for verification of my purchase. I can be reached via the contact details provided below for coordinating inspection or service center pickup.

Thank you for your prompt cooperation and professional assistance in resolving this matter.

Sincerely,

$userName
Email: $userEmail
''';
  }

  /// Updates the claim status of a specific bill in Firestore
  Future<void> updateClaimStatus({
    required String billId,
    required String status,
    String? claimNotes,
  }) async {
    final Map<String, dynamic> updates = {
      'claimStatus': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (claimNotes != null) {
      updates['claimNotes'] = claimNotes;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.billsCollection)
        .doc(billId)
        .update(updates);

    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('warranties')
          .doc(billId)
          .update(updates);
    } catch (_) {}
  }
}
