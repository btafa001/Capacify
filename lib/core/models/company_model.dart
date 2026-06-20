import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String website;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String postalCode;
  final String country;
  final String employees;
  final String trade;
  final List<String> services;
  final String logoUrl;
  final String vatNumber;
  final String verificationStatus;
  final int ratingSum;
  final int ratingCount;
  final bool contentFlagged;
  final DateTime? createdAt;

  bool get isVerified => verificationStatus == 'verified';
  double get avgRating => ratingCount > 0 ? ratingSum / ratingCount : 0.0;

  CompanyModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.website,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.employees,
    required this.trade,
    required this.services,
    required this.logoUrl,
    this.vatNumber = '',
    this.verificationStatus = 'none',
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.contentFlagged = false,
    this.createdAt,
  });

  // Convert Firestore document to CompanyModel
  factory CompanyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      website: data['website'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      postalCode: data['postalCode'] ?? '',
      country: data['country'] ?? 'Deutschland',
      employees: data['employees'] ?? '',
      trade: data['trade'] ?? '',
      services: List<String>.from(data['services'] ?? []),
      logoUrl: data['logoUrl'] ?? '',
      vatNumber: data['vatNumber'] ?? '',
      verificationStatus: data['verificationStatus'] ?? 'none',
      ratingSum: data['ratingSum'] ?? 0,
      ratingCount: data['ratingCount'] ?? 0,
      contentFlagged: data['contentFlagged'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert CompanyModel to Map for Firestore — used only on initial creation.
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'website': website,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'employees': employees,
      'trade': trade,
      'services': services,
      'logoUrl': logoUrl,
      'vatNumber': vatNumber,
      'verificationStatus': verificationStatus,
      'ratingSum': ratingSum,
      'ratingCount': ratingCount,
      'contentFlagged': contentFlagged,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// For editing an existing company's profile fields. Deliberately excludes
  /// vatNumber/verificationStatus (set at registration / managed by admin
  /// actions) and ratingSum/ratingCount/createdAt (managed by submitRating())
  /// — Firestore's update() only touches keys present here, so omitting them
  /// leaves the existing values untouched. contentFlagged IS included since
  /// it's derived from the description text and must be recomputed on save.
  Map<String, dynamic> toFirestoreForUpdate() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'website': website,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'employees': employees,
      'trade': trade,
      'services': services,
      'logoUrl': logoUrl,
      'contentFlagged': contentFlagged,
    };
  }
}