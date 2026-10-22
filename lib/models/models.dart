import 'package:cloud_firestore/cloud_firestore.dart';

DateTime dateValue(dynamic value) => value is Timestamp
    ? value.toDate()
    : DateTime.fromMillisecondsSinceEpoch(0);
String money(num amount) =>
    '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

class Listing {
  final String id, title, description, department, category, condition;
  final String ownerId, ownerName, imageUrl, status;
  final double salePrice, dailyRate;
  final DateTime createdAt;
  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.category,
    required this.condition,
    required this.ownerId,
    required this.ownerName,
    required this.imageUrl,
    required this.status,
    required this.salePrice,
    required this.dailyRate,
    required this.createdAt,
  });
  factory Listing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Listing(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      department: d['department'] ?? '',
      category: d['category'] ?? '',
      condition: d['condition'] ?? '',
      ownerId: d['ownerId'] ?? '',
      ownerName: d['ownerName'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      status: d['status'] ?? 'archived',
      salePrice: (d['salePrice'] as num? ?? 0).toDouble(),
      dailyRate: (d['dailyRate'] as num? ?? 0).toDouble(),
      createdAt: dateValue(d['createdAt']),
    );
  }
  bool get available => status == 'available';
  Map<String, dynamic> get snapshot => {
    'title': title,
    'department': department,
    'category': category,
    'imageUrl': imageUrl,
    'salePrice': salePrice,
    'dailyRate': dailyRate,
    'ownerName': ownerName,
  };
}

class Booking {
  final String id, listingId, title, buyerId, sellerId, buyerName, sellerName;
  final String mode, status, pickupSpot;
  final DateTime pickupAt, startAt, endAt, createdAt;
  final double total;
  final int days;
  final String paymentMethod, paymentStatus, paymentReference, paymentAttemptId;
  const Booking({
    required this.id,
    required this.listingId,
    required this.title,
    required this.buyerId,
    required this.sellerId,
    required this.buyerName,
    required this.sellerName,
    required this.mode,
    required this.status,
    required this.pickupSpot,
    required this.pickupAt,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    required this.total,
    required this.days,
    this.paymentMethod = 'handover',
    this.paymentStatus = 'unpaid',
    this.paymentReference = '',
    this.paymentAttemptId = '',
  });
  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Booking(
      id: doc.id,
      listingId: d['listingId'],
      title: d['title'],
      buyerId: d['buyerId'],
      sellerId: d['sellerId'],
      buyerName: d['buyerName'],
      sellerName: d['sellerName'],
      mode: d['mode'],
      status: d['status'],
      pickupSpot: d['pickupSpot'],
      pickupAt: dateValue(d['pickupAt']),
      startAt: dateValue(d['startAt']),
      endAt: dateValue(d['endAt']),
      createdAt: dateValue(d['createdAt']),
      total: (d['total'] as num).toDouble(),
      days: d['days'],
      paymentMethod: d['paymentMethod'] ?? 'handover',
      paymentStatus: d['paymentStatus'] ?? 'unpaid',
      paymentReference: d['paymentReference'] ?? '',
      paymentAttemptId: d['paymentAttemptId'] ?? '',
    );
  }
  bool get simulated => paymentMethod == 'mock';
  bool get invoiceAvailable =>
      ['confirmed', 'completed'].contains(status) &&
      (!simulated || paymentStatus == 'succeeded');
  String get paymentLabel => simulated
      ? 'SIMULATION · $paymentStatus (no money moved)'
      : 'Pay at handover · payment not recorded';
}

/// Exclusive return date; UTC arithmetic avoids browser daylight-saving drift.
int rentalDays(DateTime start, DateTime end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
double bookingTotal({
  required String mode,
  required double salePrice,
  required double dailyRate,
  required DateTime start,
  required DateTime end,
}) {
  if (mode == 'buy' && salePrice > 0) return salePrice;
  if (mode != 'rent' ||
      dailyRate <= 0 ||
      rentalDays(start, end) < 1 ||
      rentalDays(start, end) > 90) {
    throw ArgumentError('Choose a rental period between 1 and 90 days.');
  }
  return double.parse((dailyRate * rentalDays(start, end)).toStringAsFixed(2));
}
