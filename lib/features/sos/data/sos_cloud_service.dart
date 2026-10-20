import 'package:cloud_firestore/cloud_firestore.dart';

class SosCloudService {
  SosCloudService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('sos');

  Future<bool> exists(String id) async {
    final snapshot = await _collection.doc(id).get();
    return snapshot.exists;
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
    final data = <String, dynamic>{
      'type': type,
      'message': message,
      'status': status,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    // A status/message update must not erase a previously stored incident
    // snapshot when an older or legacy local record has no coordinates.
    if (_validCoordinates(latitude, longitude)) {
      data['latitude'] = latitude;
      data['longitude'] = longitude;
    }

    await _collection.doc(id).update(data);
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }

  static bool _validCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude == 0 && longitude == 0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
