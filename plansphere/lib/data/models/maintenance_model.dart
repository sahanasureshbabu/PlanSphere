import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRecord {
  final String id;
  final DateTime serviceDate;
  final double cost;
  final String technicianName;
  final String description;
  final String? receiptUrl;
  final String serviceType;
  final DateTime? nextServiceDate;

  ServiceRecord({
    required this.id,
    required this.serviceDate,
    required this.cost,
    required this.technicianName,
    required this.description,
    this.receiptUrl,
    this.serviceType = 'General Maintenance',
    this.nextServiceDate,
  });

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    return ServiceRecord(
      id: map['id'] ?? '',
      serviceDate: map['serviceDate'] is Timestamp
          ? (map['serviceDate'] as Timestamp).toDate()
          : map['serviceDate'] != null
              ? DateTime.parse(map['serviceDate'])
              : DateTime.now(),
      cost: (map['cost'] ?? 0.0).toDouble(),
      technicianName: map['technicianName'] ?? '',
      description: map['description'] ?? '',
      receiptUrl: map['receiptUrl'],
      serviceType: map['serviceType'] ?? 'General Maintenance',
      nextServiceDate: map['nextServiceDate'] is Timestamp
          ? (map['nextServiceDate'] as Timestamp).toDate()
          : map['nextServiceDate'] != null
              ? DateTime.tryParse(map['nextServiceDate'].toString())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceDate': Timestamp.fromDate(serviceDate),
      'cost': cost,
      'technicianName': technicianName,
      'description': description,
      'receiptUrl': receiptUrl,
      'serviceType': serviceType,
      'nextServiceDate': nextServiceDate != null ? Timestamp.fromDate(nextServiceDate!) : null,
    };
  }

  ServiceRecord copyWith({
    String? id,
    DateTime? serviceDate,
    double? cost,
    String? technicianName,
    String? description,
    String? receiptUrl,
    String? serviceType,
    DateTime? nextServiceDate,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      serviceDate: serviceDate ?? this.serviceDate,
      cost: cost ?? this.cost,
      technicianName: technicianName ?? this.technicianName,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      serviceType: serviceType ?? this.serviceType,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
    );
  }
}

class AmcRecord {
  final String providerName;
  final String? contactPhone;
  final DateTime startDate;
  final DateTime endDate;
  final double cost;
  final String? policyNumber;

  AmcRecord({
    required this.providerName,
    this.contactPhone,
    required this.startDate,
    required this.endDate,
    required this.cost,
    this.policyNumber,
  });

  factory AmcRecord.fromMap(Map<String, dynamic> map) {
    return AmcRecord(
      providerName: map['providerName'] ?? '',
      contactPhone: map['contactPhone'],
      startDate: map['startDate'] is Timestamp
          ? (map['startDate'] as Timestamp).toDate()
          : map['startDate'] != null
              ? DateTime.parse(map['startDate'])
              : DateTime.now(),
      endDate: map['endDate'] is Timestamp
          ? (map['endDate'] as Timestamp).toDate()
          : map['endDate'] != null
              ? DateTime.parse(map['endDate'])
              : DateTime.now(),
      cost: (map['cost'] ?? 0.0).toDouble(),
      policyNumber: map['policyNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerName': providerName,
      'contactPhone': contactPhone,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'cost': cost,
      'policyNumber': policyNumber,
    };
  }

  AmcRecord copyWith({
    String? providerName,
    String? contactPhone,
    DateTime? startDate,
    DateTime? endDate,
    double? cost,
    String? policyNumber,
  }) {
    return AmcRecord(
      providerName: providerName ?? this.providerName,
      contactPhone: contactPhone ?? this.contactPhone,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cost: cost ?? this.cost,
      policyNumber: policyNumber ?? this.policyNumber,
    );
  }
}
