import 'package:cloud_firestore/cloud_firestore.dart';

class SosCloudService {
  SosCloudService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('sos');
  }

  Future<void> create({
    required String id,
    required String ownerId,
    required String type,
    required String? message,
    required double? latitude,
    required double? longitude,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    await _collection.doc(id).set({
      'id': id,
      'ownerId': ownerId,
      'type': type,
      'message': message,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    });
  }

  Future<void> update({
    required String id,
    required String type,
    required String? message,
    required double? latitude,
    required double? longitude,
    required String status,
    required DateTime updatedAt,
  }) async {
    await _collection.doc(id).update({
      'type': type,
      'message': message,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'updatedAt': Timestamp.fromDate(updatedAt),
    });
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}