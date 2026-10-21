import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'photo_service.dart';
import 'voice_clip.dart';
import '../models/models.dart';

class MarketService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  MarketService(this.db, this.auth);
  String get uid => auth.currentUser!.uid;
  Stream<QuerySnapshot<Map<String, dynamic>>> listings() => db
      .collection('listings')
      .where('status', isEqualTo: 'available')
      .snapshots(includeMetadataChanges: true);
  Stream<QuerySnapshot<Map<String, dynamic>>> myListings() => db
      .collection('listings')
      .where('ownerId', isEqualTo: uid)
      .snapshots(includeMetadataChanges: true);
  Stream<QuerySnapshot<Map<String, dynamic>>> bookmarks() => db
      .collection('users')
      .doc(uid)
      .collection('bookmarks')
      .snapshots(includeMetadataChanges: true);
  Stream<QuerySnapshot<Map<String, dynamic>>> bookings() => db
      .collection('bookings')
      .where('participants', arrayContains: uid)
      .snapshots(includeMetadataChanges: true);
  Stream<QuerySnapshot<Map<String, dynamic>>> conversations() => db
      .collection('conversations')
      .where('participants', arrayContains: uid)
      .snapshots(includeMetadataChanges: true);
  Stream<DocumentSnapshot<Map<String, dynamic>>> listing(String id) =>
      db.collection('listings').doc(id).snapshots(includeMetadataChanges: true);
  Stream<DocumentSnapshot<Map<String, dynamic>>> booking(String id) =>
      db.collection('bookings').doc(id).snapshots(includeMetadataChanges: true);
  Future<void> saveBookmark(Listing listing, bool saved) async {
    final ref = db
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .doc(listing.id);
    if (saved) {
      await ref.delete().timeout(const Duration(seconds: 15));
    } else {
      await ref
          .set({
            ...listing.snapshot,
            'listingId': listing.id,
            'savedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));
    }
  }

  Future<String> publish(
    Map<String, dynamic> values,
    Uint8List? image,
    String? mime,
  ) async {
    final profile = await db
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final ref = db.collection('listings').doc();
    String imageUrl = '';
    Uint8List? compressed;
    if (image != null) {
      compressed = await PhotoService.compress(image);
      imageUrl = 'firestore:${ref.id}';
    }
    final batch = db.batch();
    batch.set(ref, {
      ...values,
      'ownerId': uid,
      'ownerName': profile.data()!['name'],
      'imageUrl': imageUrl,
      'status': 'available',
      'activeBookingId': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (compressed != null) {
      batch.set(db.collection('listing-images').doc(ref.id), {
        'ownerId': uid,
        'data': base64Encode(compressed),
        'contentType': 'image/jpeg',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit().timeout(const Duration(seconds: 20));
    return ref.id;
  }

  Future<void> archiveListing(Listing item) async {
    await db.runTransaction((tx) async {
      final ref = db.collection('listings').doc(item.id);
      final d = (await tx.get(ref)).data();
      if (d == null || d['ownerId'] != uid || d['status'] != 'available') {
        throw StateError('Only your available listings can be archived.');
      }
      tx.update(ref, {'status': 'archived'});
    });
  }

  Future<String> createBooking({
    required Listing item,
    required String mode,
    required DateTime start,
    required DateTime end,
    required DateTime pickupAt,
    required String pickupSpot,
    bool simulatePayment = false,
  }) async {
    if (pickupSpot.trim().length < 3 || pickupSpot.trim().length > 120) {
      throw ArgumentError(
        'Enter a pickup location between 3 and 120 characters.',
      );
    }
    if (pickupAt.isBefore(DateTime.now())) {
      throw ArgumentError('Choose a future pickup time.');
    }
    final bookingRef = db.collection('bookings').doc();
    final itemRef = db.collection('listings').doc(item.id);
    final profileRef = db.collection('users').doc(uid);
    await db
        .runTransaction((tx) async {
          final itemDoc = await tx.get(itemRef);
          final profile = await tx.get(profileRef);
          if (!itemDoc.exists) throw StateError('This item has been removed.');
          final current = Listing.fromDoc(itemDoc);
          if (!current.available) {
            throw StateError('This item has already been reserved.');
          }
          if (current.ownerId == uid) {
            throw StateError('You cannot book your own item.');
          }
          if (current.salePrice != item.salePrice ||
              current.dailyRate != item.dailyRate) {
            throw StateError(
              'The price has changed. Reopen the item before booking.',
            );
          }
          final total = bookingTotal(
            mode: mode,
            salePrice: current.salePrice,
            dailyRate: current.dailyRate,
            start: start,
            end: end,
          );
          tx.set(bookingRef, {
            'listingId': item.id,
            'title': current.title,
            'buyerId': uid,
            'sellerId': current.ownerId,
            'buyerName': profile.data()!['name'],
            'sellerName': current.ownerName,
            'participants': [uid, current.ownerId],
            'mode': mode,
            'status': 'confirmed',
            'total': total,
            'days': mode == 'rent' ? rentalDays(start, end) : 0,
            'startAt': Timestamp.fromDate(start),
            'endAt': Timestamp.fromDate(end),
            'pickupAt': Timestamp.fromDate(pickupAt),
            'pickupSpot': pickupSpot.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            if (simulatePayment) ...{
              'paymentMethod': 'mock',
              'paymentStatus': 'pending',
              'paymentReference': '',
              'paymentAttemptId': '',
            },
          });
          tx.update(itemRef, {
            'status': 'reserved',
            'activeBookingId': bookingRef.id,
          });
        })
        .timeout(const Duration(seconds: 25));
    return bookingRef.id;
  }

  Future<void> updateBooking(Booking booking, String status) async {
    final ref = db.collection('bookings').doc(booking.id);
    final itemRef = db.collection('listings').doc(booking.listingId);
    await db
        .runTransaction((tx) async {
          final d = (await tx.get(ref)).data();
          final item = (await tx.get(itemRef)).data();
          if (d == null ||
              d['status'] != 'confirmed' ||
              item == null ||
              item['activeBookingId'] != booking.id) {
            throw StateError(
              'This booking has changed. Refresh and try again.',
            );
          }
          if (status == 'completed' && d['sellerId'] != uid) {
            throw StateError('Only the seller can complete a booking.');
          }
          if (status == 'completed' &&
              d['paymentMethod'] == 'mock' &&
              d['paymentStatus'] != 'succeeded') {
            throw StateError(
              'Complete the test payment before confirming handover or return.',
            );
          }
          if (status == 'cancelled' &&
              !(d['participants'] as List).contains(uid)) {
            throw StateError('This is not your booking.');
          }
          if (status != 'completed' && status != 'cancelled') {
            throw ArgumentError('Invalid booking status.');
          }
          tx.update(ref, {
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.update(itemRef, {
            'status': status == 'completed' && d['mode'] == 'buy'
                ? 'sold'
                : 'available',
            'activeBookingId': '',
          });
        })
        .timeout(const Duration(seconds: 25));
  }

  Future<String> openConversation(Listing item) async {
    if (item.ownerId == uid) throw StateError('This is your own listing.');
    final id = '${item.id}_$uid';
    final ref = db.collection('conversations').doc(id);
    await db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      final profile = await tx.get(db.collection('users').doc(uid));
      final listing = await tx.get(db.collection('listings').doc(item.id));
      if (!listing.exists) throw StateError('This item is no longer listed.');
      if (!existing.exists) {
        tx.set(ref, {
          'listingId': item.id,
          'title': item.title,
          'buyerId': uid,
          'sellerId': item.ownerId,
          'participants': [uid, item.ownerId],
          'buyerName': profile.data()!['name'],
          'sellerName': item.ownerName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
    return id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String id) => db
      .collection('conversations')
      .doc(id)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots(includeMetadataChanges: true);
  String newMessageId(String id) =>
      db.collection('conversations').doc(id).collection('messages').doc().id;

  Future<void> sendMessage(String id, String text, {String? messageId}) async {
    final value = text.trim();
    if (value.isEmpty || value.length > 2000) {
      throw ArgumentError('Messages must contain 1 to 2000 characters.');
    }
    final sender = uid;
    final conversation = db.collection('conversations').doc(id);
    final ref = conversation.collection('messages').doc(messageId);
    await db
        .runTransaction((tx) async {
          final chat = await tx.get(conversation);
          final existing = await tx.get(ref);
          if (!(chat.data()?['participants'] as List? ?? []).contains(sender)) {
            throw StateError('This conversation is unavailable.');
          }
          if (existing.exists) {
            if (existing.data()?['senderId'] != sender ||
                existing.data()?['text'] != value ||
                existing.data()?['type'] == 'audio') {
              throw StateError('This message reference has already been used.');
            }
            return;
          }
          tx.set(ref, {
            'senderId': sender,
            'text': value,
            'createdAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  Future<void> sendVoice(
    String id,
    VoiceClip clip, {
    required String messageId,
  }) async {
    // Validate even a clip supplied outside the recording UI.
    VoiceClip.decode(clip.encoded, clip.durationMs);
    final sender = uid;
    final conversation = db.collection('conversations').doc(id);
    final ref = conversation.collection('messages').doc(messageId);
    final audio = conversation.collection('audio').doc(messageId);
    await db
        .runTransaction((tx) async {
          final chat = await tx.get(conversation);
          final existing = await tx.get(ref);
          if (!(chat.data()?['participants'] as List? ?? []).contains(sender)) {
            throw StateError('This conversation is unavailable.');
          }
          if (existing.exists) {
            final saved = await tx.get(audio);
            if (existing.data()?['senderId'] != sender ||
                existing.data()?['type'] != 'audio' ||
                saved.data()?['data'] != clip.encoded) {
              throw StateError(
                'This voice message reference has already been used.',
              );
            }
            return;
          }
          tx.set(ref, {
            'senderId': sender,
            'type': 'audio',
            'durationMs': clip.durationMs,
            'audioId': messageId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(audio, {
            'senderId': sender,
            'data': clip.encoded,
            'contentType': 'audio/wav',
            'durationMs': clip.durationMs,
            'createdAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 25));
  }

  Future<VoiceClip> loadVoice(String id, String messageId) async {
    final doc = await db
        .collection('conversations')
        .doc(id)
        .collection('audio')
        .doc(messageId)
        .get()
        .timeout(const Duration(seconds: 20));
    final data = doc.data();
    if (data == null || data['contentType'] != 'audio/wav') {
      throw StateError('Voice message unavailable.');
    }
    return VoiceClip.decode(data['data'] as String, data['durationMs'] as int);
  }

  Future<void> markConversationRead(String id, Timestamp at) async {
    final ref = db
        .collection('conversations')
        .doc(id)
        .collection('reads')
        .doc(uid);
    await db
        .runTransaction((tx) async {
          final old = (await tx.get(ref)).data()?['readAt'] as Timestamp?;
          if (old == null || at.compareTo(old) > 0) tx.set(ref, {'readAt': at});
        })
        .timeout(const Duration(seconds: 15));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> readReceipt(String id) => db
      .collection('conversations')
      .doc(id)
      .collection('reads')
      .doc(uid)
      .snapshots();
}
